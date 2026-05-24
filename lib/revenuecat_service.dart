import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RevenueCatService {
  // TODO: RevenueCatのダッシュボードから取得したAPIキーを設定してください
  static const String _appleApiKey = 'apple_api_key_here';
  static const String _googleApiKey = 'google_api_key_here';

  static Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    } else {
      return;
    }
    await Purchases.configure(configuration);
  }

  /// 利用回数の同期を行う (RevenueCatのトランザクション履歴などから復元する場合)
  static Future<void> syncUsageCount() async {
    // 今回はローカルのSharedPreferencesに残りの回数（もしくは使用回数）を保存するシンプルな形式とする。
    // サブスクリプションとは異なり、消耗型はCustomerInfoのnonSubscriptionTransactionsなどから購入履歴を確認できます。
  }

  /// AIの残りの使用回数を取得する
  static Future<int> getRemainingUses() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('ai_remaining_uses') ?? 0;
  }

  /// AIの使用回数を1消費する
  static Future<bool> consumeUse() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt('ai_remaining_uses') ?? 0;
    if (current > 0) {
      await prefs.setInt('ai_remaining_uses', current - 1);
      return true;
    }
    return false; // 回数不足
  }

  /// AI利用回数を追加する
  static Future<void> addUses(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt('ai_remaining_uses') ?? 0;
    await prefs.setInt('ai_remaining_uses', current + amount);
  }

  /// RevenueCatのOfferingメタデータから付与回数を取得する
  /// ダッシュボードの Offerings → (対象Offering) → Metadata に
  /// キー "uses_per_purchase"、値 50 (数値) を設定してください。
  static Future<int> getUsesPerPurchase() async {
    try {
      final offerings = await Purchases.getOfferings();
      final meta = offerings.current?.metadata;
      if (meta != null && meta.containsKey('uses_per_purchase')) {
        return (meta['uses_per_purchase'] as num).toInt();
      }
    } catch (e) {
      debugPrint('Error fetching offering metadata: $e');
    }
    return 50; // フォールバック値
  }

  /// 利用可能なパッケージ（消耗型アイテムなど）を取得する
  static Future<List<Package>> getOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching offerings: $e');
      return [];
    }
  }

  /// パッケージ（消耗型）を購入する
  static Future<bool> purchasePackage(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      // RevenueCatダッシュボードのOfferingメタデータから付与回数を取得して追加する
      final uses = await getUsesPerPurchase();
      await addUses(uses);
      return true;
    } catch (e) {
      debugPrint('Error purchasing package: $e');
      return false;
    }
  }
}
