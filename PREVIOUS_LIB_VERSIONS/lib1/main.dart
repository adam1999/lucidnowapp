import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../lib__/screens/intro/intro_screens.dart';
import '../../lib__/services/preferences_service.dart';
import '../../lib__/services/purchases_service.dart';
import '../lib_200/translations/app_translations.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/journal/dream_journal_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/training/main_training_page.dart';
import 'screens/widgets/common_header.dart';
import 'screens/tutorial/tutorial_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
  }
  
  // Initialize RevenueCat
  try {
    await PurchasesService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize RevenueCat: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  runApp(
    ChangeNotifierProvider(
      create: (_) => settingsProvider,
      child: const MyGradientApp(),
    ),
  );
}

class MyGradientApp extends StatelessWidget {
  const MyGradientApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: const TextTheme().apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      primaryTextTheme: const TextTheme().apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      colorScheme: const ColorScheme.dark(),
      iconTheme: const IconThemeData(color: Colors.white),
      appBarTheme: const AppBarTheme(
        titleTextStyle: TextStyle(color: Colors.white),
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lucid Now',
      theme: theme,
      home: Stack(
        children: [
          Container(
            color: const Color(0xFF06070F),
          ),
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
            child: FutureBuilder<bool>(
              future: PreferencesService.hasSeenIntro(),
              builder: (context, introSnapshot) {
                if (introSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Colors.transparent,
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                // Show intro screens if the user hasn't seen them
                final hasSeenIntro = introSnapshot.data ?? false;
                if (!hasSeenIntro) {
                  return const IntroScreens();
                }
                
                // Otherwise proceed with auth check
                return StreamBuilder<User?>(
                  stream: AuthService().authStateChanges,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasData) {
                      return const MainNavigationScreen();
                    }
                    return const LoginScreen();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  MainNavigationScreenState createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 1;
  bool _showNavBar = true;

  static const Color journalColor = Color(0xFF7dd3f3);
  static const Color trainingColor = Color(0xFFf4cd8b);
  static const Color profileColor = Color(0xFFe77d7f);

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CommonHeader(),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              const DreamJournalScreen(),
              TrainingScreen(
                onBlackOverlayChanged: (isActive) {
                  setState(() {
                    _showNavBar = !isActive;
                  });
                },
              ),
              const ProfileScreen(),
            ],
          ),

          if (_showNavBar) Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF252531).withOpacity(0.8),
                        const Color(0xFF1A1A1A),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                        (Set<WidgetState> states) {
                          return TextStyle(
                            color: Colors.white.withOpacity(states.contains(WidgetState.selected) ? 1.0 : 0.6),
                            fontSize: 10,
                            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w500 : FontWeight.normal,
                          );
                        },
                      ),
                      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
                        (Set<WidgetState> states) {
                          return IconThemeData(
                            color: Colors.white.withOpacity(states.contains(WidgetState.selected) ? 1.0 : 0.6),
                            size: 20,
                          );
                        },
                      ),
                    ),
                    child: NavigationBar(
                      height: 56, // Slightly increased to accommodate the icon background
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      indicatorColor: Colors.transparent,
                      elevation: 0,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: [
                        _buildDestination(0, Icons.book, AppTranslations.translate('journal', settings.currentLanguage)),
                        _buildDestination(1, Icons.bedtime, AppTranslations.translate('sleep', settings.currentLanguage)),
                        _buildDestination(2, Icons.person, AppTranslations.translate('profile', settings.currentLanguage)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  NavigationDestination _buildDestination(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    
    // Use the same color as the main buttons (Start Sleeping and Training)
    const Color buttonColor = Color(0xFF5E5DE3);
    
    return NavigationDestination(
      icon: Icon(
        icon, 
        color: Colors.white.withOpacity(0.6),
        size: 20,
      ),
      selectedIcon: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withOpacity(0.4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          icon, 
          color: Colors.white,
          size: 18, // Slightly smaller to fit nicely in the container
        ),
      ),
      label: label,
    );
  }
}