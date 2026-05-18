import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'revenuecat_service.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  List<Package> _packages = [];
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
    final packages = await RevenueCatService.getOfferings();

    setState(() {
      _remainingUses = uses;
      _packages = packages;
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
          const SnackBar(content: Text('購入が完了しました。AI利用回数が追加されました。')),
        );
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
    return Scaffold(
      appBar: AppBar(title: const Text('AI利用回数のチャージ')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                const Text(
                  'チャージプラン',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _packages.isEmpty
                      ? const Center(child: Text('現在購入できるプランがありません。'))
                      : ListView.builder(
                          itemCount: _packages.length,
                          itemBuilder: (context, index) {
                            final package = _packages[index];
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
