import 'package:flutter/material.dart';
import 'package:lucid_dream_trainer/models/intro_screen.dart';
import 'package:lucid_dream_trainer/screens/auth/login_screen.dart';
import 'package:lucid_dream_trainer/services/preferences_service.dart';

class IntroScreens extends StatefulWidget {
  final bool tutorialMode;
  
  const IntroScreens({Key? key, this.tutorialMode = false}) : super(key: key);

  @override
  State<IntroScreens> createState() => _IntroScreensState();
}

class _IntroScreensState extends State<IntroScreens> {
  final PageController _pageController = PageController();
  final List<IntroScreen> _screens = IntroScreen.getIntroScreens();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _screens.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Last page, mark intro as seen and navigate appropriately
      _finishIntro();
    }
  }

  Future<void> _finishIntro() async {
    // Only set intro as seen if not in tutorial mode
    if (!widget.tutorialMode) {
      await PreferencesService.setIntroSeen();
    }
    
    if (mounted) {
      if (widget.tutorialMode) {
        // Just go back to previous screen if in tutorial mode
        Navigator.of(context).pop();
      } else {
        // Regular navigation to login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Page View with both background and content
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _screens.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  // Background image
                  _buildFullScreenImage(_screens[index].imagePath),
                  
                  // Gradient overlay for text
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.4),
                            Colors.black.withOpacity(0.7),
                            Colors.black.withOpacity(0.9),
                          ],
                          stops: const [0.0, 0.2, 0.6, 1.0],
                        ),
                      ),
                      padding: const EdgeInsets.only(
                        top: 100.0, // Taller top padding to extend gradient up
                        bottom: 180.0, // Increased bottom padding to avoid overlap with buttons
                        left: 24.0,
                        right: 24.0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title and description
                          Text(
                            _screens[index].title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _screens[index].description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Skip button at top
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () {
                    if (widget.tutorialMode) {
                      Navigator.of(context).pop();
                    } else {
                      _finishIntro();
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom controls (page indicators and next button)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Page indicators
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _screens.length,
                      (index) => _buildDotIndicator(index),
                    ),
                  ),
                ),
                
                // Next/Get Started button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24.0, 
                    0, 
                    24.0, 
                    MediaQuery.of(context).padding.bottom > 0 
                        ? MediaQuery.of(context).padding.bottom + 20.0
                        : 40.0, 
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5E5DE3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage < _screens.length - 1 
                            ? 'Next' 
                            : 'Get Started',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenImage(String imagePath) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              size: 80,
              color: Colors.white24,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDotIndicator(int index) {
    bool isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF5E5DE3) : Colors.white54,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
} 