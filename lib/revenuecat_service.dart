import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RevenueCatService {
  // TODO: RevenueCatのダッシュボードから取得したAPIキーを設定してください
  static const String _appleApiKey = 'apple_api_key_here';
  static const String _googleApiKey = 'google_api_key_here';

  // 1回の購入で付与されるAI利用回数（パッケージごとの設定が必要な場合は変更してください）
  static const int usesPerPurchase = 100;

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
    // デフォルトで初回は10回程度のお試し枠を付与するなどの処理もここで行えます。
    // 今回は初期値は0とします。
    return prefs.getInt('ai_remaining_uses') ?? 10; // 初回無料分として10を設定
  }

  /// AIの使用回数を1消費する
  static Future<bool> consumeUse() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt('ai_remaining_uses') ?? 10;
    if (current > 0) {
      await prefs.setInt('ai_remaining_uses', current - 1);
      return true;
    }
    return false; // 回数不足
  }

  /// AI利用回数を追加する
  static Future<void> addUses(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt('ai_remaining_uses') ?? 10;
    await prefs.setInt('ai_remaining_uses', current + amount);
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
      // 購入が完了したら、利用回数を追加する
      // ※どのパッケージを買ったかによって付与回数を変えたい場合は、package.identifierなどで判定する。
      await addUses(usesPerPurchase);
      return true;
    } catch (e) {
      debugPrint('Error purchasing package: $e');
      return false;
    }
  }
}
