import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../lib_200/translations/app_translations.dart';
import '../../../lib_200/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../../../../lib__/services/preferences_service.dart';
import '../../../../lib__/screens/intro/intro_screens.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final String currentLanguage = settings.currentLanguage;
    
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
          title: Text(
            AppTranslations.translate('howItWorks', currentLanguage),
            style: const TextStyle(
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
                _buildHeroSection(currentLanguage),
                const SizedBox(height: 24),
                _buildFeatureCard(
                  icon: Icons.bedtime,
                  title: AppTranslations.translate('nightProtocol', currentLanguage),
                  content: AppTranslations.translate('nightProtocolDescription', currentLanguage),
                  color: const Color(0xFF5E5DE3),
                ),
                const SizedBox(height: 20),
                _buildFeatureCard(
                  icon: Icons.self_improvement,
                  title: AppTranslations.translate('trainingMode', currentLanguage),
                  content: AppTranslations.translate('trainingModeDescription', currentLanguage),
                  color: const Color(0xFF7A67EB),
                ),
                const SizedBox(height: 20),
                _buildFeatureCard(
                  icon: Icons.book_outlined,
                  title: AppTranslations.translate('dreamJournal', currentLanguage),
                  content: AppTranslations.translate('dreamJournalDescription', currentLanguage),
                  color: const Color(0xFF9370DB),
                ),
                const SizedBox(height: 20),
                _buildTipsCard(currentLanguage),
                const SizedBox(height: 24),
                _buildStartButton(context, currentLanguage),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(String currentLanguage) {
    return Stack(
      children: [
        Container(
          height: 180,
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
                  const Icon(
                    Icons.nights_stay,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppTranslations.translate('unlockYourDreams', currentLanguage),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppTranslations.translate('simpleTools', currentLanguage),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
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

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF252531).withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsCard(String currentLanguage) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF252531).withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFFFFD700),
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    AppTranslations.translate('proTips', currentLanguage),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTipItem(
                icon: Icons.access_time,
                text: AppTranslations.translate('bestResultsTip', currentLanguage),
              ),
              _buildTipItem(
                icon: Icons.notifications,
                text: AppTranslations.translate('wakingTip', currentLanguage),
              ),
              _buildTipItem(
                icon: Icons.psychology,
                text: AppTranslations.translate('mindfulnessTip', currentLanguage),
              ),
              _buildTipItem(
                icon: Icons.edit_note,
                text: AppTranslations.translate('journalTip', currentLanguage),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context, String currentLanguage) {
    return Center(
      child: Column(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E5DE3),
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 8,
              shadowColor: const Color(0xFF5E5DE3).withOpacity(0.5),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const IntroScreens(tutorialMode: true)),
            ),
            child: Text(
              AppTranslations.translate('startNow', currentLanguage),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              // Directly navigate to intro slides in tutorial mode
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IntroScreens(tutorialMode: true)),
              );
            },
            icon: const Icon(Icons.slideshow, color: Colors.white70),
            label: Text(
              AppTranslations.translate('viewIntroSlides', currentLanguage) ?? 'View Intro Slides',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}