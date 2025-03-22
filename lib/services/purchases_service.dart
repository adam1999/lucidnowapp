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
  
  // Initialize RevenueCat with the most straightforward configuration
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Configure with your API key
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      
      // Get initial customer info to verify connection
      final customerInfo = await Purchases.getCustomerInfo();
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing RevenueCat: $e');
    }
  }

  // Check if premium is active
  static Future<bool> isPremiumActive() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      
      // First check if there's an active entitlement with our ID
      final isPremium = customerInfo.entitlements.active.containsKey(_entitlementId);
      
      // Check all active entitlements as a backup in case the ID is wrong
      if (!isPremium && customerInfo.entitlements.active.isNotEmpty) {
        // If we have any active entitlements, consider premium as active as a fallback
        return true;
      }
      
      return isPremium;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  // Show RevenueCat's paywall
  static Future<bool> showPaywallIfNeeded(BuildContext context, [String language = 'en']) async {
    try {
      // Get current offerings
      final offerings = await Purchases.getOfferings();
      PaywallResult result;
      
      // First attempt: Try to use "paywall_premium" offering specifically
      if (offerings.all.containsKey("paywall_premium")) {
        result = await RevenueCatUI.presentPaywall(
          offering: offerings.all["paywall_premium"],
        );
      } 
      // Second attempt: Try to use the current offering if available
      else if (offerings.current != null) {
        result = await RevenueCatUI.presentPaywall(
          offering: offerings.current!,
        );
      } 
      // Final fallback: Use entitlement-based presentation
      else {
        result = await RevenueCatUI.presentPaywallIfNeeded(_entitlementId);
      }
      
      // Verify purchase success
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.active.containsKey(_entitlementId);
      
      // As a fallback, if any entitlement is active, consider it a success
      if (!isPremium && customerInfo.entitlements.active.isNotEmpty) {
        return true;
      }
      
      return isPremium;
    } catch (e) {
      debugPrint('Error showing RevenueCat paywall: $e');
      
      // Show a simple error message
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppTranslations.translate('errorTitle', language)),
          content: Text(AppTranslations.translate('premiumPurchaseError', language)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppTranslations.translate('ok', language)),
            ),
          ],
        ),
      );
      
      return false;
    }
  }

  // Open app store settings
  static Future<void> openAppStoreSettings() async {
    if (Platform.isIOS) {
      try {
        // For iOS, use iTunes URL scheme to open subscription management
        final settingsUrl = Uri.parse('itms-apps://apps.apple.com/account/subscriptions');
        if (await canLaunchUrl(settingsUrl)) {
          await launchUrl(settingsUrl);
        } else {
          // Fallback to App Store website
          final webUrl = Uri.parse('https://apps.apple.com/account/subscriptions');
          await launchUrl(webUrl);
        }
      } catch (e) {
        debugPrint('Error opening app store settings: $e');
      }
    } else {
      debugPrint('This method is only available on iOS devices');
    }
  }

  // Open play store settings
  static Future<void> openPlayStoreSettings() async {
    if (Platform.isAndroid) {
      try {
        // For Android, open Play Store subscriptions
        final playStoreUrl = Uri.parse('https://play.google.com/store/account/subscriptions');
        await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Error opening play store settings: $e');
      }
    } else {
      debugPrint('This method is only available on Android devices');
    }
  }
}