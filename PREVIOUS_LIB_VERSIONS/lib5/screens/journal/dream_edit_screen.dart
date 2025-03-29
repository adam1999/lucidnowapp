// lib/screens/journal/dream_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/dream.dart';
import '../../translations/app_translations.dart';
import '../../providers/settings_provider.dart';

class DreamEditScreen extends StatefulWidget {
  final DreamEntry? dreamEntry;

  const DreamEditScreen({super.key, this.dreamEntry});

  @override
  State<DreamEditScreen> createState() => _DreamEditScreenState();
}

class _DreamEditScreenState extends State<DreamEditScreen> with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  final _formKey = GlobalKey<FormState>();
  List<_DreamFormField> _dreamFields = [];
  final FocusNode _firstFieldFocusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.dreamEntry?.date ?? DateTime.now();
    
    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.forward();
    
    if (widget.dreamEntry != null) {
      _dreamFields = widget.dreamEntry!.dreams
          .map((dream) => _DreamFormField(
                contentController: TextEditingController(text: dream.content),
                isLucid: dream.isLucid,
                vividness: dream.vividness,
              ))
          .toList();
    } else {
      _dreamFields = [_DreamFormField(contentController: TextEditingController())];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _firstFieldFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (var field in _dreamFields) {
      field.contentController.dispose();
      field.focusNode.dispose();
    }
    _firstFieldFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _removeDreamField(int index) {
    setState(() {
      _dreamFields[index].contentController.dispose();
      _dreamFields.removeAt(index);
      if (_dreamFields.isEmpty) {
        _dreamFields.add(_DreamFormField(contentController: TextEditingController()));
      }
    });
  }

  void _addDreamField() {
    final newFocusNode = FocusNode();
    final newField = _DreamFormField(
      contentController: TextEditingController(),
      focusNode: newFocusNode,
    );
    
    setState(() {
      _dreamFields.add(newField);
    });
    
    // Focus on the newly added field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      newFocusNode.requestFocus();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF5E5DE3),
              surface: Color(0xFF252531),
            ),
            dialogBackgroundColor: const Color(0xFF252531),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveDreams() {
    if (_formKey.currentState!.validate()) {
      final validDreams = _dreamFields
          .where((field) => field.contentController.text.trim().isNotEmpty)
          .map((field) => Dream(
                content: field.contentController.text.trim(),
                isLucid: field.isLucid,
                vividness: field.vividness,
              ))
          .toList();

      if (validDreams.isEmpty) {
        Navigator.pop(context);
        return;
      }

      final dreamEntry = DreamEntry(
        id: widget.dreamEntry?.id ?? const Uuid().v4(),
        date: _selectedDate,
        dreams: validDreams,
      );
      Navigator.pop(context, dreamEntry);
    }
  }

  Widget _buildVividnessLevel(int level, int currentLevel) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _dreamFields[_dreamFields.indexWhere((field) => field.vividness == currentLevel)].vividness = level;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: level <= currentLevel 
              ? Color.lerp(Colors.blue, Colors.purple, (level - 1) / 4)?.withOpacity(0.8)
              : const Color(0xFF252531).withOpacity(0.5),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: level <= currentLevel 
                ? Color.lerp(Colors.blue, Colors.purple, (level - 1) / 4)?.withOpacity(0.8) ?? Colors.transparent
                : Colors.white24,
            width: 1.5,
          ),
          boxShadow: level <= currentLevel ? [
            BoxShadow(
              color: Color.lerp(Colors.blue, Colors.purple, (level - 1) / 4)?.withOpacity(0.3) ?? Colors.transparent,
              blurRadius: 8,
              spreadRadius: 1,
            )
          ] : null,
        ),
        child: Center(
          child: Text(
            level.toString(),
            style: TextStyle(
              color: level <= currentLevel ? Colors.white : Colors.white60,
              fontWeight: level <= currentLevel ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF06070F), 
          elevation: 0,
          title: Text(
            widget.dreamEntry == null 
              ? AppTranslations.translate('newDreams', settings.currentLanguage)
              : AppTranslations.translate('editDreams', settings.currentLanguage),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            if (widget.dreamEntry != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF252531),
                      title: Text(
                        AppTranslations.translate('deleteDream', settings.currentLanguage),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      content: Text(
                        AppTranslations.translate('deleteDreamConfirm', settings.currentLanguage),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            AppTranslations.translate('cancel', settings.currentLanguage),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            AppTranslations.translate('delete', settings.currentLanguage),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    Navigator.of(context).pop("delete");
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveDreams,
            ),
          ],
        ),


        body: Stack(
          children: [
            // Gradient background
            Container(
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
            ),
            // Page content
            FadeTransition(
              opacity: _animation,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Date selector card
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF252531).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _selectDate(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: const Color(0xFF5E5DE3).withOpacity(0.9),
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white54,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Dream fields
                    ..._dreamFields.asMap().entries.map((entry) {
                      final index = entry.key;
                      final field = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF252531).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Dream header with remove button
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.purple.withOpacity(0.7),
                                            Colors.blue.withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Text(
                                        '${AppTranslations.translate('dream', settings.currentLanguage)} ${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 22),
                                      onPressed: () => _removeDreamField(index),
                                      splashRadius: 24,
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Lucid dream toggle
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.nightlight_round,
                                      color: field.isLucid ? const Color(0xFF5E5DE3) : Colors.white54,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      AppTranslations.translate('lucidDream', settings.currentLanguage),
                                      style: TextStyle(
                                        color: field.isLucid ? Colors.white : Colors.white70,
                                        fontSize: 16,
                                        fontWeight: field.isLucid ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                    const Spacer(),
                                    Switch(
                                      value: field.isLucid,
                                      onChanged: (value) => setState(() => field.isLucid = value),
                                      activeColor: const Color(0xFF5E5DE3),
                                      activeTrackColor: const Color(0xFF5E5DE3).withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Vividness selector
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                                child: Text(
                                  AppTranslations.translate('vividness', settings.currentLanguage),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              
                              // Vividness buttons
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    for (int i = 1; i <= 5; i++)
                                      _buildVividnessLevel(i, field.vividness),
                                  ],
                                ),
                              ),
                              
                              // Dream content text field
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: TextFormField(
                                    controller: field.contentController,
                                    focusNode: index == 0 && widget.dreamEntry == null ? _firstFieldFocusNode : field.focusNode,
                                    maxLines: null,
                                    minLines: 3,
                                    keyboardType: TextInputType.multiline,
                                    textInputAction: TextInputAction.newline,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: AppTranslations.translate('enterDream', settings.currentLanguage),
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                                      contentPadding: const EdgeInsets.all(16),
                                      border: InputBorder.none,
                                      errorStyle: const TextStyle(color: Colors.redAccent),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return AppTranslations.translate('pleaseEnterDream', settings.currentLanguage);
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    // Add another dream button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: TextButton(
                        onPressed: _addDreamField,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: const Color(0xFF5E5DE3).withOpacity(0.6),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF5E5DE3),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppTranslations.translate('addAnotherDream', settings.currentLanguage),
                              style: const TextStyle(
                                color: Color(0xFF5E5DE3),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DreamFormField {
  final TextEditingController contentController;
  final FocusNode focusNode;
  bool isLucid;
  int vividness;

  _DreamFormField({
    required this.contentController,
    FocusNode? focusNode,
    this.isLucid = false,
    this.vividness = 3,
  }) : focusNode = focusNode ?? FocusNode();
}
