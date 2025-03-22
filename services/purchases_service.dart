import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:lucid_dream_trainer/translations/app_translations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class PurchasesService {
  static const String _apiKey = 'appl_WWhSUmlhgNMVOalRmISFCthGDjP';
  static const String _entitlementId = 'premium';
  static bool _isInitialized = false;
  static bool _isTestPremiumGranted = false;
  
  // For development and troubleshooting
  static bool forceEnablePremium = false;

  // Initialize RevenueCat with the most straightforward configuration
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Enable detailed logs for debugging
      await Purchases.setDebugLogsEnabled(true);
      
      // Configure with your API key
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      
      // Get initial customer info to verify connection
      final customerInfo = await Purchases.getCustomerInfo();
      print("Initial customer info: ${customerInfo.entitlements.active}");
      
      _isInitialized = true;
      print('RevenueCat initialized successfully');
    } catch (e) {
      print('Error initializing RevenueCat: $e');
    }
  }

  // Open subscription management in App Store
  static Future<void> openAppStoreSettings() async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        // Deep link to open subscription management in iOS Settings
        final settingsUrl = Uri.parse('itms-apps://apps.apple.com/account/subscriptions');
        if (await canLaunchUrl(settingsUrl)) {
          await launchUrl(settingsUrl);
        } else {
          // Fallback if direct link doesn't work
          final appStoreUrl = Uri.parse('https://apps.apple.com/account/subscriptions');
          await launchUrl(appStoreUrl);
        }
      }
    } catch (e) {
      print('Error opening App Store settings: $e');
    }
  }
  
  // Open subscription management in Play Store
  static Future<void> openPlayStoreSettings() async {
    try {
      if (Platform.isAndroid) {
        final playStoreUrl = Uri.parse('https://play.google.com/store/account/subscriptions');
        await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error opening Play Store settings: $e');
    }
  }
} 