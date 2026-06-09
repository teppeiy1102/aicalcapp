import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RevenueCatService {
  // TODO: RevenueCatのダッシュボードから取得したAPIキーを設定してください
  static const String _appleApiKey = 'appl_zHsobuxMwVlEqFKNklXHwvbyrPw';
  static const String _googleApiKey = 'goog_IWMvniZrCNWNIAUYVXhfeaKUeQb';

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
    //int current = 10;
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

  /// プロ版パッケージの製品IDリスト
  static const List<String> proProductIds = [
    'com.openpro',
    'com.yama.genbacalc.openpro',
  ];

  /// Offering の識別子
  static const String _proOfferingId = 'default';
  static const String _aiChargeOfferingId = 'ai_charge';

  /// プロ版パッケージを取得する（"default" Offering から）
  static Future<List<Package>> getProPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.all[_proOfferingId];
      return offering?.availablePackages ?? [];
    } catch (e) {
      debugPrint('Error fetching pro packages: $e');
      return [];
    }
  }

  /// AIチャージパッケージを取得する（"ai_charge" Offering から）
  static Future<List<Package>> getAiChargePackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.all[_aiChargeOfferingId];
      return offering?.availablePackages ?? [];
    } catch (e) {
      debugPrint('Error fetching AI charge packages: $e');
      return [];
    }
  }

  /// "ai_charge" Offering のメタデータから付与回数を取得する
  /// ダッシュボードの Offerings → ai_charge → Metadata に
  /// キー "uses_per_purchase"、値 50 (数値) を設定してください。
  static Future<int> getUsesPerPurchase() async {
    try {
      final offerings = await Purchases.getOfferings();
      final meta = offerings.all[_aiChargeOfferingId]?.metadata;
      if (meta != null && meta.containsKey('uses_per_purchase')) {
        return (meta['uses_per_purchase'] as num).toInt();
      }
    } catch (e) {
      debugPrint('Error fetching offering metadata: $e');
    }
    return 0; // フォールバック値
  }

  static bool? _cachedIsPro;

  /// プロ版（買い切り）が有効かどうか判定する
  static Future<bool> isProActive() async {
    if (_cachedIsPro != null) {
      return true;
   //   return _cachedIsPro!;
    }
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      // 非消耗型の購入履歴（トランザクション）に該当IDがあるか
      final hasProTransaction = customerInfo.nonSubscriptionTransactions.any((tx) =>
          tx.productIdentifier == 'com.openpro' ||
          tx.productIdentifier == 'com.yama.genbacalc.openpro');

      // エンタイトルメントが有効か (設定している場合)
      final hasEntitlement = (customerInfo.entitlements.all['openpro']?.isActive == true) ||
          (customerInfo.entitlements.all['macopenpro']?.isActive == true);

      // 開発・テスト時の確認用に true にする場合はここを変更してください
      _cachedIsPro = hasProTransaction || hasEntitlement;
  //    return _cachedIsPro!;
     return true;
    } catch (e) {
      debugPrint('Error checking pro status: $e');
      return false;
    }
  }

  /// キャッシュをクリアする
  static void clearCache() {
    _cachedIsPro = null;
  }

  /// キャッシュを強制設定する（テスト用など）
  static void setProCache(bool isPro) {
    _cachedIsPro = isPro;
  }

  /// 購入を復元する
  static Future<bool> restorePurchases() async {
    try {
      _cachedIsPro = null;
      await Purchases.restorePurchases();
      return await isProActive();
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      return false;
    }
  }

  /// パッケージ（消耗型・買い切り）を購入する
  static Future<bool> purchasePackage(Package package) async {
    try {
      _cachedIsPro = null;
      await Purchases.purchasePackage(package);
      final isProPackage = proProductIds.contains(package.storeProduct.identifier);
      if (!isProPackage) {
        final productId = package.storeProduct.identifier;
        int uses = 0;
        if (productId == 'com.yama.genbacalc.ai10') {
          uses = 10;
        } else {
          // RevenueCatダッシュボードのOfferingメタデータから付与回数を取得して追加する
          uses = await getUsesPerPurchase();
        }
        if (uses > 0) {
          await addUses(uses);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error purchasing package: $e');
      return false;
    }
  }
}
