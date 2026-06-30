import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum SubscriptionTier {
  free,
  premium,
  family,
}

/// Service handling In-App Purchases via RevenueCat.
/// Exposes methods to fetch offerings, purchase, and check entitlement status.
class IAPService {
  // TODO: Replace with actual RevenueCat API keys from dashboard
  static const String _appleApiKey = 'appl_api_key_placeholder';
  static const String _googleApiKey = 'goog_api_key_placeholder';

  /// Initializes RevenueCat SDK.
  /// Must be called early in the app lifecycle (e.g. main.dart).
  Future<void> init() async {
    if (kIsWeb) return; // RevenueCat does not support web yet.

    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    
    if (Platform.isIOS || Platform.isMacOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    } else if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_googleApiKey);
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
    }
  }

  /// Fetches available offerings from RevenueCat.
  Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        return offerings;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get offerings: $e');
      return null;
    }
  }

  /// Purchases a specific package (e.g. monthly, yearly).
  Future<bool> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      return _isPremiumOrFamily(customerInfo);
    } catch (e) {
      debugPrint('Failed to purchase package: $e');
      return false;
    }
  }

  /// Restores previous purchases.
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return _isPremiumOrFamily(customerInfo);
    } catch (e) {
      debugPrint('Failed to restore purchases: $e');
      return false;
    }
  }

  /// Helper to determine the current subscription tier based on active entitlements.
  SubscriptionTier getSubscriptionTier(CustomerInfo customerInfo) {
    // Check for family plan first
    if (customerInfo.entitlements.all['family']?.isActive == true) {
      return SubscriptionTier.family;
    }
    
    // Check for premium (monthly/yearly)
    if (customerInfo.entitlements.all['premium']?.isActive == true) {
      return SubscriptionTier.premium;
    }

    return SubscriptionTier.free;
  }

  /// Helper to check if the user has premium or family access.
  bool _isPremiumOrFamily(CustomerInfo customerInfo) {
    final tier = getSubscriptionTier(customerInfo);
    return tier == SubscriptionTier.premium || tier == SubscriptionTier.family;
  }

  /// Fetches the latest CustomerInfo to determine current subscription status.
  Future<SubscriptionTier> getCurrentTier() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return getSubscriptionTier(customerInfo);
    } catch (e) {
      debugPrint('Failed to get customer info: $e');
      return SubscriptionTier.free;
    }
  }
}
