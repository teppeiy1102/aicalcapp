import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'revenuecat_service.dart';


class StorePage extends StatefulWidget {
  /// true の場合はプロ版購入画面として表示する。
  /// false（デフォルト）は AI 利用回数チャージ画面として表示する。
  final bool isProContext;

  const StorePage({super.key, this.isProContext = false});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  List<Package> _allPackages = [];
  bool _isLoading = true;
  int _remainingUses = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final uses = await RevenueCatService.getRemainingUses();
    final packages = widget.isProContext
        ? await RevenueCatService.getProPackages()
        : await RevenueCatService.getAiChargePackages();

    setState(() {
      _remainingUses = uses;
      _allPackages = packages;
      _isLoading = false;
    });
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() {
      _isLoading = true;
    });

    final success = await RevenueCatService.purchasePackage(package);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('購入が完了しました。')),
        );
        // プロ版購入後は画面を閉じて前の画面に戻る
        if (widget.isProContext) {
          Navigator.pop(context, true);
          return;
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('購入をキャンセルしたか、エラーが発生しました。')),
        );
      }
    }

    // UIを更新
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final packages = _allPackages;
    final title = widget.isProContext ? 'プロ版を購入' : 'AI利用回数チャージ';
    final sectionLabel = widget.isProContext ? 'プロ版（買い切り）' : 'チャージプラン';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              final isPro = await RevenueCatService.restorePurchases();
              setState(() => _isLoading = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isPro ? '購入を復元しました（プロ版有効）' : '復元できる情報がありません')),
                );
                if (isPro && widget.isProContext) {
                  Navigator.pop(context, true);
                }
              }
            },
            child: const Text('購入を復元', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (widget.isProContext)
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    color: Colors.deepPurpleAccent.withOpacity(0.1),
                    width: double.infinity,
                    child: const Column(
                      children: [
                        Icon(Icons.workspace_premium, size: 48, color: Colors.amber),
                        SizedBox(height: 8),
                        Text(
                          'プロ版を購入すると、すべてのプロ機能が\n永久に利用可能になります。',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    color: Colors.blueAccent.withOpacity(0.1),
                    width: double.infinity,
                    child: Column(
                      children: [
                        const Text(
                          '現在の残回数',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_remainingUses 回',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  sectionLabel,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: packages.isEmpty
                      ? const Center(child: Text('現在購入できるプランがありません。'))
                      : ListView.builder(
                          itemCount: packages.length,
                          itemBuilder: (context, index) {
                            final package = packages[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: ListTile(
                                title: Text(package.storeProduct.title),
                                subtitle: Text(
                                  package.storeProduct.description,
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _purchasePackage(package),
                                  child: Text(package.storeProduct.priceString),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
