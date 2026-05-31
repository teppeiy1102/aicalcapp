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

/// グラデーション「PRO」バッジウィジェット
class ProBadge extends StatelessWidget {
  final double fontSize;
  final EdgeInsets padding;

  const ProBadge({
    super.key,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF6B6B),
            Color(0xFFFF9F43),
            Color(0xFFFFD93D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'PRO',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          height: 1.0,
        ),
      ),
    );
  }
}

/// プロ機能に必要な説明テキストをグラデーションで表示するウィジェット
class ProRequiredLabel extends StatelessWidget {
  final String text;

  const ProRequiredLabel({
    super.key,
    this.text = 'プロ版が必要です',
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFFFF6B6B),
          Color(0xFFFF9F43),
          Color(0xFFFFD93D),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// シート追加上限に達したときの Pro アップグレードダイアログを表示する
Future<void> showSheetLimitDialog(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF161625),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const ProBadge(fontSize: 12, padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'シートの上限に達しました',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '無料版では最大5枚までシートを作成できます。',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B6B).withOpacity(0.12),
                  const Color(0xFFFFD93D).withOpacity(0.08),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF9F43).withOpacity(0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD93D), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'プロ版にアップグレードするとシートを無制限に作成できます。',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('キャンセル', style: TextStyle(color: Colors.white38)),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF6B6B),
                Color(0xFFFF9F43),
                Color(0xFFFFD93D),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                ctx,
                MaterialPageRoute(builder: (_) => const StorePage(isProContext: true)),
              );
            },
            child: const Text(
              'プロ版にアップグレード',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
