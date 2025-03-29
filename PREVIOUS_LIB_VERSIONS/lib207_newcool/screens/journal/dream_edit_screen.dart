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

class _DreamEditScreenState extends State<DreamEditScreen> {
  late DateTime _selectedDate;
  final _formKey = GlobalKey<FormState>();
  List<_DreamFormField> _dreamFields = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.dreamEntry?.date ?? DateTime.now();
    if (widget.dreamEntry != null) {
      _dreamFields = widget.dreamEntry!.dreams
          .map((dream) => _DreamFormField(
                contentController: TextEditingController(text: dream.content),
                isLucid: dream.isLucid,
              ))
          .toList();
    } else {
      _dreamFields = [_DreamFormField(contentController: TextEditingController())];
    }
  }

  @override
  void dispose() {
    for (var field in _dreamFields) {
      field.contentController.dispose();
    }
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
    setState(() {
      _dreamFields.add(_DreamFormField(contentController: TextEditingController()));
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
              primary: Colors.purple,
              surface: Color(0xFF252531),
            ),
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
                vividness: field.vividness, // Save vividness value
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


  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF06070F), // Use the dark top gradient color
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
                      title: const Text(
                        'Delete Dream',
                        style: TextStyle(color: Colors.white70),
                      ),
                      content: const Text(
                        'Are you sure you want to delete this dream?',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
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
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    title: Text(
                      DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: Colors.white),
                    onTap: () => _selectDate(context),
                    tileColor: const Color(0xFF252531),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._dreamFields.asMap().entries.map((entry) {
                    final index = entry.key;
                    final field = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index > 0) const Divider(height: 32),
                        Row(
                          children: [
                            Text(
                              '${AppTranslations.translate('dream', settings.currentLanguage)} ${index + 1}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                              onPressed: () => _removeDreamField(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: Text(
                            AppTranslations.translate('lucidDream', settings.currentLanguage),
                            style: const TextStyle(color: Colors.white),
                          ),
                          value: field.isLucid,
                          onChanged: (value) => setState(() => field.isLucid = value),
                          tileColor: const Color(0xFF252531),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // New vividness slider below the Lucid Dream checkbox
                        Text(
                          AppTranslations.translate('vividness', settings.currentLanguage),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        Slider(
                          value: field.vividness.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: field.vividness.toString(),
                          activeColor: const Color(0xFF5E5DE3),
                          inactiveColor: Colors.white24,
                          onChanged: (value) {
                            setState(() {
                              field.vividness = value.toInt();
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252531),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextFormField(
                            controller: field.contentController,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: AppTranslations.translate('enterDream', settings.currentLanguage),
                              hintStyle: const TextStyle(color: Colors.white60),
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
                      ],
                    );
                  }).toList(),

                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _addDreamField,
                    icon: const Icon(Icons.add, color: Color(0xFF5E5DE3)),
                    label: Text(
                      AppTranslations.translate('addAnotherDream', settings.currentLanguage),
                      style: const TextStyle(color: Color(0xFF5E5DE3)),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF5E5DE3),
                    ),
                  ),

                ],
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
  bool isLucid;
  int vividness; // New vividness field

  _DreamFormField({
    required this.contentController,
    this.isLucid = false,
    this.vividness = 3, // Default vividness value
  });
}
