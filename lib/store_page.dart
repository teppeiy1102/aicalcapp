import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'revenuecat_service.dart';
import 'l10n/app_localizations.dart';

class StorePage extends StatefulWidget {
  /// true の場合はプロ版購入画面として表示する。
  /// false（デフォルト）は AI 利用回数チャージ画面として表示する。
  final bool isProContext;

  const StorePage({super.key, this.isProContext = false});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage>
    with SingleTickerProviderStateMixin {
  List<Package> _allPackages = [];
  bool _isLoading = true;
  int _remainingUses = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ブランドカラー
  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _lightBlue = Color(0xFF42A5F5);
  static const Color _accentBlue = Color(0xFF0288D1);
  static const Color _gradientStart = Color(0xFF1976D2);
  static const Color _gradientEnd = Color(0xFF64B5F6);
  static const Color _surfaceWhite = Color(0xFFFFFFFF);
  static const Color _backgroundGrey = Color(0xFFF0F4FF);
  static const Color _textDark = Color(0xFF1A237E);
  static const Color _textMedium = Color(0xFF37474F);
  static const Color _textLight = Color(0xFF78909C);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final uses = await RevenueCatService.getRemainingUses();
    final packages = widget.isProContext
        ? await RevenueCatService.getProPackages()
        : await RevenueCatService.getAiChargePackages();
    setState(() {
      _remainingUses = uses;
      _allPackages = packages;
      _isLoading = false;
    });
    _animationController.forward(from: 0);
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isLoading = true);
    final success = await RevenueCatService.purchasePackage(package);
    final l10n = _l10n;
    if (success) {
      if (mounted) {
        _showResultSnackBar(l10n.storePurchaseComplete, isSuccess: true);
        if (widget.isProContext) {
          Navigator.pop(context, true);
          return;
        }
      }
    } else {
      if (mounted) {
        _showResultSnackBar(l10n.storePurchaseFailed, isSuccess: false);
      }
    }
    await _loadData();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  void _showResultSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF1565C0) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final title = widget.isProContext ? l10n.storeProTitle : l10n.storeAiTitle;

    return Scaffold(
      backgroundColor: _backgroundGrey,
      appBar: _buildAppBar(title),
      body: _isLoading
          ? _buildLoadingView()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroSection(),
                    _buildPackagesSection(),
                    _buildFeatureDescriptionSection(),
                    _buildNotesSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(String title) {
    final l10n = _l10n;
    return AppBar(
      backgroundColor: _surfaceWhite,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: _lightBlue.withOpacity(0.3),
      iconTheme: const IconThemeData(color: _primaryBlue),
      title: Text(
        title,
        style: const TextStyle(
          color: _textDark,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            setState(() => _isLoading = true);
            final isPro = await RevenueCatService.restorePurchases();
            setState(() => _isLoading = false);
            if (mounted) {
              _showResultSnackBar(
                isPro ? l10n.storeRestoredPro : l10n.storeNoRestore,
                isSuccess: isPro,
              );
              if (isPro && widget.isProContext) {
                Navigator.pop(context, true);
              }
            }
          },
          icon: const Icon(Icons.restore, size: 18, color: _accentBlue),
          label: Text(
            l10n.storeRestorePurchases,
            style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLoadingView() {
    final l10n = _l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _surfaceWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _lightBlue.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: _primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.loading,
            style: const TextStyle(color: _textLight, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gradientStart, Color(0xFF1E88E5), _gradientEnd],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: widget.isProContext ? _buildProHero() : _buildAiHero(),
    );
  }

  Widget _buildProHero() {
    final l10n = _l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
         Text(
            l10n.proVersion,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 50,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.proPermanentUnlock,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_open_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  l10n.proOneTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiHero() {
    final l10n = _l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Text(
            l10n.aiCharge,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 50,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.aiChargeDesc,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  l10n.aiCurrentRemaining,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_remainingUses',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: _primaryBlue,
                        height: 1.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        l10n.aiTimes,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureDescriptionSection() {
    if (widget.isProContext) {
      return _buildProFeatureDescription();
    } else {
      return _buildAiFeatureDescription();
    }
  }

  Widget _buildProFeatureDescription() {
    final l10n = _l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: l10n.proFeatures,
            subtitle: l10n.proFeaturesDesc,
          ),
          const Divider(height: 1, color: Color(0xFFE3EEFF)),
          _buildFeatureItem(
            icon: Icons.calculate_rounded,
            title: l10n.proFeatureAdvancedCalc,
            description: l10n.proFeatureAdvancedCalcDesc,
            color: const Color(0xFF1565C0),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.table_chart_rounded,
            title: l10n.proFeatureUnlimitedSheets,
            description: l10n.proFeatureUnlimitedSheetsDesc,
            color: const Color(0xFF0288D1),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.share_rounded,
            title: l10n.proFeatureExport,
            description: l10n.proFeatureExportDesc,
            color: const Color(0xFF0277BD),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.hub_rounded,
            title: l10n.proFeatureLinkGraph,
            description: l10n.proFeatureLinkGraphDesc,
            color: const Color(0xFF1565C0),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAiFeatureDescription() {
    final l10n = _l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: l10n.aiFeatures,
            subtitle: l10n.aiFeaturesDesc,
          ),
          const Divider(height: 1, color: Color(0xFFE3EEFF)),

          _buildFeatureItem(
            icon: Icons.functions_rounded,
            title: l10n.aiFeatureFormulaAssist,
            description: l10n.aiFeatureFormulaAssistDesc,
            color: const Color(0xFF0288D1),
          ),
  const Divider(height: 1, color: Color(0xFFE3EEFF)),
          _buildFeatureItem(
            icon: Icons.camera_alt_rounded,
            title: l10n.aiFeatureCounting,
            description: l10n.aiFeatureCountingDesc,
            color: const Color(0xFF0288D1),
          ),
          _buildDivider(),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryBlue.withOpacity(0.05), _lightBlue.withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _lightBlue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: _accentBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.aiFeatureConsumable,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textMedium,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textLight,
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textMedium,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 70,
      endIndent: 20,
      color: Color(0xFFF0F4FF),
    );
  }

  Widget _buildPackagesSection() {
    final l10n = _l10n;
    final sectionLabel = widget.isProContext ? l10n.planSelect : l10n.chargePlanSelect;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Text(
            sectionLabel,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
        ),
        _allPackages.isEmpty
            ? _buildEmptyPackages()
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _allPackages.length,
                itemBuilder: (context, index) {
                  return _buildPackageCard(_allPackages[index], index);
                },
              ),
      ],
    );
  }

  Widget _buildEmptyPackages() {
    final l10n = _l10n;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3EEFF)),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: _textLight),
          const SizedBox(height: 12),
          Text(
            l10n.noPlansAvailable,
            style: const TextStyle(fontSize: 15, color: _textMedium, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.tryAgainLater,
            style: const TextStyle(fontSize: 13, color: _textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Package package, int index) {
    final isRecommended = index == 0;
    final l10n = _l10n;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecommended ? _primaryBlue.withOpacity(0.4) : const Color(0xFFE3EEFF),
          width: isRecommended ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isRecommended
                ? _primaryBlue.withOpacity(0.12)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (isRecommended && _allPackages.length > 1)
            Positioned(
              top: 0,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_gradientStart, _gradientEnd],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Text(
                  l10n.recommended,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _gradientStart.withOpacity(0.15),
                        _gradientEnd.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    widget.isProContext
                        ? Icons.workspace_premium_rounded
                        : Icons.bolt_rounded,
                    size: 26,
                    color: _primaryBlue,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.storeProduct.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        package.storeProduct.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _textMedium,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildPurchaseButton(package),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton(Package package) {
    return GestureDetector(
      onTap: () => _purchasePackage(package),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_gradientStart, _gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          package.storeProduct.priceString,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    final l10n = _l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3EEFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: _accentBlue),
              const SizedBox(width: 8),
              Text(
                l10n.purchaseNotes,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._buildNoteItems(),
        ],
      ),
    );
  }

  List<Widget> _buildNoteItems() {
    final l10n = _l10n;
    final notes = widget.isProContext
        ? [
            l10n.purchaseNotesPro1,
            l10n.purchaseNotesPro2,
            l10n.purchaseNotesPro3,
            l10n.purchaseNotesPro4,
            l10n.purchaseNotesPro5,
          ]
        : [
            l10n.purchaseNotesAi1,
            l10n.purchaseNotesAi2,
            l10n.purchaseNotesAi3,
            l10n.purchaseNotesAi4,
            l10n.purchaseNotesAi5,
            l10n.purchaseNotesAi6,
          ];

    return notes
        .map(
          (note) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 12,
                color: _textMedium,
                height: 1.6,
              ),
            ),
          ),
        )
        .toList();
  }
}