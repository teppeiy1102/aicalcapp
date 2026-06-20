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
  String get moveUp => 'Move Up';

  @override
  String get moveDown => 'Move Down';

  @override
  String get expose => 'Expose';

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
}
