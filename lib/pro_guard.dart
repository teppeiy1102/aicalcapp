import 'package:flutter/material.dart';
import 'revenuecat_service.dart';
import 'store_page.dart';

class ProGuard {
  static Future<void> checkAndRun(BuildContext context, VoidCallback onSuccess) async {
    final isPro = await RevenueCatService.isProActive();
    if (isPro) {
      onSuccess();
    } else {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('プロ版の機能です'),
          content: const Text('この機能を利用するには、プロ版を購入してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StorePage(isProContext: true)),
                );
              },
              child: const Text('ストアへ'),
            ),
          ],
        ),
      );
    }
  }
}
