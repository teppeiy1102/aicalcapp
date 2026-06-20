import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Calc'**
  String get appTitle;

  /// No description provided for @genbaCalc.
  ///
  /// In en, this message translates to:
  /// **'Genba Calc'**
  String get genbaCalc;

  /// No description provided for @genbaCalcTagline.
  ///
  /// In en, this message translates to:
  /// **'Next-gen calculator for the field'**
  String get genbaCalcTagline;

  /// No description provided for @proLabel.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get proLabel;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @noSheets.
  ///
  /// In en, this message translates to:
  /// **'No sheets yet'**
  String get noSheets;

  /// No description provided for @noSheetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start the magic of automating your calculations'**
  String get noSheetsSubtitle;

  /// No description provided for @untitledSheet.
  ///
  /// In en, this message translates to:
  /// **'Untitled Sheet'**
  String get untitledSheet;

  /// No description provided for @newSheet.
  ///
  /// In en, this message translates to:
  /// **'New Sheet'**
  String get newSheet;

  /// No description provided for @standardCalc.
  ///
  /// In en, this message translates to:
  /// **'Standard Calc'**
  String get standardCalc;

  /// No description provided for @sampleCalc.
  ///
  /// In en, this message translates to:
  /// **'Sample Calculation'**
  String get sampleCalc;

  /// No description provided for @newCalc.
  ///
  /// In en, this message translates to:
  /// **'New Calc'**
  String get newCalc;

  /// No description provided for @deleteSheet.
  ///
  /// In en, this message translates to:
  /// **'Delete Sheet'**
  String get deleteSheet;

  /// No description provided for @deleteSheetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This action cannot be undone.'**
  String deleteSheetConfirm(Object title);

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteConfirm;

  /// No description provided for @duplicatedSheet.
  ///
  /// In en, this message translates to:
  /// **'Duplicated \"{title}\"'**
  String duplicatedSheet(Object title);

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String updatedAt(Object date);

  /// No description provided for @addedToNewSheet.
  ///
  /// In en, this message translates to:
  /// **'Added to new sheet'**
  String get addedToNewSheet;

  /// No description provided for @addedItemsToNewSheet.
  ///
  /// In en, this message translates to:
  /// **'Added {count} items to new sheet'**
  String addedItemsToNewSheet(Object count);

  /// No description provided for @generatedSheet.
  ///
  /// In en, this message translates to:
  /// **'Generated \"{title}\"'**
  String generatedSheet(Object title);

  /// No description provided for @aiLocalNotReady.
  ///
  /// In en, this message translates to:
  /// **'Local AI is not initialized.'**
  String get aiLocalNotReady;

  /// No description provided for @aiPurchaseRequired.
  ///
  /// In en, this message translates to:
  /// **'AI requires purchase'**
  String get aiPurchaseRequired;

  /// No description provided for @aiPurchaseRequiredDesc.
  ///
  /// In en, this message translates to:
  /// **'You need to charge AI usage credits to use AI features. Please purchase from the store page.'**
  String get aiPurchaseRequiredDesc;

  /// No description provided for @goToStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get goToStore;

  /// No description provided for @generatingFormula.
  ///
  /// In en, this message translates to:
  /// **'Generating formula...'**
  String get generatingFormula;

  /// No description provided for @generationFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed: {error}'**
  String generationFailed(Object error);

  /// No description provided for @mergeSheets.
  ///
  /// In en, this message translates to:
  /// **'Merge Calculation Sheets'**
  String get mergeSheets;

  /// No description provided for @mergeSheetsDesc.
  ///
  /// In en, this message translates to:
  /// **'Display multiple sheets side by side'**
  String get mergeSheetsDesc;

  /// No description provided for @mergedView.
  ///
  /// In en, this message translates to:
  /// **'Merged View'**
  String get mergedView;

  /// No description provided for @mergedSheetLabel.
  ///
  /// In en, this message translates to:
  /// **'({count}) Merged'**
  String mergedSheetLabel(Object count);

  /// No description provided for @proRequired.
  ///
  /// In en, this message translates to:
  /// **'Pro version required'**
  String get proRequired;

  /// No description provided for @proFeature.
  ///
  /// In en, this message translates to:
  /// **'Pro Feature'**
  String get proFeature;

  /// No description provided for @proFeatureDesc.
  ///
  /// In en, this message translates to:
  /// **'Please purchase the Pro version to use this feature.'**
  String get proFeatureDesc;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @upgradeToProUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro for unlimited sheets.'**
  String get upgradeToProUnlimited;

  /// No description provided for @sheetLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Sheet limit reached'**
  String get sheetLimitReached;

  /// No description provided for @sheetLimitDesc.
  ///
  /// In en, this message translates to:
  /// **'The free version allows up to 5 sheets.'**
  String get sheetLimitDesc;

  /// No description provided for @qrShare.
  ///
  /// In en, this message translates to:
  /// **'Share via QR'**
  String get qrShare;

  /// No description provided for @qrShareDesc.
  ///
  /// In en, this message translates to:
  /// **'Select sheets to export with QR code'**
  String get qrShareDesc;

  /// No description provided for @qrImport.
  ///
  /// In en, this message translates to:
  /// **'Import Sheet'**
  String get qrImport;

  /// No description provided for @qrImportDesc.
  ///
  /// In en, this message translates to:
  /// **'Import sheets from QR code'**
  String get qrImportDesc;

  /// No description provided for @noSharableSheets.
  ///
  /// In en, this message translates to:
  /// **'No sheets to share'**
  String get noSharableSheets;

  /// No description provided for @importComplete.
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get importComplete;

  /// No description provided for @importedSheet.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{result}\"'**
  String importedSheet(Object result);

  /// No description provided for @invalidQrCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid sheet QR code'**
  String get invalidQrCode;

  /// No description provided for @importedSheetDefault.
  ///
  /// In en, this message translates to:
  /// **'Imported Sheet'**
  String get importedSheetDefault;

  /// No description provided for @linkGraph.
  ///
  /// In en, this message translates to:
  /// **'Link Graph'**
  String get linkGraph;

  /// No description provided for @linkGraphDesc.
  ///
  /// In en, this message translates to:
  /// **'Visualize link relationships between sheets'**
  String get linkGraphDesc;

  /// No description provided for @select2OrMore.
  ///
  /// In en, this message translates to:
  /// **'Select 2 or more'**
  String get select2OrMore;

  /// No description provided for @selectingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectingCount(Object count);

  /// No description provided for @selectSheetsToShare.
  ///
  /// In en, this message translates to:
  /// **'Select sheets to share'**
  String get selectSheetsToShare;

  /// No description provided for @addSheetsCount.
  ///
  /// In en, this message translates to:
  /// **'Add {count} sheets'**
  String addSheetsCount(Object count);

  /// No description provided for @mergeSheetsCount.
  ///
  /// In en, this message translates to:
  /// **'Merge {count} sheets'**
  String mergeSheetsCount(Object count);

  /// No description provided for @select1OrMore.
  ///
  /// In en, this message translates to:
  /// **'Select 1 or more'**
  String get select1OrMore;

  /// No description provided for @shareSheetsCount.
  ///
  /// In en, this message translates to:
  /// **'Share {count} sheets'**
  String shareSheetsCount(Object count);

  /// No description provided for @pleaseSelect1OrMore.
  ///
  /// In en, this message translates to:
  /// **'Please select at least 1'**
  String get pleaseSelect1OrMore;

  /// No description provided for @addSheet.
  ///
  /// In en, this message translates to:
  /// **'Add Sheet'**
  String get addSheet;

  /// No description provided for @noFormulaSet.
  ///
  /// In en, this message translates to:
  /// **'No formula set'**
  String get noFormulaSet;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemCount(Object count);

  /// No description provided for @calcAddThis.
  ///
  /// In en, this message translates to:
  /// **'Add This Calculation'**
  String get calcAddThis;

  /// No description provided for @calcEnterThis.
  ///
  /// In en, this message translates to:
  /// **'Enter This Value'**
  String get calcEnterThis;

  /// No description provided for @aiPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter AI instructions... (e.g., calculate tax)'**
  String get aiPromptHint;

  /// No description provided for @aiGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get aiGenerate;

  /// No description provided for @aiCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get aiCreateNew;

  /// No description provided for @aiModify.
  ///
  /// In en, this message translates to:
  /// **'Modify / Add'**
  String get aiModify;

  /// No description provided for @aiCamera.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get aiCamera;

  /// No description provided for @aiGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get aiGallery;

  /// No description provided for @aiRemainingUses.
  ///
  /// In en, this message translates to:
  /// **'Remaining AI uses: {count} (Purchase more)'**
  String aiRemainingUses(Object count);

  /// No description provided for @proVersion.
  ///
  /// In en, this message translates to:
  /// **'Pro Version'**
  String get proVersion;

  /// No description provided for @proAllFeaturesAvailable.
  ///
  /// In en, this message translates to:
  /// **'All features available'**
  String get proAllFeaturesAvailable;

  /// No description provided for @proUnlockAll.
  ///
  /// In en, this message translates to:
  /// **'Unlock all features permanently (one-time purchase)'**
  String get proUnlockAll;

  /// No description provided for @proPurchased.
  ///
  /// In en, this message translates to:
  /// **'Purchased ✓'**
  String get proPurchased;

  /// No description provided for @proBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy →'**
  String get proBuy;

  /// No description provided for @aiCredits.
  ///
  /// In en, this message translates to:
  /// **'AI Credits'**
  String get aiCredits;

  /// No description provided for @aiCreditsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} remaining / Recharge anytime'**
  String aiCreditsRemaining(Object count);

  /// No description provided for @aiCreditsCharge.
  ///
  /// In en, this message translates to:
  /// **'Charge →'**
  String get aiCreditsCharge;

  /// No description provided for @aiCreditsNote.
  ///
  /// In en, this message translates to:
  /// **'AI credits accumulate. No expiration date.'**
  String get aiCreditsNote;

  /// No description provided for @settingsOperation.
  ///
  /// In en, this message translates to:
  /// **'Operation Settings'**
  String get settingsOperation;

  /// No description provided for @settingsVibrate.
  ///
  /// In en, this message translates to:
  /// **'Button Vibration'**
  String get settingsVibrate;

  /// No description provided for @settingsVibrateDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibrate feedback when tapping calculator buttons'**
  String get settingsVibrateDesc;

  /// No description provided for @settingsBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing & Purchase'**
  String get settingsBilling;

  /// No description provided for @userConstants.
  ///
  /// In en, this message translates to:
  /// **'User-Defined Constants'**
  String get userConstants;

  /// No description provided for @userConstantsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get userConstantsAdd;

  /// No description provided for @userConstantsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No constants yet\nTap \"Add\" in the top right to add'**
  String get userConstantsEmpty;

  /// No description provided for @userConstantsDesc.
  ///
  /// In en, this message translates to:
  /// **'User-defined constants appear in all sheets\' constant presets'**
  String get userConstantsDesc;

  /// No description provided for @builtinConstants.
  ///
  /// In en, this message translates to:
  /// **'Built-in Constants'**
  String get builtinConstants;

  /// No description provided for @addConstant.
  ///
  /// In en, this message translates to:
  /// **'Add Constant'**
  String get addConstant;

  /// No description provided for @editConstant.
  ///
  /// In en, this message translates to:
  /// **'Edit Constant'**
  String get editConstant;

  /// No description provided for @constantName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get constantName;

  /// No description provided for @constantNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Tax rate'**
  String get constantNameHint;

  /// No description provided for @constantValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get constantValue;

  /// No description provided for @constantValueHint.
  ///
  /// In en, this message translates to:
  /// **'0.0'**
  String get constantValueHint;

  /// No description provided for @storeProTitle.
  ///
  /// In en, this message translates to:
  /// **'Buy Pro Version'**
  String get storeProTitle;

  /// No description provided for @storeAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Usage Charge'**
  String get storeAiTitle;

  /// No description provided for @storePurchaseComplete.
  ///
  /// In en, this message translates to:
  /// **'Purchase completed 🎉'**
  String get storePurchaseComplete;

  /// No description provided for @storePurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase was cancelled or an error occurred.'**
  String get storePurchaseFailed;

  /// No description provided for @storeRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get storeRestorePurchases;

  /// No description provided for @storeRestoredPro.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored (Pro active) ✅'**
  String get storeRestoredPro;

  /// No description provided for @storeNoRestore.
  ///
  /// In en, this message translates to:
  /// **'No purchases to restore.'**
  String get storeNoRestore;

  /// No description provided for @proOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase, no additional fees'**
  String get proOneTime;

  /// No description provided for @proPermanentUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock all features permanently'**
  String get proPermanentUnlock;

  /// No description provided for @aiCharge.
  ///
  /// In en, this message translates to:
  /// **'AI Charge'**
  String get aiCharge;

  /// No description provided for @aiChargeDesc.
  ///
  /// In en, this message translates to:
  /// **'AI usage is charged based on the plan purchased'**
  String get aiChargeDesc;

  /// No description provided for @aiCurrentRemaining.
  ///
  /// In en, this message translates to:
  /// **'Current Remaining'**
  String get aiCurrentRemaining;

  /// No description provided for @aiTimes.
  ///
  /// In en, this message translates to:
  /// **'times'**
  String get aiTimes;

  /// No description provided for @proFeatures.
  ///
  /// In en, this message translates to:
  /// **'Pro Features'**
  String get proFeatures;

  /// No description provided for @proFeaturesDesc.
  ///
  /// In en, this message translates to:
  /// **'Purchase once, use forever'**
  String get proFeaturesDesc;

  /// No description provided for @proFeatureAdvancedCalc.
  ///
  /// In en, this message translates to:
  /// **'Unlock Advanced Calculation'**
  String get proFeatureAdvancedCalc;

  /// No description provided for @proFeatureAdvancedCalcDesc.
  ///
  /// In en, this message translates to:
  /// **'All advanced calculation features previously limited in the standard version become available, including complex formulas and variable calculations.'**
  String get proFeatureAdvancedCalcDesc;

  /// No description provided for @proFeatureUnlimitedSheets.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Sheets & Tables'**
  String get proFeatureUnlimitedSheets;

  /// No description provided for @proFeatureUnlimitedSheetsDesc.
  ///
  /// In en, this message translates to:
  /// **'Create unlimited sheets and tables. Suitable for large-scale projects.'**
  String get proFeatureUnlimitedSheetsDesc;

  /// No description provided for @proFeatureExport.
  ///
  /// In en, this message translates to:
  /// **'Data Export & Sharing'**
  String get proFeatureExport;

  /// No description provided for @proFeatureExportDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate QR codes and share calculation sheets on the spot. Export data in CSV and other formats to share with team members and clients.'**
  String get proFeatureExportDesc;

  /// No description provided for @proFeatureLinkGraph.
  ///
  /// In en, this message translates to:
  /// **'Full Link Graph Features'**
  String get proFeatureLinkGraph;

  /// No description provided for @proFeatureLinkGraphDesc.
  ///
  /// In en, this message translates to:
  /// **'The link graph feature for visually managing dependencies between calculators is fully unlocked.'**
  String get proFeatureLinkGraphDesc;

  /// No description provided for @aiFeatures.
  ///
  /// In en, this message translates to:
  /// **'AI Features'**
  String get aiFeatures;

  /// No description provided for @aiFeaturesDesc.
  ///
  /// In en, this message translates to:
  /// **'Use AI for the number of times charged'**
  String get aiFeaturesDesc;

  /// No description provided for @aiFeatureFormulaAssist.
  ///
  /// In en, this message translates to:
  /// **'AI Formula Assist'**
  String get aiFeatureFormulaAssist;

  /// No description provided for @aiFeatureFormulaAssistDesc.
  ///
  /// In en, this message translates to:
  /// **'AI supports creating complex formulas. Simply convey conditions in natural language to get appropriate formula suggestions.'**
  String get aiFeatureFormulaAssistDesc;

  /// No description provided for @aiFeatureCounting.
  ///
  /// In en, this message translates to:
  /// **'AI Counting'**
  String get aiFeatureCounting;

  /// No description provided for @aiFeatureCountingDesc.
  ///
  /// In en, this message translates to:
  /// **'AI counts specified items from images. Import counted values instantly into the calculator.'**
  String get aiFeatureCountingDesc;

  /// No description provided for @aiFeatureConsumable.
  ///
  /// In en, this message translates to:
  /// **'AI usage is consumable. Reflected in remaining count immediately after purchase. No expiration.'**
  String get aiFeatureConsumable;

  /// No description provided for @planSelect.
  ///
  /// In en, this message translates to:
  /// **'Plan Selection'**
  String get planSelect;

  /// No description provided for @chargePlanSelect.
  ///
  /// In en, this message translates to:
  /// **'Select Charge Plan'**
  String get chargePlanSelect;

  /// No description provided for @noPlansAvailable.
  ///
  /// In en, this message translates to:
  /// **'No plans currently available for purchase'**
  String get noPlansAvailable;

  /// No description provided for @tryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Please try again later'**
  String get tryAgainLater;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @purchaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Purchase Notes'**
  String get purchaseNotes;

  /// No description provided for @purchaseNotesPro1.
  ///
  /// In en, this message translates to:
  /// **'・The Pro version is a one-time purchase. Once purchased, you can use it permanently with no additional fees.'**
  String get purchaseNotesPro1;

  /// No description provided for @purchaseNotesPro2.
  ///
  /// In en, this message translates to:
  /// **'・Purchases are linked to your Apple ID account. You can use it across multiple devices by signing in with the same Apple ID.'**
  String get purchaseNotesPro2;

  /// No description provided for @purchaseNotesPro3.
  ///
  /// In en, this message translates to:
  /// **'・If you have previously purchased, you can resume use via \"Restore Purchases\" in the top right.'**
  String get purchaseNotesPro3;

  /// No description provided for @purchaseNotesPro4.
  ///
  /// In en, this message translates to:
  /// **'・Payments are processed through the App Store. Please check Apple\'s terms of use for details.'**
  String get purchaseNotesPro4;

  /// No description provided for @purchaseNotesPro5.
  ///
  /// In en, this message translates to:
  /// **'・Please contact support if you have any questions.'**
  String get purchaseNotesPro5;

  /// No description provided for @purchaseNotesAi1.
  ///
  /// In en, this message translates to:
  /// **'・Purchased AI usage is consumable. One use is consumed each time you use AI.'**
  String get purchaseNotesAi1;

  /// No description provided for @purchaseNotesAi2.
  ///
  /// In en, this message translates to:
  /// **'・No expiration date. Purchased uses can be used at any time.'**
  String get purchaseNotesAi2;

  /// No description provided for @purchaseNotesAi3.
  ///
  /// In en, this message translates to:
  /// **'・Purchases are linked to your Apple ID account. You can use it across multiple devices by signing in with the same Apple ID.'**
  String get purchaseNotesAi3;

  /// No description provided for @purchaseNotesAi4.
  ///
  /// In en, this message translates to:
  /// **'・If your credits run low, you can always add more.'**
  String get purchaseNotesAi4;

  /// No description provided for @purchaseNotesAi5.
  ///
  /// In en, this message translates to:
  /// **'・Payments are processed through the App Store. Please check Apple\'s terms of use for details.'**
  String get purchaseNotesAi5;

  /// No description provided for @purchaseNotesAi6.
  ///
  /// In en, this message translates to:
  /// **'・The \"Restore Purchases\" function is for restoring the Pro version. It does not apply to AI usage restoration.'**
  String get purchaseNotesAi6;

  /// No description provided for @calcName.
  ///
  /// In en, this message translates to:
  /// **'Calc {n}'**
  String calcName(Object n);

  /// No description provided for @calcTerm1.
  ///
  /// In en, this message translates to:
  /// **'Term 1'**
  String get calcTerm1;

  /// No description provided for @calcTerm2.
  ///
  /// In en, this message translates to:
  /// **'Term 2'**
  String get calcTerm2;

  /// No description provided for @calcTermOther.
  ///
  /// In en, this message translates to:
  /// **'Term {n}'**
  String calcTermOther(Object n);

  /// No description provided for @calcAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get calcAnswer;

  /// No description provided for @calcLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get calcLink;

  /// No description provided for @constant.
  ///
  /// In en, this message translates to:
  /// **'Constant'**
  String get constant;

  /// No description provided for @noCondition.
  ///
  /// In en, this message translates to:
  /// **'(no condition)'**
  String get noCondition;

  /// No description provided for @logicOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get logicOr;

  /// No description provided for @logicXor.
  ///
  /// In en, this message translates to:
  /// **'either'**
  String get logicXor;

  /// No description provided for @logicAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get logicAnd;

  /// No description provided for @multipleOf.
  ///
  /// In en, this message translates to:
  /// **'{a} is a multiple of {b}'**
  String multipleOf(Object a, Object b);

  /// No description provided for @copiedItem.
  ///
  /// In en, this message translates to:
  /// **'Copied \"{name}\"'**
  String copiedItem(Object name);

  /// No description provided for @cutItem.
  ///
  /// In en, this message translates to:
  /// **'Cut \"{name}\"'**
  String cutItem(Object name);

  /// No description provided for @imageAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Image analysis failed'**
  String get imageAnalysisFailed;

  /// No description provided for @addMemo.
  ///
  /// In en, this message translates to:
  /// **'Add Memo'**
  String get addMemo;

  /// No description provided for @memoTitle.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get memoTitle;

  /// No description provided for @formulaWrap.
  ///
  /// In en, this message translates to:
  /// **'Wrap Formula'**
  String get formulaWrap;

  /// No description provided for @formulaUnwrap.
  ///
  /// In en, this message translates to:
  /// **'Unwrap Formula'**
  String get formulaUnwrap;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @qrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get qrCode;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQr;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @piLabel.
  ///
  /// In en, this message translates to:
  /// **'π (Pi)'**
  String get piLabel;

  /// No description provided for @eLabel.
  ///
  /// In en, this message translates to:
  /// **'e (Natural log base)'**
  String get eLabel;

  /// No description provided for @gLabel.
  ///
  /// In en, this message translates to:
  /// **'g (Gravity)'**
  String get gLabel;

  /// No description provided for @phiLabel.
  ///
  /// In en, this message translates to:
  /// **'φ (Golden ratio)'**
  String get phiLabel;

  /// No description provided for @cLabel.
  ///
  /// In en, this message translates to:
  /// **'c (Speed of light m/s)'**
  String get cLabel;

  /// No description provided for @viewMode.
  ///
  /// In en, this message translates to:
  /// **'View Mode'**
  String get viewMode;

  /// No description provided for @editMode.
  ///
  /// In en, this message translates to:
  /// **'Edit Mode'**
  String get editMode;

  /// No description provided for @tableMode.
  ///
  /// In en, this message translates to:
  /// **'Table Mode'**
  String get tableMode;

  /// No description provided for @toggleNames.
  ///
  /// In en, this message translates to:
  /// **'Toggle Names'**
  String get toggleNames;

  /// No description provided for @insertCalcBelow.
  ///
  /// In en, this message translates to:
  /// **'Insert Calc Below'**
  String get insertCalcBelow;

  /// No description provided for @insertMemoBelow.
  ///
  /// In en, this message translates to:
  /// **'Insert Memo Below'**
  String get insertMemoBelow;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @cut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get moveDown;

  /// No description provided for @expose.
  ///
  /// In en, this message translates to:
  /// **'Expose'**
  String get expose;

  /// No description provided for @linkSettings.
  ///
  /// In en, this message translates to:
  /// **'Link Settings'**
  String get linkSettings;

  /// No description provided for @addTerm.
  ///
  /// In en, this message translates to:
  /// **'Add Term'**
  String get addTerm;

  /// No description provided for @brackets.
  ///
  /// In en, this message translates to:
  /// **'Brackets'**
  String get brackets;

  /// No description provided for @exposed.
  ///
  /// In en, this message translates to:
  /// **'Exposed'**
  String get exposed;

  /// No description provided for @notExposed.
  ///
  /// In en, this message translates to:
  /// **'Not Exposed'**
  String get notExposed;

  /// No description provided for @sheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Sheet Title'**
  String get sheetTitle;

  /// No description provided for @sheetBackground.
  ///
  /// In en, this message translates to:
  /// **'Sheet Background'**
  String get sheetBackground;

  /// No description provided for @displayOrder.
  ///
  /// In en, this message translates to:
  /// **'Display Order'**
  String get displayOrder;

  /// No description provided for @addStandaloneMemo.
  ///
  /// In en, this message translates to:
  /// **'Add Standalone Memo'**
  String get addStandaloneMemo;

  /// No description provided for @addLogicItem.
  ///
  /// In en, this message translates to:
  /// **'Add Logic Item'**
  String get addLogicItem;

  /// No description provided for @addSheetConstant.
  ///
  /// In en, this message translates to:
  /// **'Add Sheet Constant'**
  String get addSheetConstant;

  /// No description provided for @copyFormula.
  ///
  /// In en, this message translates to:
  /// **'Copy formula: {name}'**
  String copyFormula(Object name);

  /// No description provided for @copyAnswer.
  ///
  /// In en, this message translates to:
  /// **'Copy answer: {value}'**
  String copyAnswer(Object value);

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @logicItemEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Logic'**
  String get logicItemEdit;

  /// No description provided for @logicItemNew.
  ///
  /// In en, this message translates to:
  /// **'New Logic'**
  String get logicItemNew;

  /// No description provided for @logicName.
  ///
  /// In en, this message translates to:
  /// **'Logic Name'**
  String get logicName;

  /// No description provided for @logicConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get logicConditions;

  /// No description provided for @logicAddCondition.
  ///
  /// In en, this message translates to:
  /// **'Add Condition'**
  String get logicAddCondition;

  /// No description provided for @logicLhs.
  ///
  /// In en, this message translates to:
  /// **'Left side'**
  String get logicLhs;

  /// No description provided for @logicOp.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get logicOp;

  /// No description provided for @logicRhs.
  ///
  /// In en, this message translates to:
  /// **'Right side'**
  String get logicRhs;

  /// No description provided for @logicRhs2.
  ///
  /// In en, this message translates to:
  /// **'Right side 2'**
  String get logicRhs2;

  /// No description provided for @logicChain.
  ///
  /// In en, this message translates to:
  /// **'Chain'**
  String get logicChain;

  /// No description provided for @logicChainAnd.
  ///
  /// In en, this message translates to:
  /// **'AND'**
  String get logicChainAnd;

  /// No description provided for @logicChainOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get logicChainOr;

  /// No description provided for @logicChainXor.
  ///
  /// In en, this message translates to:
  /// **'XOR'**
  String get logicChainXor;

  /// No description provided for @linkSourceDialog.
  ///
  /// In en, this message translates to:
  /// **'Link Source'**
  String get linkSourceDialog;

  /// No description provided for @linkSourceSameSheet.
  ///
  /// In en, this message translates to:
  /// **'Same Sheet'**
  String get linkSourceSameSheet;

  /// No description provided for @linkSourceOtherSheet.
  ///
  /// In en, this message translates to:
  /// **'Other Sheet'**
  String get linkSourceOtherSheet;

  /// No description provided for @linkSourceConstant.
  ///
  /// In en, this message translates to:
  /// **'Constant'**
  String get linkSourceConstant;

  /// No description provided for @linkSourceLogic.
  ///
  /// In en, this message translates to:
  /// **'Logic Result'**
  String get linkSourceLogic;

  /// No description provided for @linkSourceGlobalConstant.
  ///
  /// In en, this message translates to:
  /// **'Global Constant'**
  String get linkSourceGlobalConstant;

  /// No description provided for @linkTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get linkTarget;

  /// No description provided for @linkTargetResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get linkTargetResult;

  /// No description provided for @linkTargetInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get linkTargetInput;

  /// No description provided for @linkTargetOperand.
  ///
  /// In en, this message translates to:
  /// **'Operand'**
  String get linkTargetOperand;

  /// No description provided for @transformDialog.
  ///
  /// In en, this message translates to:
  /// **'Transform'**
  String get transformDialog;

  /// No description provided for @transformNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get transformNone;

  /// No description provided for @transformPow.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get transformPow;

  /// No description provided for @transformPowExp.
  ///
  /// In en, this message translates to:
  /// **'Exponent'**
  String get transformPowExp;

  /// No description provided for @transformDiv.
  ///
  /// In en, this message translates to:
  /// **'Divide by'**
  String get transformDiv;

  /// No description provided for @transformMul.
  ///
  /// In en, this message translates to:
  /// **'Multiply by'**
  String get transformMul;

  /// No description provided for @transformAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get transformAdd;

  /// No description provided for @transformSub.
  ///
  /// In en, this message translates to:
  /// **'Subtract'**
  String get transformSub;

  /// No description provided for @precision.
  ///
  /// In en, this message translates to:
  /// **'Precision'**
  String get precision;

  /// No description provided for @precisionZero.
  ///
  /// In en, this message translates to:
  /// **'No decimals'**
  String get precisionZero;

  /// No description provided for @precision1.
  ///
  /// In en, this message translates to:
  /// **'1 decimal'**
  String get precision1;

  /// No description provided for @precision2.
  ///
  /// In en, this message translates to:
  /// **'2 decimals'**
  String get precision2;

  /// No description provided for @precision3.
  ///
  /// In en, this message translates to:
  /// **'3 decimals'**
  String get precision3;

  /// No description provided for @precision4.
  ///
  /// In en, this message translates to:
  /// **'4 decimals'**
  String get precision4;

  /// No description provided for @sheetColor.
  ///
  /// In en, this message translates to:
  /// **'Sheet Color'**
  String get sheetColor;

  /// No description provided for @colorLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get colorLight;

  /// No description provided for @colorDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get colorDark;

  /// No description provided for @memoPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter memo...'**
  String get memoPlaceholder;

  /// No description provided for @addBrackets.
  ///
  /// In en, this message translates to:
  /// **'Add Brackets'**
  String get addBrackets;

  /// No description provided for @removeBrackets.
  ///
  /// In en, this message translates to:
  /// **'Remove Brackets'**
  String get removeBrackets;

  /// No description provided for @bracketStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get bracketStart;

  /// No description provided for @bracketEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get bracketEnd;

  /// No description provided for @insertItem.
  ///
  /// In en, this message translates to:
  /// **'Insert Item'**
  String get insertItem;

  /// No description provided for @deleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get deleteItem;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history'**
  String get noHistory;

  /// No description provided for @addToSheet.
  ///
  /// In en, this message translates to:
  /// **'Add to Sheet'**
  String get addToSheet;

  /// No description provided for @importQrDialog.
  ///
  /// In en, this message translates to:
  /// **'Import via QR'**
  String get importQrDialog;

  /// No description provided for @importQrDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan QR codes to import sheets'**
  String get importQrDesc;

  /// No description provided for @cameraMode.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraMode;

  /// No description provided for @imageMode.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get imageMode;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanning;

  /// No description provided for @scanComplete.
  ///
  /// In en, this message translates to:
  /// **'Scan Complete'**
  String get scanComplete;

  /// No description provided for @collectingParts.
  ///
  /// In en, this message translates to:
  /// **'Collecting parts... ({current}/{total})'**
  String collectingParts(Object current, Object total);

  /// No description provided for @aiCountDialog.
  ///
  /// In en, this message translates to:
  /// **'AI Count'**
  String get aiCountDialog;

  /// No description provided for @aiCountDesc.
  ///
  /// In en, this message translates to:
  /// **'Take a photo and AI will count the specified items'**
  String get aiCountDesc;

  /// No description provided for @aiCountPrompt.
  ///
  /// In en, this message translates to:
  /// **'What to count (e.g., people, objects)'**
  String get aiCountPrompt;

  /// No description provided for @aiCountStart.
  ///
  /// In en, this message translates to:
  /// **'Start Counting'**
  String get aiCountStart;

  /// No description provided for @aiCounting.
  ///
  /// In en, this message translates to:
  /// **'Counting...'**
  String get aiCounting;

  /// No description provided for @aiCountResult.
  ///
  /// In en, this message translates to:
  /// **'Count Result'**
  String get aiCountResult;

  /// No description provided for @homeAiGenerateDialog.
  ///
  /// In en, this message translates to:
  /// **'AI Generate Sheet'**
  String get homeAiGenerateDialog;

  /// No description provided for @homeAiGenerateDesc.
  ///
  /// In en, this message translates to:
  /// **'Describe the calculation and AI will build a sheet for you'**
  String get homeAiGenerateDesc;

  /// No description provided for @homeAiGenerateImage.
  ///
  /// In en, this message translates to:
  /// **'Or attach an image for analysis'**
  String get homeAiGenerateImage;

  /// No description provided for @mergedReorderSheets.
  ///
  /// In en, this message translates to:
  /// **'Reorder Sheets'**
  String get mergedReorderSheets;

  /// No description provided for @mergedAddSheet.
  ///
  /// In en, this message translates to:
  /// **'Add Sheet'**
  String get mergedAddSheet;

  /// No description provided for @mergedRemoveSheet.
  ///
  /// In en, this message translates to:
  /// **'Remove Sheet'**
  String get mergedRemoveSheet;

  /// No description provided for @clipboardBar.
  ///
  /// In en, this message translates to:
  /// **'Clipboard: {name}'**
  String clipboardBar(Object name);

  /// No description provided for @clipboardBarClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clipboardBarClear;

  /// No description provided for @aiModelLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Model'**
  String get aiModelLabel;

  /// No description provided for @aiModelLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get aiModelLocal;

  /// No description provided for @aiModelCloudGemma.
  ///
  /// In en, this message translates to:
  /// **'Cloud (Gemma)'**
  String get aiModelCloudGemma;

  /// No description provided for @aiModelCloudGemini.
  ///
  /// In en, this message translates to:
  /// **'Cloud (Gemini)'**
  String get aiModelCloudGemini;

  /// No description provided for @proUpgradeBanner.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro for unlimited features'**
  String get proUpgradeBanner;

  /// No description provided for @decide.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get decide;

  /// No description provided for @noLinkableSheets.
  ///
  /// In en, this message translates to:
  /// **'No linkable sheets'**
  String get noLinkableSheets;

  /// No description provided for @noFormulas.
  ///
  /// In en, this message translates to:
  /// **'No formulas'**
  String get noFormulas;

  /// No description provided for @noLinkableConstants.
  ///
  /// In en, this message translates to:
  /// **'No linkable constants'**
  String get noLinkableConstants;

  /// No description provided for @sheetConstants.
  ///
  /// In en, this message translates to:
  /// **'Sheet Constants'**
  String get sheetConstants;

  /// No description provided for @globalConstants.
  ///
  /// In en, this message translates to:
  /// **'Global Constants'**
  String get globalConstants;

  /// No description provided for @selectLinkSource.
  ///
  /// In en, this message translates to:
  /// **'Select link source'**
  String get selectLinkSource;

  /// No description provided for @thisSheet.
  ///
  /// In en, this message translates to:
  /// **'This sheet'**
  String get thisSheet;

  /// No description provided for @exposedFormulas.
  ///
  /// In en, this message translates to:
  /// **'Exposed formulas'**
  String get exposedFormulas;

  /// No description provided for @mergedSheet.
  ///
  /// In en, this message translates to:
  /// **'Merged sheet'**
  String get mergedSheet;

  /// No description provided for @editColumnName.
  ///
  /// In en, this message translates to:
  /// **'Edit Column Name'**
  String get editColumnName;

  /// No description provided for @columnName.
  ///
  /// In en, this message translates to:
  /// **'Column Name'**
  String get columnName;

  /// No description provided for @columnSettings.
  ///
  /// In en, this message translates to:
  /// **'Column Settings'**
  String get columnSettings;

  /// No description provided for @columnDisplaySettings.
  ///
  /// In en, this message translates to:
  /// **'Column Display Settings'**
  String get columnDisplaySettings;

  /// No description provided for @trueLabel.
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get trueLabel;

  /// No description provided for @falseLabel.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get falseLabel;

  /// No description provided for @opNotEqual.
  ///
  /// In en, this message translates to:
  /// **'≠ (Not equal)'**
  String get opNotEqual;

  /// No description provided for @opBetween.
  ///
  /// In en, this message translates to:
  /// **'Within range (a ≤ x ≤ b)'**
  String get opBetween;

  /// No description provided for @opNotBetween.
  ///
  /// In en, this message translates to:
  /// **'Out of range (x < a or x > b)'**
  String get opNotBetween;

  /// No description provided for @opDivisible.
  ///
  /// In en, this message translates to:
  /// **'Multiple check (x is multiple of n)'**
  String get opDivisible;

  /// No description provided for @conditionN.
  ///
  /// In en, this message translates to:
  /// **'Condition {n}'**
  String conditionN(Object n);

  /// No description provided for @leftSide.
  ///
  /// In en, this message translates to:
  /// **'Left side (value)'**
  String get leftSide;

  /// No description provided for @operatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get operatorLabel;

  /// No description provided for @rightSide.
  ///
  /// In en, this message translates to:
  /// **'Right side (value)'**
  String get rightSide;

  /// No description provided for @lowerLimit.
  ///
  /// In en, this message translates to:
  /// **'Lower limit (a)'**
  String get lowerLimit;

  /// No description provided for @upperLimit.
  ///
  /// In en, this message translates to:
  /// **'Upper limit (b)'**
  String get upperLimit;

  /// No description provided for @divisor.
  ///
  /// In en, this message translates to:
  /// **'Divisor (n)'**
  String get divisor;

  /// No description provided for @editLogic.
  ///
  /// In en, this message translates to:
  /// **'Edit Logic'**
  String get editLogic;

  /// No description provided for @nameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get nameOptional;

  /// No description provided for @logicNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Range check'**
  String get logicNameHint;

  /// No description provided for @addCondition.
  ///
  /// In en, this message translates to:
  /// **'Add Condition'**
  String get addCondition;

  /// No description provided for @valueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get valueLabel;

  /// No description provided for @labelOptional.
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get labelOptional;

  /// No description provided for @backToCamera.
  ///
  /// In en, this message translates to:
  /// **'Back to Camera'**
  String get backToCamera;

  /// No description provided for @deleteTerm.
  ///
  /// In en, this message translates to:
  /// **'Delete term'**
  String get deleteTerm;

  /// No description provided for @showAllNodes.
  ///
  /// In en, this message translates to:
  /// **'Show All Nodes'**
  String get showAllNodes;

  /// No description provided for @layoutCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating layout...'**
  String get layoutCalculating;

  /// No description provided for @noConnections.
  ///
  /// In en, this message translates to:
  /// **'No connections'**
  String get noConnections;

  /// No description provided for @linkSource.
  ///
  /// In en, this message translates to:
  /// **'Link source'**
  String get linkSource;

  /// No description provided for @unknownLogic.
  ///
  /// In en, this message translates to:
  /// **'Unknown logic'**
  String get unknownLogic;

  /// No description provided for @noSettingLogicYet.
  ///
  /// In en, this message translates to:
  /// **'No logic expressions configured. Add one from the button above.'**
  String get noSettingLogicYet;

  /// No description provided for @selectLogic.
  ///
  /// In en, this message translates to:
  /// **'Select logic'**
  String get selectLogic;

  /// No description provided for @addLogic.
  ///
  /// In en, this message translates to:
  /// **'Add Logic'**
  String get addLogic;

  /// No description provided for @constantLink.
  ///
  /// In en, this message translates to:
  /// **'Link from constant'**
  String get constantLink;

  /// No description provided for @optionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get optionsLabel;

  /// No description provided for @linkSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Link settings'**
  String get linkSettingsHint;

  /// No description provided for @makeLinkSource.
  ///
  /// In en, this message translates to:
  /// **'Make source'**
  String get makeLinkSource;

  /// No description provided for @makeLinkTarget.
  ///
  /// In en, this message translates to:
  /// **'Make target'**
  String get makeLinkTarget;

  /// No description provided for @logicLink.
  ///
  /// In en, this message translates to:
  /// **'Logic link'**
  String get logicLink;

  /// No description provided for @trueValue.
  ///
  /// In en, this message translates to:
  /// **'Value when true'**
  String get trueValue;

  /// No description provided for @falseValue.
  ///
  /// In en, this message translates to:
  /// **'Value when false'**
  String get falseValue;

  /// No description provided for @linking.
  ///
  /// In en, this message translates to:
  /// **'Linking'**
  String get linking;

  /// No description provided for @logicLinking.
  ///
  /// In en, this message translates to:
  /// **'Logic linking'**
  String get logicLinking;

  /// No description provided for @unlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlink;

  /// No description provided for @restoreLink.
  ///
  /// In en, this message translates to:
  /// **'Restore link'**
  String get restoreLink;

  /// No description provided for @transformSection.
  ///
  /// In en, this message translates to:
  /// **'Transform (optional)'**
  String get transformSection;

  /// No description provided for @noTransform.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noTransform;

  /// No description provided for @transformSqrt.
  ///
  /// In en, this message translates to:
  /// **'√ Square root'**
  String get transformSqrt;

  /// No description provided for @transformNroot.
  ///
  /// In en, this message translates to:
  /// **'n-th root'**
  String get transformNroot;

  /// No description provided for @transformAbs.
  ///
  /// In en, this message translates to:
  /// **'|x| Absolute'**
  String get transformAbs;

  /// No description provided for @transformFloor.
  ///
  /// In en, this message translates to:
  /// **'⌊x⌋ Floor'**
  String get transformFloor;

  /// No description provided for @transformCeil.
  ///
  /// In en, this message translates to:
  /// **'⌈x⌉ Ceil'**
  String get transformCeil;

  /// No description provided for @transformRound.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get transformRound;

  /// No description provided for @transformLog10.
  ///
  /// In en, this message translates to:
  /// **'log10 (Logarithm)'**
  String get transformLog10;

  /// No description provided for @transformReciprocal.
  ///
  /// In en, this message translates to:
  /// **'1/x Reciprocal'**
  String get transformReciprocal;

  /// No description provided for @transformSin.
  ///
  /// In en, this message translates to:
  /// **'sin'**
  String get transformSin;

  /// No description provided for @transformCos.
  ///
  /// In en, this message translates to:
  /// **'cos'**
  String get transformCos;

  /// No description provided for @transformTan.
  ///
  /// In en, this message translates to:
  /// **'tan'**
  String get transformTan;

  /// No description provided for @powExponentQ.
  ///
  /// In en, this message translates to:
  /// **'Power (n):'**
  String get powExponentQ;

  /// No description provided for @nrootExponentQ.
  ///
  /// In en, this message translates to:
  /// **'Root (n):'**
  String get nrootExponentQ;

  /// No description provided for @unitCategoryCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get unitCategoryCommon;

  /// No description provided for @unitCategoryCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency / Finance'**
  String get unitCategoryCurrency;

  /// No description provided for @unitCategoryRatio.
  ///
  /// In en, this message translates to:
  /// **'Ratio / Number'**
  String get unitCategoryRatio;

  /// No description provided for @unitCategoryTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get unitCategoryTime;

  /// No description provided for @unitCategoryWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get unitCategoryWeight;

  /// No description provided for @unitCategoryLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get unitCategoryLength;

  /// No description provided for @unitCategoryVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get unitCategoryVolume;

  /// No description provided for @unitCategoryArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get unitCategoryArea;

  /// No description provided for @unitCategoryTemp.
  ///
  /// In en, this message translates to:
  /// **'Temperature / Pressure'**
  String get unitCategoryTemp;

  /// No description provided for @unitCategorySpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed / Power'**
  String get unitCategorySpeed;

  /// No description provided for @applyNumberToAll.
  ///
  /// In en, this message translates to:
  /// **'Apply number to all other rows'**
  String get applyNumberToAll;

  /// No description provided for @calcHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Calculation History'**
  String get calcHistoryTitle;

  /// No description provided for @calcHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get calcHistoryEmpty;

  /// No description provided for @clearHistoryAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearHistoryAll;

  /// No description provided for @unitSelectFromCategory.
  ///
  /// In en, this message translates to:
  /// **'Select from category'**
  String get unitSelectFromCategory;

  /// No description provided for @editItemSettings.
  ///
  /// In en, this message translates to:
  /// **'Item Settings'**
  String get editItemSettings;

  /// No description provided for @calcNameExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., Tax calculation'**
  String get calcNameExample;

  /// No description provided for @unitSettings.
  ///
  /// In en, this message translates to:
  /// **'Unit settings'**
  String get unitSettings;

  /// No description provided for @unitForTerm1.
  ///
  /// In en, this message translates to:
  /// **'Unit for term 1'**
  String get unitForTerm1;

  /// No description provided for @unitForTerm2.
  ///
  /// In en, this message translates to:
  /// **'Unit for term 2'**
  String get unitForTerm2;

  /// No description provided for @unitForResult.
  ///
  /// In en, this message translates to:
  /// **'Unit for result'**
  String get unitForResult;

  /// No description provided for @linkSettingsWarning.
  ///
  /// In en, this message translates to:
  /// **'There are link settings'**
  String get linkSettingsWarning;

  /// No description provided for @linkSettingsWarningDesc.
  ///
  /// In en, this message translates to:
  /// **'How would you like to apply?'**
  String get linkSettingsWarningDesc;

  /// No description provided for @skipLinkedApply.
  ///
  /// In en, this message translates to:
  /// **'Apply except linked values'**
  String get skipLinkedApply;

  /// No description provided for @overwriteApply.
  ///
  /// In en, this message translates to:
  /// **'Overwrite and apply'**
  String get overwriteApply;

  /// No description provided for @selectUnitFromCategory.
  ///
  /// In en, this message translates to:
  /// **'Select unit from category'**
  String get selectUnitFromCategory;

  /// No description provided for @customTextInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter any text'**
  String get customTextInputHint;

  /// No description provided for @usedUnits.
  ///
  /// In en, this message translates to:
  /// **'Used units'**
  String get usedUnits;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Calculation name'**
  String get editName;

  /// No description provided for @precisionDecimalPlaces.
  ///
  /// In en, this message translates to:
  /// **'Decimal places'**
  String get precisionDecimalPlaces;

  /// No description provided for @formulaDetails.
  ///
  /// In en, this message translates to:
  /// **'Formula details'**
  String get formulaDetails;

  /// No description provided for @resultSettings.
  ///
  /// In en, this message translates to:
  /// **'Result settings'**
  String get resultSettings;

  /// No description provided for @appliedToAllExceptLinked.
  ///
  /// In en, this message translates to:
  /// **'Applied to all except linked'**
  String get appliedToAllExceptLinked;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
