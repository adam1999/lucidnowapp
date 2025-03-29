import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucid_dream_trainer/screens/widgets/common_header.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
        // Replace the CommonHeader with a custom AppBar
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Tutorial',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(),
                const SizedBox(height: 24),
                _buildSection(
                  'Welcome to LucidNow',
                  'Hi, I\'m Adam, the founder of LucidNow. I\'m here to help you achieve something extraordinary - becoming conscious in your dreams.\n\n'
                  'Did you know you spend about 2 hours dreaming every night? Imagine being able to use this time to do anything possible in this world and beyond, with full awareness and control.',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'How It Works',
                  'LucidNow uses a scientifically-proven protocol combining three key elements:\n\n'
                  '• A custom sound trigger (a gentle 3-5 note melody you choose)\n'
                  '• Mindfulness training\n'
                  '• Smart sleep phase targeting',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Getting Started: Dream Journal',
                  'The foundation of lucid dreaming is remembering your dreams. In the app\'s Dream Journal:\n\n'
                  '• Record your dreams immediately when you wake up\n'
                  '• Even tiny fragments or feelings matter\n'
                  '• Read your journal 2-3 times daily\n'
                  '• Within a week, you\'ll notice your dreams becoming more vivid\n\n'
                  'While dream journaling enhances your results, you can start the protocol right away.',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'The Training Protocol',
                  '1. Intensive Mindfulness (5 minutes)\n'
                  'This is where your training begins:\n'
                  '• Count your breaths from 1 to 10\n'
                  '• Tap the left side for breaths 1-9\n'
                  '• Tap the right side for breath 10\n'
                  '• If you lose count, tap the top button\n'
                  '• Your mindfulness score directly correlates with lucid dream success\n'
                  '• During this exercise, your chosen trigger sound plays randomly\n\n'
                  '2. Pre-sleep phase (3 minutes)\n'
                  '• Turn off your screen\n'
                  '• Relax and listen\n'
                  '• Your trigger sound plays alongside voice prompts\n'
                  '• Focus on developing awareness when you hear the trigger\n\n'
                  '3. Sleep Preparation (2 minutes)\n'
                  '• A gentle transition phase\n'
                  '• Softer trigger sounds\n'
                  '• No voice prompts\n'
                  '• Prepares you for sleep',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'The Sleep Phase',
                  'During sleep, LucidNow works intelligently:\n\n'
                  '• Targets your REM cycles (when dreams occur)\n'
                  '• Sleep cycles happen every 90 minutes\n'
                  '• REM phases get longer throughout the night\n'
                  '• Best results after 5-6 hours of sleep\n'
                  '• Your trigger sound plays at optimal moments\n'
                  '• Volume is carefully balanced - subtle enough to not wake you, but present in your dreams',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Tips for Success',
                  '• Practice the Intensive Mindfulness exercise multiple times daily\n'
                  '• Read your dream journal regularly\n'
                  '• Start with later REM periods (5-6 hours after sleep)\n'
                  '• Adjust trigger volume carefully\n'
                  '• Track your progress in the app:\n'
                  '  - Mindfulness scores\n'
                  '  - Dream recall\n'
                  '  - Lucidity rate\n'
                  '  - Dream vividness',
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Coming Soon',
                  'We\'re constantly improving LucidNow with new features:\n\n'
                  '• Wearable integration for precise REM targeting\n'
                  '• Streak system for consistent practice\n'
                  '• Reality testing tools\n'
                  '• Advanced sleep pattern customization\n'
                  '• Even more personalization options',
                ),
                const SizedBox(height: 32),
                _buildStartButton(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Stack(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF5E5DE3).withOpacity(0.3),
                const Color(0xFF2F1D34).withOpacity(0.3),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Make Your Dreams Come True',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unlock the power of lucid dreaming',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF252531).withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                content,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5E5DE3),
          foregroundColor: Colors.white,
          minimumSize: const Size(200, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        onPressed: () => Navigator.pop(context),
        child: const Text(
          'Start Your Journey',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}