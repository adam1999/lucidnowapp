// lib/screens/journal/dream_journal_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucid_dream_trainer/screens/widgets/common_header.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/dream.dart';
import '../../translations/app_translations.dart';
import '../../providers/settings_provider.dart';
import 'widgets/dream_card.dart';
import 'dream_edit_screen.dart';

class DreamJournalScreen extends StatefulWidget {
  const DreamJournalScreen({super.key});

  @override
  State<DreamJournalScreen> createState() => _DreamJournalScreenState();
}

class _DreamJournalScreenState extends State<DreamJournalScreen> with WidgetsBindingObserver {
  List<DreamEntry> dreamEntries = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  String? _lastRefreshTimestamp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDreams();
    _checkForRefreshNotification();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app comes to foreground, check if refresh is needed
    if (state == AppLifecycleState.resumed) {
      _checkForRefreshNotification();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for refresh notification when page becomes visible
    _checkForRefreshNotification();
  }

  Future<void> _checkForRefreshNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshTimestamp = prefs.getString('dream_journal_refresh');
    
    // If there's a new refresh timestamp, reload dreams
    if (refreshTimestamp != null && refreshTimestamp != _lastRefreshTimestamp) {
      _lastRefreshTimestamp = refreshTimestamp;
      _loadDreams();
    }
  }

  Future<void> _loadDreams() async {
    setState(() => _isLoading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('dreams')
            .orderBy('date', descending: true)
            .get();

        setState(() {
          dreamEntries = snapshot.docs
              .map((doc) => DreamEntry.fromJson(doc.data()))
              .toList();
          _isLoading = false;
        });
      } catch (e) {
        debugPrint('Error loading dreams from Firestore: $e');
        await _loadLocalDreams();
      }
    } else {
      await _loadLocalDreams();
    }
  }

  Future<void> _loadLocalDreams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dreamsJson = prefs.getStringList('dreams') ?? [];
      setState(() {
        dreamEntries = dreamsJson
            .map((json) => DreamEntry.fromJson(jsonDecode(json)))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading local dreams: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDreams(DreamEntry dream) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('dreams')
            .doc(dream.id)
            .set(dream.toJson());
      } catch (e) {
        debugPrint('Error saving to Firestore: $e');
        await _saveToLocal();
      }
    } else {
      await _saveToLocal();
    }
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final dreamsJson = dreamEntries
        .map((entry) => jsonEncode(entry.toJson()))
        .toList();
    await prefs.setStringList('dreams', dreamsJson);
  }

  Future<void> _addDream() async {
    final dreamEntry = await Navigator.push<DreamEntry>(
      context,
      MaterialPageRoute(
        builder: (context) => const DreamEditScreen(),
      ),
    );

    if (dreamEntry != null) {
      setState(() {
        dreamEntries.insert(0, dreamEntry);
      });
      await _saveDreams(dreamEntry);
    }
  }

  Future<void> _editDream(DreamEntry dreamEntry) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => DreamEditScreen(dreamEntry: dreamEntry),
      ),
    );

    if (result == "delete") {
      final index = dreamEntries.indexWhere((d) => d.id == dreamEntry.id);
      if (index != -1) {
        await _deleteDream(index, dreamEntry);
      }
    } else if (result != null && result is DreamEntry) {
      setState(() {
        final index = dreamEntries.indexWhere((d) => d.id == result.id);
        dreamEntries[index] = result;
      });
      await _saveDreams(result);
    }
  }

  Future<void> _deleteDream(int index, DreamEntry dreamEntry) async {
    setState(() => dreamEntries.removeAt(index));
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('dreams')
            .doc(dreamEntry.id)
            .delete();
      } catch (e) {
        debugPrint('Error deleting from Firestore: $e');
      }
    }
    await _saveToLocal();

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppTranslations.translate('dreamDeleted', settings.currentLanguage)),
        action: SnackBarAction(
          label: AppTranslations.translate('undo', settings.currentLanguage),
          onPressed: () async {
            setState(() => dreamEntries.insert(index, dreamEntry));
            await _saveDreams(dreamEntry);
          },
        ),
      ),
    );
  }

  String _getMonthYear(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

Widget _buildDreamList(SettingsProvider settings) {  // Add settings parameter
    if (dreamEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.book_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              AppTranslations.translate('noDreamsRecorded', settings.currentLanguage),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.translate('tapToAddDream', settings.currentLanguage),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
            ),
          ],
        ),
      );
    }

    List<Widget> items = [];
    String? currentMonth;

    // Add the "Dream Journal" title
    items.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 16.0, left: 4.0),
        child: Text(
          AppTranslations.translate('journal', settings.currentLanguage),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );

    for (int i = 0; i < dreamEntries.length; i++) {
      final dreamEntry = dreamEntries[i];
      final month = _getMonthYear(dreamEntry.date);

      // Add month separator if needed
      if (currentMonth != month) {
        if (i != 0) {  // Don't add padding before the first month
          items.add(const SizedBox(height: 24));
        }
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0, left: 4.0),
            child: Text(
              month,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        );
        currentMonth = month;
      }

      // Add dream card
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: DreamCard(
            dreamEntry: dreamEntry,
            onTap: () => _editDream(dreamEntry),
          ),
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: 100.0,
      ),
      children: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF06070F),
                Color(0xFF100B1A),
                Color(0xFF1C1326),
                Color(0xFF2F1D34),
              ],
              stops: [0.0, 0.3, 0.6, 1.0],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildDreamList(settings),  // Pass settings here
            floatingActionButton: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF5E5DE3),
                onPressed: _addDream,
                child: const Icon(Icons.add, color: Colors.white, size: 32),
              ),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          ),
        );
      },
    );
  }
}