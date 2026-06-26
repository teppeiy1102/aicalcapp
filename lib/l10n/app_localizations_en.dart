// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Calc';

  @override
  String get genbaCalc => 'Genba Calc';

  @override
  String get genbaCalcTagline => 'Next-gen calculator for the field';

  @override
  String get proLabel => 'Pro';

  @override
  String get menu => 'Menu';

  @override
  String get settings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get loading => 'Loading...';

  @override
  String get ok => 'OK';

  @override
  String get noSheets => 'No sheets yet';

  @override
  String get noSheetsSubtitle =>
      'Start the magic of automating your calculations';

  @override
  String get untitledSheet => 'Untitled Sheet';

  @override
  String get newSheet => 'New Sheet';

  @override
  String get standardCalc => 'Standard Calc';

  @override
  String get sampleCalc => 'Sample Calculation';

  @override
  String get newCalc => 'New Calc';

  @override
  String get deleteSheet => 'Delete Sheet';

  @override
  String deleteSheetConfirm(Object title) {
    return 'Delete \"$title\"? This action cannot be undone.';
  }

  @override
  String get deleteConfirm => 'Delete';

  @override
  String duplicatedSheet(Object title) {
    return 'Duplicated \"$title\"';
  }

  @override
  String updatedAt(Object date) {
    return 'Updated $date';
  }

  @override
  String get addedToNewSheet => 'Added to new sheet';

  @override
  String addedItemsToNewSheet(Object count) {
    return 'Added $count items to new sheet';
  }

  @override
  String generatedSheet(Object title) {
    return 'Generated \"$title\"';
  }

  @override
  String get aiLocalNotReady => 'Local AI is not initialized.';

  @override
  String get aiPurchaseRequired => 'AI requires purchase';

  @override
  String get aiPurchaseRequiredDesc =>
      'You need to charge AI usage credits to use AI features. Please purchase from the store page.';

  @override
  String get goToStore => 'Store';

  @override
  String get generatingFormula => 'Generating formula...';

  @override
  String generationFailed(Object error) {
    return 'Generation failed: $error';
  }

  @override
  String get mergeSheets => 'Merge Calculation Sheets';

  @override
  String get mergeSheetsDesc => 'Display multiple sheets side by side';

  @override
  String get mergedView => 'Merged View';

  @override
  String mergedSheetLabel(Object count) {
    return '($count) Merged';
  }

  @override
  String get proRequired => 'Pro version required';

  @override
  String get proFeature => 'Pro Feature';

  @override
  String get proFeatureDesc =>
      'Please purchase the Pro version to use this feature.';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String get upgradeToProUnlimited => 'Upgrade to Pro for unlimited sheets.';

  @override
  String get sheetLimitReached => 'Sheet limit reached';

  @override
  String get sheetLimitDesc => 'The free version allows up to 5 sheets.';

  @override
  String get qrShare => 'Share via QR';

  @override
  String get qrShareDesc => 'Select sheets to export with QR code';

  @override
  String get qrImport => 'Import Sheet';

  @override
  String get qrImportDesc => 'Import sheets from QR code';

  @override
  String get noSharableSheets => 'No sheets to share';

  @override
  String get importComplete => 'Import Complete';

  @override
  String importedSheet(Object result) {
    return 'Imported \"$result\"';
  }

  @override
  String get invalidQrCode => 'Invalid sheet QR code';

  @override
  String get importedSheetDefault => 'Imported Sheet';

  @override
  String get linkGraph => 'Link Graph';

  @override
  String get linkGraphDesc => 'Visualize link relationships between sheets';

  @override
  String get select2OrMore => 'Select 2 or more';

  @override
  String selectingCount(Object count) {
    return '$count selected';
  }

  @override
  String get selectSheetsToShare => 'Select sheets to share';

  @override
  String addSheetsCount(Object count) {
    return 'Add $count sheets';
  }

  @override
  String mergeSheetsCount(Object count) {
    return 'Merge $count sheets';
  }

  @override
  String get select1OrMore => 'Select 1 or more';

  @override
  String shareSheetsCount(Object count) {
    return 'Share $count sheets';
  }

  @override
  String get pleaseSelect1OrMore => 'Please select at least 1';

  @override
  String get addSheet => 'Add Sheet';

  @override
  String get noFormulaSet => 'No formula set';

  @override
  String itemCount(Object count) {
    return '$count items';
  }

  @override
  String get calcAddThis => 'Add This Calculation';

  @override
  String get calcEnterThis => 'Enter This Value';

  @override
  String get aiPromptHint => 'Enter AI instructions... (e.g., calculate tax)';

  @override
  String get aiGenerate => 'Generate';

  @override
  String get aiCreateNew => 'Create New';

  @override
  String get aiModify => 'Modify / Add';

  @override
  String get aiCamera => 'Take Photo';

  @override
  String get aiGallery => 'Choose from Gallery';

  @override
  String aiRemainingUses(Object count) {
    return 'Remaining AI uses: $count (Purchase more)';
  }

  @override
  String get proVersion => 'Pro Version';

  @override
  String get proAllFeaturesAvailable => 'All features available';

  @override
  String get proUnlockAll =>
      'Unlock all features permanently (one-time purchase)';

  @override
  String get proPurchased => 'Purchased ✓';

  @override
  String get proBuy => 'Buy →';

  @override
  String get aiCredits => 'AI Credits';

  @override
  String aiCreditsRemaining(Object count) {
    return '$count remaining / Recharge anytime';
  }

  @override
  String get aiCreditsCharge => 'Charge →';

  @override
  String get aiCreditsNote => 'AI credits accumulate. No expiration date.';

  @override
  String get settingsOperation => 'Operation Settings';

  @override
  String get settingsVibrate => 'Button Vibration';

  @override
  String get settingsVibrateDesc =>
      'Vibrate feedback when tapping calculator buttons';

  @override
  String get settingsBilling => 'Billing & Purchase';

  @override
  String get userConstants => 'User-Defined Constants';

  @override
  String get userConstantsAdd => 'Add';

  @override
  String get userConstantsEmpty =>
      'No constants yet\nTap \"Add\" in the top right to add';

  @override
  String get userConstantsDesc =>
      'User-defined constants appear in all sheets\' constant presets';

  @override
  String get builtinConstants => 'Built-in Constants';

  @override
  String get addConstant => 'Add Constant';

  @override
  String get editConstant => 'Edit Constant';

  @override
  String get constantName => 'Name';

  @override
  String get constantNameHint => 'e.g., Tax rate';

  @override
  String get constantValue => 'Value';

  @override
  String get constantValueHint => '0.0';

  @override
  String get storeProTitle => 'Buy Pro Version';

  @override
  String get storeAiTitle => 'AI Usage Charge';

  @override
  String get storePurchaseComplete => 'Purchase completed 🎉';

  @override
  String get storePurchaseFailed =>
      'Purchase was cancelled or an error occurred.';

  @override
  String get storeRestorePurchases => 'Restore Purchases';

  @override
  String get storeRestoredPro => 'Purchases restored (Pro active) ✅';

  @override
  String get storeNoRestore => 'No purchases to restore.';

  @override
  String get proOneTime => 'One-time purchase, no additional fees';

  @override
  String get proPermanentUnlock => 'Unlock all features permanently';

  @override
  String get aiCharge => 'AI Charge';

  @override
  String get aiChargeDesc => 'AI usage is charged based on the plan purchased';

  @override
  String get aiCurrentRemaining => 'Current Remaining';

  @override
  String get aiTimes => 'times';

  @override
  String get proFeatures => 'Pro Features';

  @override
  String get proFeaturesDesc => 'Purchase once, use forever';

  @override
  String get proFeatureAdvancedCalc => 'Unlock Advanced Calculation';

  @override
  String get proFeatureAdvancedCalcDesc =>
      'All advanced calculation features previously limited in the standard version become available, including complex formulas and variable calculations.';

  @override
  String get proFeatureUnlimitedSheets => 'Unlimited Sheets & Tables';

  @override
  String get proFeatureUnlimitedSheetsDesc =>
      'Create unlimited sheets and tables. Suitable for large-scale projects.';

  @override
  String get proFeatureExport => 'Data Export & Sharing';

  @override
  String get proFeatureExportDesc =>
      'Generate QR codes and share calculation sheets on the spot. Export data in CSV and other formats to share with team members and clients.';

  @override
  String get proFeatureLinkGraph => 'Full Link Graph Features';

  @override
  String get proFeatureLinkGraphDesc =>
      'The link graph feature for visually managing dependencies between calculators is fully unlocked.';

  @override
  String get aiFeatures => 'AI Features';

  @override
  String get aiFeaturesDesc => 'Use AI for the number of times charged';

  @override
  String get aiFeatureFormulaAssist => 'AI Formula Assist';

  @override
  String get aiFeatureFormulaAssistDesc =>
      'AI supports creating complex formulas. Simply convey conditions in natural language to get appropriate formula suggestions.';

  @override
  String get aiFeatureCounting => 'AI Counting';

  @override
  String get aiFeatureCountingDesc =>
      'AI counts specified items from images. Import counted values instantly into the calculator.';

  @override
  String get aiFeatureConsumable =>
      'AI usage is consumable. Reflected in remaining count immediately after purchase. No expiration.';

  @override
  String get planSelect => 'Plan Selection';

  @override
  String get chargePlanSelect => 'Select Charge Plan';

  @override
  String get noPlansAvailable => 'No plans currently available for purchase';

  @override
  String get tryAgainLater => 'Please try again later';

  @override
  String get recommended => 'Recommended';

  @override
  String get purchaseNotes => 'Purchase Notes';

  @override
  String get purchaseNotesPro1 =>
      '・The Pro version is a one-time purchase. Once purchased, you can use it permanently with no additional fees.';

  @override
  String get purchaseNotesPro2 =>
      '・Purchases are linked to your Apple ID account. You can use it across multiple devices by signing in with the same Apple ID.';

  @override
  String get purchaseNotesPro3 =>
      '・If you have previously purchased, you can resume use via \"Restore Purchases\" in the top right.';

  @override
  String get purchaseNotesPro4 =>
      '・Payments are processed through the App Store. Please check Apple\'s terms of use for details.';

  @override
  String get purchaseNotesPro5 =>
      '・Please contact support if you have any questions.';

  @override
  String get purchaseNotesAi1 =>
      '・Purchased AI usage is consumable. One use is consumed each time you use AI.';

  @override
  String get purchaseNotesAi2 =>
      '・No expiration date. Purchased uses can be used at any time.';

  @override
  String get purchaseNotesAi3 =>
      '・Purchases are linked to your Apple ID account. You can use it across multiple devices by signing in with the same Apple ID.';

  @override
  String get purchaseNotesAi4 =>
      '・If your credits run low, you can always add more.';

  @override
  String get purchaseNotesAi5 =>
      '・Payments are processed through the App Store. Please check Apple\'s terms of use for details.';

  @override
  String get purchaseNotesAi6 =>
      '・The \"Restore Purchases\" function is for restoring the Pro version. It does not apply to AI usage restoration.';

  @override
  String calcName(Object n) {
    return 'Calc $n';
  }

  @override
  String get calcTerm1 => 'Term 1';

  @override
  String get calcTerm2 => 'Term 2';

  @override
  String calcTermOther(Object n) {
    return 'Term $n';
  }

  @override
  String get calcAnswer => 'Answer';

  @override
  String get calcLink => 'Link';

  @override
  String get constant => 'Constant';

  @override
  String get noCondition => '(no condition)';

  @override
  String get logicOr => 'or';

  @override
  String get logicXor => 'either';

  @override
  String get logicAnd => 'and';

  @override
  String multipleOf(Object a, Object b) {
    return '$a is a multiple of $b';
  }

  @override
  String copiedItem(Object name) {
    return 'Copied \"$name\"';
  }

  @override
  String cutItem(Object name) {
    return 'Cut \"$name\"';
  }

  @override
  String get imageAnalysisFailed => 'Image analysis failed';

  @override
  String get addMemo => 'Add Memo';

  @override
  String get memoTitle => 'Memo';

  @override
  String get formulaWrap => 'Wrap Formula';

  @override
  String get formulaUnwrap => 'Unwrap Formula';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get qrCode => 'QR Code';

  @override
  String get scanQr => 'Scan QR';

  @override
  String get done => 'Done';

  @override
  String get piLabel => 'π (Pi)';

  @override
  String get eLabel => 'e (Natural log base)';

  @override
  String get gLabel => 'g (Gravity)';

  @override
  String get phiLabel => 'φ (Golden ratio)';

  @override
  String get cLabel => 'c (Speed of light m/s)';

  @override
  String get viewMode => 'View Mode';

  @override
  String get editMode => 'Edit Mode';

  @override
  String get tableMode => 'Table Mode';

  @override
  String get toggleNames => 'Toggle Names';

  @override
  String get insertCalcBelow => 'Insert Calc Below';

  @override
  String get insertMemoBelow => 'Insert Memo Below';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get copy => 'Copy';

  @override
  String get cut => 'Cut';

  @override
  String get paste => 'Paste';

  @override
  String get pasteCopiedCalc => 'Add Copied Calculation';

  @override
  String get moveUp => 'Move Up';

  @override
  String get moveDown => 'Move Down';

  @override
  String get expose => 'Expose';

  @override
  String get exposeToSheet => 'Expose to other sheets';

  @override
  String get unexposeFromSheet => 'Remove from other sheets';

  @override
  String get linkSettings => 'Link Settings';

  @override
  String get addTerm => 'Add Term';

  @override
  String get brackets => 'Brackets';

  @override
  String get exposed => 'Exposed';

  @override
  String get notExposed => 'Not Exposed';

  @override
  String get sheetTitle => 'Sheet Title';

  @override
  String get sheetBackground => 'Sheet Background';

  @override
  String get displayOrder => 'Display Order';

  @override
  String get addStandaloneMemo => 'Add Standalone Memo';

  @override
  String get addLogicItem => 'Add Logic Item';

  @override
  String get addSheetConstant => 'Add Sheet Constant';

  @override
  String copyFormula(Object name) {
    return 'Copy formula: $name';
  }

  @override
  String copyAnswer(Object value) {
    return 'Copy answer: $value';
  }

  @override
  String get total => 'Total';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get logicItemEdit => 'Edit Logic';

  @override
  String get logicItemNew => 'New Logic';

  @override
  String get logicName => 'Logic Name';

  @override
  String get logicConditions => 'Conditions';

  @override
  String get logicAddCondition => 'Add Condition';

  @override
  String get logicLhs => 'Left side';

  @override
  String get logicOp => 'Operator';

  @override
  String get logicRhs => 'Right side';

  @override
  String get logicRhs2 => 'Right side 2';

  @override
  String get logicChain => 'Chain';

  @override
  String get logicChainAnd => 'AND';

  @override
  String get logicChainOr => 'OR';

  @override
  String get logicChainXor => 'XOR';

  @override
  String get linkSourceDialog => 'Link Source';

  @override
  String get linkSourceSameSheet => 'Same Sheet';

  @override
  String get linkSourceOtherSheet => 'Other Sheet';

  @override
  String get linkSourceConstant => 'Constant';

  @override
  String get linkSourceLogic => 'Logic Result';

  @override
  String get linkSourceGlobalConstant => 'Global Constant';

  @override
  String get linkTarget => 'Target';

  @override
  String get linkTargetResult => 'Result';

  @override
  String get linkTargetInput => 'Input';

  @override
  String get linkTargetOperand => 'Operand';

  @override
  String get transformDialog => 'Transform';

  @override
  String get transformNone => 'None';

  @override
  String get transformPow => 'Power';

  @override
  String get transformPowExp => 'Exponent';

  @override
  String get transformDiv => 'Divide by';

  @override
  String get transformMul => 'Multiply by';

  @override
  String get transformAdd => 'Add';

  @override
  String get transformSub => 'Subtract';

  @override
  String get precision => 'Precision';

  @override
  String get precisionZero => 'No decimals';

  @override
  String get precision1 => '1 decimal';

  @override
  String get precision2 => '2 decimals';

  @override
  String get precision3 => '3 decimals';

  @override
  String get precision4 => '4 decimals';

  @override
  String get sheetColor => 'Sheet Color';

  @override
  String get colorLight => 'Light';

  @override
  String get colorDark => 'Dark';

  @override
  String get memoPlaceholder => 'Enter memo...';

  @override
  String get addBrackets => 'Add Brackets';

  @override
  String get removeBrackets => 'Remove Brackets';

  @override
  String get bracketStart => 'Start';

  @override
  String get bracketEnd => 'End';

  @override
  String get insertItem => 'Insert Item';

  @override
  String get deleteItem => 'Delete Item';

  @override
  String get history => 'History';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get noHistory => 'No history';

  @override
  String get addToSheet => 'Add to Sheet';

  @override
  String get importQrDialog => 'Import via QR';

  @override
  String get importQrDesc => 'Scan QR codes to import sheets';

  @override
  String get cameraMode => 'Camera';

  @override
  String get imageMode => 'Images';

  @override
  String get scanning => 'Scanning...';

  @override
  String get scanComplete => 'Scan Complete';

  @override
  String collectingParts(Object current, Object total) {
    return 'Collecting parts... ($current/$total)';
  }

  @override
  String get aiCountDialog => 'AI Count';

  @override
  String get aiCountDesc =>
      'Take a photo and AI will count the specified items';

  @override
  String get aiCountPrompt => 'What to count (e.g., people, objects)';

  @override
  String get aiCountStart => 'Start Counting';

  @override
  String get aiCounting => 'Counting...';

  @override
  String get aiCountResult => 'Count Result';

  @override
  String get homeAiGenerateDialog => 'AI Generate Sheet';

  @override
  String get homeAiGenerateDesc =>
      'Describe the calculation and AI will build a sheet for you';

  @override
  String get homeAiGenerateImage => 'Or attach an image for analysis';

  @override
  String get mergedReorderSheets => 'Reorder Sheets';

  @override
  String get mergedAddSheet => 'Add Sheet';

  @override
  String get mergedRemoveSheet => 'Remove Sheet';

  @override
  String clipboardBar(Object name) {
    return 'Clipboard: $name';
  }

  @override
  String get clipboardBarClear => 'Clear';

  @override
  String get aiModelLabel => 'AI Model';

  @override
  String get aiModelLocal => 'Local';

  @override
  String get aiModelCloudGemma => 'Cloud (Gemma)';

  @override
  String get aiModelCloudGemini => 'Cloud (Gemini)';

  @override
  String get proUpgradeBanner => 'Upgrade to Pro for unlimited features';

  @override
  String get decide => 'OK';

  @override
  String get noLinkableSheets => 'No linkable sheets';

  @override
  String get noFormulas => 'No formulas';

  @override
  String get noLinkableConstants => 'No linkable constants';

  @override
  String get sheetConstants => 'Sheet Constants';

  @override
  String get globalConstants => 'Global Constants';

  @override
  String get selectLinkSource => 'Select link source';

  @override
  String get thisSheet => 'This sheet';

  @override
  String get exposedFormulas => 'Exposed formulas';

  @override
  String get mergedSheet => 'Merged sheet';

  @override
  String get editColumnName => 'Edit Column Name';

  @override
  String get columnName => 'Column Name';

  @override
  String get columnSettings => 'Column Settings';

  @override
  String get columnDisplaySettings => 'Column Display Settings';

  @override
  String get trueLabel => 'True';

  @override
  String get falseLabel => 'False';

  @override
  String get opGreaterThan => '> (Greater than)';

  @override
  String get opGreaterEqual => '≥ (Greater or equal)';

  @override
  String get opLessThan => '< (Less than)';

  @override
  String get opLessEqual => '≤ (Less or equal)';

  @override
  String get opEqual => '= (Equal)';

  @override
  String get opNotEqual => '≠ (Not equal)';

  @override
  String get opBetween => 'Within range (a ≤ x ≤ b)';

  @override
  String get opNotBetween => 'Out of range (x < a or x > b)';

  @override
  String get opDivisible => 'Multiple check (x is multiple of n)';

  @override
  String conditionN(Object n) {
    return 'Condition $n';
  }

  @override
  String get leftSide => 'Left side (value)';

  @override
  String get operatorLabel => 'Operator';

  @override
  String get rightSide => 'Right side (value)';

  @override
  String get lowerLimit => 'Lower limit (a)';

  @override
  String get upperLimit => 'Upper limit (b)';

  @override
  String get divisor => 'Divisor (n)';

  @override
  String get editLogic => 'Edit Logic';

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get logicNameHint => 'e.g., Range check';

  @override
  String get addCondition => 'Add Condition';

  @override
  String get valueLabel => 'Value';

  @override
  String get labelOptional => 'Label (optional)';

  @override
  String get backToCamera => 'Back to Camera';

  @override
  String get deleteTerm => 'Delete term';

  @override
  String get showAllNodes => 'Show All Nodes';

  @override
  String get layoutCalculating => 'Calculating layout...';

  @override
  String get noConnections => 'No connections';

  @override
  String get linkSource => 'Link source';

  @override
  String get unknownLogic => 'Unknown logic';

  @override
  String get noSettingLogicYet =>
      'No logic expressions configured. Add one from the button above.';

  @override
  String get selectLogic => 'Select logic';

  @override
  String get addLogic => 'Add Logic';

  @override
  String get constantLink => 'Link from constant';

  @override
  String get optionsLabel => 'Options';

  @override
  String get linkSettingsHint => 'Link settings';

  @override
  String get makeLinkSource => 'Make source';

  @override
  String get makeLinkTarget => 'Make target';

  @override
  String get logicLink => 'Logic link';

  @override
  String get trueValue => 'Value when true';

  @override
  String get falseValue => 'Value when false';

  @override
  String get linking => 'Linking';

  @override
  String get logicLinking => 'Logic linking';

  @override
  String get unlink => 'Unlink';

  @override
  String get restoreLink => 'Restore link';

  @override
  String get transformSection => 'Transform (optional)';

  @override
  String get noTransform => 'None';

  @override
  String get transformSqrt => '√ Square root';

  @override
  String get transformNroot => 'n-th root';

  @override
  String get transformAbs => '|x| Absolute';

  @override
  String get transformFloor => '⌊x⌋ Floor';

  @override
  String get transformCeil => '⌈x⌉ Ceil';

  @override
  String get transformRound => 'Round';

  @override
  String get transformLog10 => 'log10 (Logarithm)';

  @override
  String get transformReciprocal => '1/x Reciprocal';

  @override
  String get transformSin => 'sin';

  @override
  String get transformCos => 'cos';

  @override
  String get transformTan => 'tan';

  @override
  String get powExponentQ => 'Power (n):';

  @override
  String get nrootExponentQ => 'Root (n):';

  @override
  String get unitCategoryCommon => 'Common';

  @override
  String get unitCategoryCurrency => 'Currency / Finance';

  @override
  String get unitCategoryRatio => 'Ratio / Number';

  @override
  String get unitCategoryTime => 'Time';

  @override
  String get unitCategoryWeight => 'Weight';

  @override
  String get unitCategoryLength => 'Length';

  @override
  String get unitCategoryVolume => 'Volume';

  @override
  String get unitCategoryArea => 'Area';

  @override
  String get unitCategoryTemp => 'Temperature / Pressure';

  @override
  String get unitCategorySpeed => 'Speed / Power';

  @override
  String get applyNumberToAll => 'Apply number to all other rows';

  @override
  String get calcHistoryTitle => 'Calculation History';

  @override
  String get calcHistoryEmpty => 'No history yet';

  @override
  String get clearHistoryAll => 'Clear All';

  @override
  String get unitSelectFromCategory => 'Select from category';

  @override
  String get editItemSettings => 'Item Settings';

  @override
  String get calcNameExample => 'e.g., Tax calculation';

  @override
  String get unitSettings => 'Unit settings';

  @override
  String get unitForTerm1 => 'Unit for term 1';

  @override
  String get unitForTerm2 => 'Unit for term 2';

  @override
  String get unitForResult => 'Unit for result';

  @override
  String get linkSettingsWarning => 'There are link settings';

  @override
  String get linkSettingsWarningDesc => 'How would you like to apply?';

  @override
  String get skipLinkedApply => 'Apply except linked values';

  @override
  String get overwriteApply => 'Overwrite and apply';

  @override
  String get selectUnitFromCategory => 'Select unit from category';

  @override
  String get customTextInputHint => 'Enter any text';

  @override
  String get usedUnits => 'Used units';

  @override
  String get editName => 'Calculation name';

  @override
  String get precisionDecimalPlaces => 'Decimal places';

  @override
  String get formulaDetails => 'Formula details';

  @override
  String get resultSettings => 'Result settings';

  @override
  String get appliedToAllExceptLinked => 'Applied to all except linked';

  @override
  String get tooltipMenu => 'Menu';

  @override
  String get tooltipLinkValues => 'Link values';

  @override
  String get toolbarCalculator => 'Calculator';

  @override
  String get toolbarAiGenerate => 'AI Generate';

  @override
  String get modeSelect => 'Select Display Mode';

  @override
  String get editModeDesc => 'Edit formulas';

  @override
  String get viewModeDesc => 'View constants, memos, and calculation results';

  @override
  String get tableModeDesc => 'Display and edit values in sheet format';

  @override
  String get aiGenerateCalc => 'Generate formula with AI';

  @override
  String get noContent => 'No content';

  @override
  String get memoEmptyHint => 'Memo (tap to edit)';

  @override
  String defaultCalcName(Object n) {
    return 'Calc $n';
  }

  @override
  String defaultConstantName(Object n) {
    return 'Constant $n';
  }

  @override
  String get previousResult => 'Previous balance (answer)';

  @override
  String get logicExpression => 'Logic expression';

  @override
  String logicFormat(Object name) {
    return '$name (logic)';
  }

  @override
  String constantFormat(Object name) {
    return '$name (constant)';
  }

  @override
  String get sheetTitleUnknown => 'Untitled sheet';

  @override
  String get labelFormula => 'Formula';

  @override
  String get labelNoFormula => 'No formula set';

  @override
  String get cameraPermissionRequired => 'Camera permission is required.';

  @override
  String get galleryPermissionRequired =>
      'Photo library permission is required.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String imagePickFailed(Object error) {
    return 'Failed to pick image: $error';
  }

  @override
  String get enterCountInstruction => 'Please enter what to count.';

  @override
  String get countReadFailed =>
      'Could not read the number. Try a different instruction.';

  @override
  String errorOccurred(Object error) {
    return 'Error: $error';
  }

  @override
  String get selectObjectToCount => 'Select object to count';

  @override
  String remainingUsesFormat(Object count) {
    return 'Remaining AI uses: $count (Purchase more)';
  }

  @override
  String get aiImageAnalyzing => 'AI is analyzing the image...';

  @override
  String get reflectToCalc => 'Apply to Calculator';

  @override
  String get changePhoto => 'Change Photo';

  @override
  String get countInstruction =>
      'Enter what to count, and AI will analyze the image.';

  @override
  String get countHint => 'What to count? (e.g., people, bolts, boxes)';

  @override
  String get categorySelectLabel => 'Select from category';

  @override
  String get deleteHistoryTitle => 'Delete history';

  @override
  String deleteHistoryConfirm(Object count) {
    return 'Delete the selected $count history entries?';
  }

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String get fullClearTitle => 'Clear All';

  @override
  String get fullClearConfirm => 'Delete all history?';

  @override
  String itemsSelected(Object count) {
    return '$count selected';
  }

  @override
  String get normalCalc => 'Calculation';

  @override
  String sheetCount(Object count) {
    return '$count sheets';
  }

  @override
  String memoCount(Object count) {
    return '$count items';
  }

  @override
  String exposedCount(Object count) {
    return '$count items';
  }

  @override
  String selectAtLeast(Object count) {
    return 'Select at least $count';
  }

  @override
  String selectedCountFormat(Object count) {
    return '$count selected';
  }

  @override
  String get noItemsInSelectionMode => 'Please select at least 1';

  @override
  String get aiFormulaGeneration => 'AI Formula Generation';

  @override
  String get aiCountTitle => 'AI Count';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get reflect => 'Apply';

  @override
  String get changePicture => 'Change Picture';

  @override
  String get countByAi => 'Count with AI';

  @override
  String get selectImageDesc =>
      'Select an image. AI will analyze the image and count the specified objects.';

  @override
  String get cameraLabel => 'Camera';

  @override
  String get galleryLabel => 'Gallery';

  @override
  String get markerToggle => 'Toggle Markers';

  @override
  String get reflectToCalcShort => 'Apply';

  @override
  String get analyzingImage => 'AI is analyzing the image...';

  @override
  String get countTargetInstruction =>
      'Enter what to count, and AI will analyze the image.';

  @override
  String get countHintText => 'What to count? (e.g., people, bolts, boxes)';

  @override
  String remainingUsesText(Object count) {
    return 'Remaining AI uses: $count';
  }

  @override
  String get purchaseMore => 'Purchase More';

  @override
  String get copySuccess => 'Copied';

  @override
  String get csvCopied => 'CSV copied to clipboard';

  @override
  String get noDataToCopy => 'No data to copy';

  @override
  String get noDataToShare => 'No data to share';

  @override
  String get encodeFailed => 'Failed to encode data';

  @override
  String get sheetLinkSettings => 'Sheet Link Settings';

  @override
  String linkSettingOfRow(Object name) {
    return 'Link settings for $name';
  }

  @override
  String get linkFromCalc => 'Link from calc';

  @override
  String get linkToCalc => 'Link to calc';

  @override
  String get linkToResult => 'Link to result';

  @override
  String get linkToInput => 'Link to input';

  @override
  String get linkToOperand => 'Link to operand';

  @override
  String get saveCalc => 'Add Calculation';

  @override
  String get enterValue => 'Enter value';

  @override
  String get editMemoTitle => 'Edit Memo';

  @override
  String get memoEditSave => 'Save';

  @override
  String get insertToMemo => 'Insert to Memo';

  @override
  String get aiPurchaseDescShort => 'AI requires purchase';

  @override
  String get aiPurchaseDescLong =>
      'Please purchase from the store to use AI features.';

  @override
  String get graphHint =>
      'Drag to move · Pinch/Scroll to zoom · Double tap to fit · Tap sheet to expand';

  @override
  String graphShowAllNodes(Object count) {
    return 'All $count Nodes';
  }

  @override
  String graphShowLinkedNodes(Object count) {
    return 'Linked $count Nodes';
  }

  @override
  String get graphCalcCount => 'Calculations';

  @override
  String get graphLogicCount => 'Logic';

  @override
  String get graphEdgeCount => 'Connections';

  @override
  String get graphFitting => 'Fit to Screen';

  @override
  String get graphShowingAll => 'Showing All Nodes';

  @override
  String get graphShowingLinked => 'Showing Linked Only';

  @override
  String get formulaCalc => 'Formula';

  @override
  String get formulaLogic => 'Logic';

  @override
  String get edit => 'Edit';

  @override
  String sheetLabel(Object name) {
    return 'Sheet: $name';
  }

  @override
  String get saveWithStored => 'Calculate with stored';

  @override
  String get saveLabelStored => 'With stored';

  @override
  String get evalTrue => 'True';

  @override
  String get evalFalse => 'False';

  @override
  String get evaluateWithStored => 'Evaluate with stored';

  @override
  String logicConditionsCount(Object count) {
    return 'Conditions ($count)';
  }

  @override
  String otherItemsCount(Object count) {
    return '$count more...';
  }

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String get qrScanFailed => 'Failed to read QR code';

  @override
  String get saveImageToGallery => 'Save as image';

  @override
  String get saving => 'Saving...';

  @override
  String get saveSuccess => 'QR code saved to photos';

  @override
  String saveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get galleryAccessDenied => 'Photo library access denied';

  @override
  String get qRImportFailedTitle => 'Import Failed';

  @override
  String get qrDataMergeFailed =>
      'Failed to merge QR data. Please scan again from the beginning.';

  @override
  String get cutConfirm => 'Cut';

  @override
  String get pasteData => 'Paste data';

  @override
  String copiedName(Object name) {
    return 'Copied \"$name\"';
  }

  @override
  String get searchConstants => 'Search constants';

  @override
  String graphAllNodesCount(Object count) {
    return 'All $count Nodes';
  }

  @override
  String graphLinkedNodesCount(Object count) {
    return 'Linked $count Nodes';
  }

  @override
  String get graphTooltipShowAll => 'Showing All Nodes';

  @override
  String get graphTooltipShowLinked => 'Showing Linked Only';

  @override
  String get graphTooltipFit => 'Fit to Screen';

  @override
  String graphLegendCalc(Object count) {
    return 'Calc: $count';
  }

  @override
  String graphLegendLogic(Object count) {
    return 'Logic: $count';
  }

  @override
  String graphLegendEdges(Object count) {
    return 'Edges: $count';
  }

  @override
  String get graphNodeCalc => 'Calc';

  @override
  String get graphNodeLogic => 'Logic';

  @override
  String get graphEditLink => 'Edit';

  @override
  String graphSheetName(Object name) {
    return 'Sheet: $name';
  }

  @override
  String graphConditionExpressions(Object count) {
    return 'Conditions ($count conditions)';
  }

  @override
  String graphMoreItems(Object count) {
    return '$count more...';
  }

  @override
  String get graphEvaluatesTrue => 'True';

  @override
  String get graphEvaluatesFalse => 'False';

  @override
  String get graphEvaluateStored => 'Evaluate with stored';

  @override
  String get graphSaveValue => 'Calculate with stored';

  @override
  String get graphSaveEvaluate => 'Evaluate with stored';

  @override
  String get graphEmptyTitle => 'No graph data';

  @override
  String get graphEmptyDesc =>
      'Create calculations and set links to generate a graph.';

  @override
  String get confirmDeleteCalc => 'Delete this calculation?';

  @override
  String get confirmDeleteRow => 'Delete this row?';

  @override
  String confirmDeleteSelected(Object count) {
    return 'Delete selected $count items?';
  }

  @override
  String get addCalcRow => 'Add Calculation Row';

  @override
  String get calcRowName => 'Row Name';

  @override
  String get calcRowNameHint => 'e.g., Tax calculation';

  @override
  String get calcRowType => 'Type';

  @override
  String get calcRowValue => 'Value';

  @override
  String get calcRowFormula => 'Formula';

  @override
  String get editCalcRow => 'Edit Calculation Row';

  @override
  String get deleteCalcRow => 'Delete Calculation Row';

  @override
  String get insertCalcRowAbove => 'Insert Above';

  @override
  String get insertCalcRowBelow => 'Insert Below';

  @override
  String get moveCalcRowUp => 'Move Up';

  @override
  String get moveCalcRowDown => 'Move Down';

  @override
  String get duplicateCalcRow => 'Duplicate';

  @override
  String get calcRowSettings => 'Calculation Settings';

  @override
  String get changeOperation => 'Change Operator';

  @override
  String get selectOperation => 'Select Operator';

  @override
  String get addOperation => 'Add Operator';

  @override
  String get removeOperation => 'Remove Operator';

  @override
  String get termSettings => 'Term Settings';

  @override
  String calcTerm(Object n) {
    return 'Term $n';
  }

  @override
  String get calcOperator => 'Operator';

  @override
  String get calcOperand => 'Operand';

  @override
  String get calcOthers => 'Additional Terms';

  @override
  String calcTermsCount(Object count) {
    return '$count terms';
  }

  @override
  String get calcResultPrecision => 'Result Precision';

  @override
  String get showResultOnly => 'Show Result Only';

  @override
  String get showFormulaResult => 'Show Formula & Result';

  @override
  String get selectSheetFirst => 'Select a sheet first';

  @override
  String get selectSourceFirst => 'Select a link source first';

  @override
  String get noSourceForLink => 'No available sources for linking';

  @override
  String get linkExists => 'Link set';

  @override
  String get linkNotExists => 'No link';

  @override
  String get clearAllLinks => 'Clear All Links';

  @override
  String linkCount(Object count) {
    return '$count links';
  }

  @override
  String linkingTo(Object dest) {
    return 'Linked to: $dest';
  }

  @override
  String sourceFrom(Object src) {
    return 'Source: $src';
  }

  @override
  String get linkConfirmReset => 'Reset all link settings?';

  @override
  String get linkConfirmOverwrite => 'Overwrite existing links?';

  @override
  String get linkSettingsSaved => 'Link settings saved';

  @override
  String get linkSettingsCleared => 'Link settings cleared';

  @override
  String get logicEvaluatesTrue => 'Logic evaluates to TRUE';

  @override
  String get logicEvaluatesFalse => 'Logic evaluates to FALSE';

  @override
  String get confirmDeleteLogic => 'Delete this logic expression?';

  @override
  String get confirmDeleteMemo => 'Delete this memo?';

  @override
  String get confirmDeleteConstant => 'Delete this constant?';

  @override
  String get noConstantsYet => 'No constants yet';

  @override
  String get addConstantToSheet => 'Add constant to sheet';

  @override
  String get editSheetConstant => 'Edit Sheet Constant';

  @override
  String get constantGroupLabel => 'Group name';

  @override
  String get constantGroupLabelHint => 'e.g., Materials, Expenses';

  @override
  String get selectConstantGroup => 'Select group';

  @override
  String get filterConstants => 'Filter constants';

  @override
  String get clearFilter => 'Clear filter';

  @override
  String get allConstants => 'All Constants';

  @override
  String get recentConstants => 'Recent Constants';

  @override
  String get favoriteConstants => 'Favorite Constants';

  @override
  String get customConstants => 'Custom Constants';

  @override
  String get systemConstants => 'System Constants';

  @override
  String get addToFavorites => 'Add to Favorites';

  @override
  String get removeFromFavorites => 'Remove from Favorites';

  @override
  String get constantsReordered => 'Constants reordered';

  @override
  String get confirmReorderConstants => 'Reset constant order?';

  @override
  String get constantValueUpdated => 'Constant updated';

  @override
  String get memoSaved => 'Memo saved';

  @override
  String get memoDeleted => 'Memo deleted';

  @override
  String get confirmMemoDelete => 'Delete this memo?';

  @override
  String get noMemos => 'No memos yet';

  @override
  String get emptyMemoHint => 'Tap to add memo';

  @override
  String get columnVisibility => 'Column Display Settings';

  @override
  String get configureColumns => 'Configure Columns';

  @override
  String get restoreDefaultColumns => 'Restore Default Columns';

  @override
  String get confirmResetColumns => 'Reset column settings to default?';

  @override
  String get columnsReset => 'Column settings reset';

  @override
  String get tableViewMode => 'Table View';

  @override
  String get switchToCalcView => 'Switch to Calc View';

  @override
  String get switchToTableView => 'Switch to Table View';

  @override
  String get noDataAvailable => 'No data available';

  @override
  String get dataLoaded => 'Data loaded';

  @override
  String get dataSaveError => 'Error saving data';

  @override
  String get dataLoadError => 'Error loading data';

  @override
  String get operationSuccess => 'Operation completed';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get networkError => 'Network error occurred. Please try again.';

  @override
  String get unknownError => 'Unknown error occurred';

  @override
  String get retry => 'Retry';

  @override
  String get confirmAction => 'Confirm action';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get changesNotSaved => 'Unsaved changes will be lost. Discard?';

  @override
  String get discard => 'Discard';

  @override
  String get keepEditing => 'Keep Editing';

  @override
  String get hideName => 'Hide Name';

  @override
  String get showName => 'Show Name';

  @override
  String get hideAllNames => 'Hide All Calculation Names';

  @override
  String get showAllNames => 'Show All Calculation Names';

  @override
  String get displaySingleLine => 'Display in a single line';

  @override
  String get displayWrapped => 'Display wrapped';

  @override
  String get editWidgetNameColor => 'Edit Widget Name & Color';

  @override
  String get duplicateSheet => 'Duplicate this sheet';

  @override
  String get copyAsCsv => 'Copy as CSV';

  @override
  String get shareWithQrCode => 'Share with QR Code';

  @override
  String get logicItemNewDesc => 'Comparison / AND/OR condition evaluation';

  @override
  String get sheetTitleHint => 'e.g., Financial calculation';

  @override
  String get constantSettings => 'Constant Settings';

  @override
  String get backgroundColor => 'Background Color';

  @override
  String get widgetName => 'Widget Name';

  @override
  String get calculatorTooltip => 'Calculator';

  @override
  String unitForOtherTerm(Object n) {
    return 'Unit for term $n';
  }

  @override
  String get unitLabel => 'Unit';

  @override
  String get numericValue => 'Numeric Value';

  @override
  String valueSettings(Object term) {
    return '$term Settings';
  }

  @override
  String get linkLogic => 'Link Logic';

  @override
  String get linkLogicShort => 'Logic Link';

  @override
  String get transformExprPrefix_none => '';

  @override
  String get transformExprPrefix_sqrt => '√';

  @override
  String transformExprPrefix_pow(Object n) {
    return '($n)^';
  }

  @override
  String transformExprLabel(Object expr, Object result) {
    return '$expr = $result';
  }

  @override
  String get errorResult => 'Error';

  @override
  String get applyToAllWithLinks => 'Apply number to all other rows';

  @override
  String get add => 'Add';

  @override
  String get addRow => 'Add Row';

  @override
  String get navigateToSheetLabel => 'Go to Sheet';

  @override
  String get navigateToSheet => 'Go to Sheet';

  @override
  String get allSheetsDisplayMode => 'All Sheets Display Mode';

  @override
  String get applyToAllSheets => 'Apply to all sheets';

  @override
  String get editModeShort => 'Edit';

  @override
  String get viewModeShort => 'View';

  @override
  String get tableModeShort => 'Table';

  @override
  String get linkGraphDescShort =>
      'Visualize link relationships between sheets';

  @override
  String get addToSheetLabel => 'Add to Sheet';

  @override
  String get selectSheetToAdd => 'Select sheet to add';

  @override
  String selectSheetToAddCount(Object count) {
    return 'Select sheet to add ($count)';
  }

  @override
  String itemCountFormat(Object count) {
    return '$count items';
  }

  @override
  String get mergedViewNameColor => 'Merged View Name & Color';

  @override
  String get viewName => 'View Name';

  @override
  String get viewNameHint => 'e.g., Project calculation';

  @override
  String get backgroundColorLabel => 'Background Color (App bar & background)';

  @override
  String get noSheetsInMerged => 'No sheets';

  @override
  String get aiLabel => 'ai';

  @override
  String get addThisCalc => 'Add This Calculation';

  @override
  String calcNameDefault(Object n) {
    return 'Calc $n';
  }

  @override
  String get historyTitle => 'Calculation History';

  @override
  String get historyDelete => 'Delete';

  @override
  String historyDeleteCount(Object count) {
    return 'Delete ($count)';
  }

  @override
  String get historyAdd => 'Add';

  @override
  String historyAddCount(Object count, Object label) {
    return '$label ($count)';
  }

  @override
  String get historyClearAll => 'Clear All';

  @override
  String get historyCancel => 'Cancel';

  @override
  String get historyNoEntries => 'No history yet';

  @override
  String historyDeleteConfirm(Object count) {
    return 'Delete $count history entries?';
  }

  @override
  String get historyDeleteTitle => 'Delete history';

  @override
  String get historyClearAllTitle => 'Clear All';

  @override
  String get historyClearAllConfirm => 'Delete all history entries?';

  @override
  String historyDateFormat(
    Object day,
    Object hour,
    Object minute,
    Object month,
  ) {
    return '$month/$day $hour:$minute';
  }

  @override
  String historySelectCount(Object count) {
    return '$count selected';
  }

  @override
  String get calcHistoryAddMultiple => 'Add to Sheet';

  @override
  String calcHistoryAddMultipleCount(Object count, Object label) {
    return '$label ($count)';
  }

  @override
  String get calcHistoryDelete => 'Delete';

  @override
  String calcHistoryDeleteCount(Object count) {
    return 'Delete ($count)';
  }

  @override
  String get calcHistoryClearAll => 'Clear All';

  @override
  String get calcHistoryCancel => 'Cancel';

  @override
  String get calcHistoryNoEntries => 'No history yet';

  @override
  String calcHistoryDeleteConfirm(Object count) {
    return 'Delete $count history entries?';
  }

  @override
  String get calcHistoryDeleteTitle => 'Delete history';

  @override
  String get calcHistoryClearAllTitle => 'Clear All';

  @override
  String get calcHistoryClearAllConfirm => 'Delete all history entries?';

  @override
  String get calcHistoryToday => 'Today';

  @override
  String get calcHistoryYesterday => 'Yesterday';

  @override
  String calcHistoryDateFormat(
    Object day,
    Object hour,
    Object minute,
    Object month,
  ) {
    return '$month/$day $hour:$minute';
  }

  @override
  String calcHistorySelectCount(Object count) {
    return '$count selected';
  }

  @override
  String get calcHistoryAdd => 'Add';

  @override
  String calcHistoryAddCount(Object count, Object label) {
    return '$label ($count)';
  }

  @override
  String calcHistoryDeleteCountFormat(Object count) {
    return 'Delete ($count)';
  }

  @override
  String calcHistoryAddCountFormat(Object count, Object label) {
    return '$label ($count)';
  }

  @override
  String calcHistorySelectCountFormat(Object count) {
    return '$count selected';
  }

  @override
  String get calcHistoryNoEntriesText => 'No history yet';

  @override
  String calcHistoryDeleteConfirmText(Object count) {
    return 'Delete $count history entries?';
  }

  @override
  String get calcHistoryDeleteTitleText => 'Delete history';

  @override
  String get calcHistoryClearAllTitleText => 'Clear All';

  @override
  String get calcHistoryClearAllConfirmText => 'Delete all history entries?';

  @override
  String get calcHistoryTodayText => 'Today';

  @override
  String get calcHistoryYesterdayText => 'Yesterday';

  @override
  String calcHistoryDateFormatText(
    Object day,
    Object hour,
    Object minute,
    Object month,
  ) {
    return '$month/$day $hour:$minute';
  }

  @override
  String calcHistorySelectCountText(Object count) {
    return '$count selected';
  }

  @override
  String get calcHistoryAddText => 'Add';

  @override
  String calcHistoryAddCountText(Object count, Object label) {
    return '$label ($count)';
  }

  @override
  String get calcHistoryDeleteText => 'Delete';

  @override
  String calcHistoryDeleteCountText(Object count) {
    return 'Delete ($count)';
  }

  @override
  String get calcHistoryClearAllText => 'Clear All';

  @override
  String get calcHistoryCancelText => 'Cancel';

  @override
  String get listObjectsFromImage => 'List objects from image to count';

  @override
  String linkSourcePrefix(Object label) {
    return 'Link: $label';
  }

  @override
  String previousLinkPrefix(Object label) {
    return 'Previous link: $label';
  }

  @override
  String logicLinkPrefix(Object label) {
    return 'Logic link: $label';
  }

  @override
  String rowOfLabel(Object field, Object name) {
    return '$name of $field';
  }

  @override
  String get nameUntitled => 'Untitled';

  @override
  String get numberLabel => 'Number';

  @override
  String get unitFreeInput => 'Type any text';

  @override
  String get unitSelectSuggestion => 'Select from used units';

  @override
  String get powExpLabel => 'Exponent (n):';

  @override
  String get powRootLabel => 'Root (n):';

  @override
  String get linkActiveLabel => 'Linked';

  @override
  String get logicLinkActiveLabel => 'Logic linked';

  @override
  String get removeTerm => 'Remove term';

  @override
  String get linkSettingsSection => 'Link settings';

  @override
  String get linkSourceBtn => 'Make link source';

  @override
  String get linkTargetBtn => 'Make link target';

  @override
  String get logicAssociation => 'Logic linking';

  @override
  String get noLogicItemSet =>
      'No logic items set. Click the button above to add.';

  @override
  String get selectLogicItem => 'Select logic item';

  @override
  String get linkFromConstant => 'Link from constant';

  @override
  String get transformOption => 'Transform (optional)';

  @override
  String get precisionLabel => 'Decimal places';

  @override
  String get resultUnit => 'Answer unit';

  @override
  String unit1OfLabel(Object name) {
    return 'Unit of $name';
  }

  @override
  String get resultSettingsTitle => 'Result settings';

  @override
  String get linkSourceSelectHint =>
      'Select a link source value, then tap destination values to set links.\nMultiple destinations can be set.';

  @override
  String get selectField => 'Select field';

  @override
  String get nextArrow => 'Next →';

  @override
  String get reselect => 'Reselect';

  @override
  String get linkDest => 'Link destination';

  @override
  String get multipleSelectable => '(Multiple selection allowed)';

  @override
  String get selectLinkSourceFormula => 'Please select a source formula';

  @override
  String get noOtherFormulas => 'No other formulas available';

  @override
  String get setLink => 'Set Link';

  @override
  String get selectUnitFromCategoryTitle => 'Select unit from category';

  @override
  String get transformPowLabel => 'x^n Power';
}
