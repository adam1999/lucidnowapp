import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/journal/dream_journal_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/training/main_training_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Failed to initialize Firebase: $e');
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
      title: 'My Damn App',
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
            child: StreamBuilder<User?>(
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
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                child: Stack(
                  children: [
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    NavigationBarTheme(
                      data: NavigationBarThemeData(
                        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                          (Set<WidgetState> states) {
                            return TextStyle(
                              color: states.contains(WidgetState.selected)
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 10,  // Reduce from 12
                            );
                          },
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.only(top: 10, bottom: 0),  // Added top padding
                        child: NavigationBar(
                          height: 60,  // Reduce from 80
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
                              _buildDestination(0, Icons.book, 'Journal'),
                              _buildDestination(1, Icons.visibility, 'Training'),
                              _buildDestination(2, Icons.person, 'Profile'),
                            ],

                        ),
                      ),
                    ),
                  ],
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
    return NavigationDestination(
      icon: Icon(icon, 
        color: Colors.white.withOpacity(isSelected ? 0.9 : 0.5),
        size: 22,  // Reduced from 26
      ),
      selectedIcon: Icon(icon, 
        color: Colors.white,
        size: 22,  // Reduced from 26
      ),
      label: label,
    );
  }
}