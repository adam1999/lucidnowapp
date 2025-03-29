// sound_selection_grid.dart (no changes)
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundSelectionGrid extends StatefulWidget {
  final String selectedSound;
  final Function(String) onSoundSelected;

  const SoundSelectionGrid({
    Key? key,
    required this.selectedSound,
    required this.onSoundSelected,
  }) : super(key: key);

  @override
  State<SoundSelectionGrid> createState() => _SoundSelectionGridState();
}

class _SoundSelectionGridState extends State<SoundSelectionGrid> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? playingSound;

  final List<Map<String, String>> sounds = [
    {'id': 'melody1.mp3', 'name': 'Melody 1'},
    {'id': 'melody2.mp3', 'name': 'Melody 2'},
    {'id': 'melody3.mp3', 'name': 'Melody 3'},
    {'id': 'melody4.mp3', 'name': 'Melody 4'},
    {'id': 'melody5.mp3', 'name': 'Melody 5'},
    {'id': 'melody6.mp3', 'name': 'Melody 6'},
  ];

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(String soundFile) async {
    if (playingSound == soundFile) {
      await _audioPlayer.stop();
      setState(() => playingSound = null);
    } else {
      try {
        if (playingSound != null) {
          await _audioPlayer.stop();
        }
        await _audioPlayer.play(AssetSource('soundtriggers/$soundFile'));
        setState(() => playingSound = soundFile);
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() => playingSound = null);
          }
        });
      } catch (e) {
        debugPrint('Error playing sound: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemCount: sounds.length,
      itemBuilder: (context, index) {
        final sound = sounds[index];
        final isSelected = sound['id'] == widget.selectedSound;
        final isPlaying = sound['id'] == playingSound;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onSoundSelected(sound['id']!),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isSelected 
                    ? const Color(0xFF5E5DE3).withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                border: Border.all(
                  color: isSelected ? const Color(0xFF5E5DE3) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    sound['name']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.stop : Icons.play_arrow,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                    onPressed: () => _playSound(sound['id']!),
                    tooltip: isPlaying ? 'Stop' : 'Play',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
