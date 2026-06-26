// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'AI Calc';

  @override
  String get genbaCalc => '現場カリク';

  @override
  String get genbaCalcTagline => '現場を支える、次世代の電卓';

  @override
  String get proLabel => 'Pro';

  @override
  String get menu => 'メニュー';

  @override
  String get settings => '設定';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get save => '保存';

  @override
  String get loading => '読み込み中...';

  @override
  String get ok => 'OK';

  @override
  String get noSheets => 'まだシートがありません';

  @override
  String get noSheetsSubtitle => '計算を自動化する魔法を始めましょう';

  @override
  String get untitledSheet => '無題のシート';

  @override
  String get newSheet => '新規シート';

  @override
  String get standardCalc => '定型計算';

  @override
  String get sampleCalc => 'サンプルの計算';

  @override
  String get newCalc => '新規計算';

  @override
  String get deleteSheet => 'シートの削除';

  @override
  String deleteSheetConfirm(Object title) {
    return '「$title」を削除しますか？この操作は取り消せません。';
  }

  @override
  String get deleteConfirm => '削除する';

  @override
  String duplicatedSheet(Object title) {
    return '「$title」を複製しました';
  }

  @override
  String updatedAt(Object date) {
    return '更新 $date';
  }

  @override
  String get addedToNewSheet => '新規シートに追加しました';

  @override
  String addedItemsToNewSheet(Object count) {
    return '$count件を新規シートに追加しました';
  }

  @override
  String generatedSheet(Object title) {
    return '「$title」を生成しました';
  }

  @override
  String get aiLocalNotReady => 'ローカルAIが初期化されていません。';

  @override
  String get aiPurchaseRequired => 'AI機能は購入が必要です';

  @override
  String get aiPurchaseRequiredDesc =>
      'AI機能を使用するには、AI利用回数のチャージが必要です。ストアページで購入してください。';

  @override
  String get goToStore => 'ストアへ';

  @override
  String get generatingFormula => '計算式を生成中...';

  @override
  String generationFailed(Object error) {
    return '生成失敗: $error';
  }

  @override
  String get mergeSheets => '計算シートを結合する';

  @override
  String get mergeSheetsDesc => '複数のシートを1画面に並べて表示';

  @override
  String get mergedView => '結合ビュー';

  @override
  String mergedSheetLabel(Object count) {
    return '($count) 結合シート';
  }

  @override
  String get proRequired => 'プロ版が必要です';

  @override
  String get proFeature => 'プロ版の機能です';

  @override
  String get proFeatureDesc => 'この機能を利用するには、プロ版を購入してください。';

  @override
  String get upgradeToPro => 'プロ版にアップグレード';

  @override
  String get upgradeToProUnlimited => 'プロ版にアップグレードするとシートを無制限に作成できます。';

  @override
  String get sheetLimitReached => 'シートの上限に達しました';

  @override
  String get sheetLimitDesc => '無料版では最大5枚までシートを作成できます。';

  @override
  String get qrShare => 'QRコードで共有';

  @override
  String get qrShareDesc => 'シートを選択してQRコードで書き出す';

  @override
  String get qrImport => 'シートを取り込む';

  @override
  String get qrImportDesc => 'QRコードからシートをインポート';

  @override
  String get noSharableSheets => '共有できるシートがありません';

  @override
  String get importComplete => '取り込み完了';

  @override
  String importedSheet(Object result) {
    return '「$result」を取り込みました';
  }

  @override
  String get invalidQrCode => '有効なシートQRコードではありません';

  @override
  String get importedSheetDefault => '取り込んだシート';

  @override
  String get linkGraph => 'リンクグラフ';

  @override
  String get linkGraphDesc => 'シート間のリンク関係をグラフで可視化';

  @override
  String get select2OrMore => '2件以上選択';

  @override
  String selectingCount(Object count) {
    return '$count件選択中';
  }

  @override
  String get selectSheetsToShare => '共有するシートを選択してください';

  @override
  String addSheetsCount(Object count) {
    return '$count件のシートを追加';
  }

  @override
  String mergeSheetsCount(Object count) {
    return '$count件のシートを結合';
  }

  @override
  String get select1OrMore => '1件以上選択';

  @override
  String shareSheetsCount(Object count) {
    return '$count件のシートを共有';
  }

  @override
  String get pleaseSelect1OrMore => '1件以上選択してください';

  @override
  String get addSheet => 'シートを追加';

  @override
  String get noFormulaSet => '計算式未設定';

  @override
  String itemCount(Object count) {
    return '$count件';
  }

  @override
  String get calcAddThis => 'この計算を追加';

  @override
  String get calcEnterThis => 'この値を入力';

  @override
  String get aiPromptHint => 'AIへの指示を入力…（例: 消費税の計算）';

  @override
  String get aiGenerate => '生成';

  @override
  String get aiCreateNew => '新規作成';

  @override
  String get aiModify => '修正・追加';

  @override
  String get aiCamera => 'カメラで撮影';

  @override
  String get aiGallery => 'ギャラリーから選択';

  @override
  String aiRemainingUses(Object count) {
    return '残りAI使用回数: $count 回 (追加購入)';
  }

  @override
  String get proVersion => 'プロ版';

  @override
  String get proAllFeaturesAvailable => 'すべての機能が利用可能です';

  @override
  String get proUnlockAll => 'すべての機能を永久にアンロック（買い切り）';

  @override
  String get proPurchased => '購入済み ✓';

  @override
  String get proBuy => '購入する →';

  @override
  String get aiCredits => 'AIクレジット';

  @override
  String aiCreditsRemaining(Object count) {
    return '残り $count 回 ／ 何度でもチャージ可能';
  }

  @override
  String get aiCreditsCharge => 'チャージ →';

  @override
  String get aiCreditsNote => 'AIクレジットは累積されます。有効期限はありません。';

  @override
  String get settingsOperation => '操作設定';

  @override
  String get settingsVibrate => 'ボタン振動';

  @override
  String get settingsVibrateDesc => '電卓ボタンをタップしたときにバイブレーションでフィードバック';

  @override
  String get settingsBilling => '課金・購入';

  @override
  String get userConstants => 'ユーザー定義定数';

  @override
  String get userConstantsAdd => '追加';

  @override
  String get userConstantsEmpty => 'まだ定数がありません\n右上の「追加」から追加できます';

  @override
  String get userConstantsDesc => 'ユーザー定義定数は全シートの定数追加プリセットに表示されます';

  @override
  String get builtinConstants => '組み込み定数';

  @override
  String get addConstant => '定数を追加';

  @override
  String get editConstant => '定数を編集';

  @override
  String get constantName => '名前';

  @override
  String get constantNameHint => '例: 消費税率';

  @override
  String get constantValue => '値';

  @override
  String get constantValueHint => '0.0';

  @override
  String get storeProTitle => 'プロ版を購入';

  @override
  String get storeAiTitle => 'AI利用回数チャージ';

  @override
  String get storePurchaseComplete => '購入が完了しました 🎉';

  @override
  String get storePurchaseFailed => '購入がキャンセルされたか、エラーが発生しました。';

  @override
  String get storeRestorePurchases => '購入を復元';

  @override
  String get storeRestoredPro => '購入を復元しました（プロ版有効）✅';

  @override
  String get storeNoRestore => '復元できる購入情報がありませんでした。';

  @override
  String get proOneTime => '買い切り・追加費用なし';

  @override
  String get proPermanentUnlock => 'すべての機能を永久にアンロック';

  @override
  String get aiCharge => 'AIチャージ';

  @override
  String get aiChargeDesc => '購入したプランの回数分のAI利用がチャージされます';

  @override
  String get aiCurrentRemaining => '現在の残回数';

  @override
  String get aiTimes => '回';

  @override
  String get proFeatures => 'プロ版でできること';

  @override
  String get proFeaturesDesc => '一度購入すれば永久に利用可能';

  @override
  String get proFeatureAdvancedCalc => '高度な計算機能のアンロック';

  @override
  String get proFeatureAdvancedCalcDesc =>
      '複雑な数式や変数計算など、通常版では制限されていた高度な計算機能が全て利用可能になります。';

  @override
  String get proFeatureUnlimitedSheets => '無制限のシートとテーブル作成';

  @override
  String get proFeatureUnlimitedSheetsDesc =>
      '作成できるシートやテーブルの数が無制限になります。大規模なプロジェクトにも対応可能です。';

  @override
  String get proFeatureExport => 'データのエクスポート・共有';

  @override
  String get proFeatureExportDesc =>
      'QRコードを生成し、その場で計算シートの共有が可能です。CSVやその他の形式でデータをエクスポートし、チームメンバーやクライアントと共有できます。';

  @override
  String get proFeatureLinkGraph => 'リンクグラフの完全機能';

  @override
  String get proFeatureLinkGraphDesc =>
      '計算機間のリンク・依存関係をビジュアルで管理できるリンクグラフ機能が完全に解放されます。';

  @override
  String get aiFeatures => 'AI機能でできること';

  @override
  String get aiFeaturesDesc => 'チャージした回数分だけAIを活用';

  @override
  String get aiFeatureFormulaAssist => '計算式のAIアシスト';

  @override
  String get aiFeatureFormulaAssistDesc =>
      '複雑な計算式の作成をAIがサポート。自然言語で条件を伝えるだけで適切な数式を提案します。';

  @override
  String get aiFeatureCounting => 'AIカウント機能';

  @override
  String get aiFeatureCountingDesc =>
      '画像から指定したアイテムをAIがカウントします。カウントした数値は電卓に即座にインポートします。';

  @override
  String get aiFeatureConsumable => 'AI利用回数は消耗型です。購入後すぐに残回数に反映されます。有効期限はありません。';

  @override
  String get planSelect => 'プラン選択';

  @override
  String get chargePlanSelect => 'チャージプランを選択';

  @override
  String get noPlansAvailable => '現在購入できるプランがありません';

  @override
  String get tryAgainLater => '後ほど再度お試しください';

  @override
  String get recommended => 'おすすめ';

  @override
  String get purchaseNotes => '購入に関するご注意';

  @override
  String get purchaseNotesPro1 =>
      '・プロ版は買い切り型です。一度ご購入いただくと、追加費用なしで永久にご利用いただけます。';

  @override
  String get purchaseNotesPro2 =>
      '・購入はApple IDアカウントに紐づいて管理されます。同じApple IDでサインインすることで複数端末でご利用いただけます。';

  @override
  String get purchaseNotesPro3 => '・過去にご購入済みの場合は、画面右上の「購入を復元」からご利用を再開いただけます。';

  @override
  String get purchaseNotesPro4 =>
      '・お支払いはApp Storeを通じて行われます。詳しくはAppleの利用規約をご確認ください。';

  @override
  String get purchaseNotesPro5 => '・ご不明な点はサポートまでお問い合わせください。';

  @override
  String get purchaseNotesAi1 => '・購入したAI利用回数は消耗型です。ご利用のたびに1回ずつ消費されます。';

  @override
  String get purchaseNotesAi2 => '・有効期限はありません。購入した回数はいつでもご利用いただけます。';

  @override
  String get purchaseNotesAi3 =>
      '・購入はApple IDアカウントに紐づいて管理されます。同じApple IDでサインインすることで複数端末でご利用いただけます。';

  @override
  String get purchaseNotesAi4 => '・回数が不足した場合は、いつでも追加チャージが可能です。';

  @override
  String get purchaseNotesAi5 =>
      '・お支払いはApp Storeを通じて行われます。詳しくはAppleの利用規約をご確認ください。';

  @override
  String get purchaseNotesAi6 =>
      '・購入履歴の「購入を復元」機能は、プロ版の復元に使用します。AI利用回数の復元は対象外です。';

  @override
  String calcName(Object n) {
    return '計算 $n';
  }

  @override
  String get calcTerm1 => '項1';

  @override
  String get calcTerm2 => '項2';

  @override
  String calcTermOther(Object n) {
    return '項$n';
  }

  @override
  String get calcAnswer => '答え';

  @override
  String get calcLink => 'リンク';

  @override
  String get constant => '定数';

  @override
  String get noCondition => '(条件なし)';

  @override
  String get logicOr => 'または';

  @override
  String get logicXor => 'どちらか一方';

  @override
  String get logicAnd => 'かつ';

  @override
  String multipleOf(Object a, Object b) {
    return '$a が $b の倍数';
  }

  @override
  String copiedItem(Object name) {
    return '「$name」をコピーしました';
  }

  @override
  String cutItem(Object name) {
    return '「$name」を切り取りました';
  }

  @override
  String get imageAnalysisFailed => '画像の解析に失敗しました';

  @override
  String get addMemo => 'メモを追加';

  @override
  String get memoTitle => 'メモ';

  @override
  String get formulaWrap => '式を折り返す';

  @override
  String get formulaUnwrap => '式を折り返さない';

  @override
  String get exportCsv => 'CSV書き出し';

  @override
  String get qrCode => 'QRコード';

  @override
  String get scanQr => 'QR読取';

  @override
  String get done => '完了';

  @override
  String get piLabel => 'π (円周率)';

  @override
  String get eLabel => 'e (自然対数の底)';

  @override
  String get gLabel => 'g (重力加速度)';

  @override
  String get phiLabel => 'φ (黄金比)';

  @override
  String get cLabel => 'c (光速 m/s)';

  @override
  String get viewMode => '表示モード';

  @override
  String get editMode => '編集モード';

  @override
  String get tableMode => '表モード';

  @override
  String get toggleNames => '名前の表示切替';

  @override
  String get insertCalcBelow => '下に計算を挿入';

  @override
  String get insertMemoBelow => '下にメモを挿入';

  @override
  String get duplicate => '複製';

  @override
  String get copy => 'コピー';

  @override
  String get cut => '切り取り';

  @override
  String get paste => '貼り付け';

  @override
  String get pasteCopiedCalc => 'コピーした計算を追加';

  @override
  String get moveUp => '上に移動';

  @override
  String get moveDown => '下に移動';

  @override
  String get expose => '開放';

  @override
  String get exposeToSheet => '他のシートに開放する';

  @override
  String get unexposeFromSheet => '他シートへの開放を解除';

  @override
  String get linkSettings => '連動設定';

  @override
  String get addTerm => '項を追加';

  @override
  String get brackets => 'カッコ';

  @override
  String get exposed => '開放中';

  @override
  String get notExposed => '未開放';

  @override
  String get sheetTitle => 'シート名';

  @override
  String get sheetBackground => 'シート背景';

  @override
  String get displayOrder => '表示順序';

  @override
  String get addStandaloneMemo => '独立メモを追加';

  @override
  String get addLogicItem => '論理式を追加';

  @override
  String get addSheetConstant => 'シート定数を追加';

  @override
  String copyFormula(Object name) {
    return '$name の計算式';
  }

  @override
  String copyAnswer(Object value) {
    return '$value をコピー';
  }

  @override
  String get total => '合計';

  @override
  String get selectAll => '全て選択';

  @override
  String get deselectAll => '選択解除';

  @override
  String get logicItemEdit => '論理式を編集';

  @override
  String get logicItemNew => '新しい論理式';

  @override
  String get logicName => '論理式名';

  @override
  String get logicConditions => '条件';

  @override
  String get logicAddCondition => '条件を追加';

  @override
  String get logicLhs => '左辺';

  @override
  String get logicOp => '演算子';

  @override
  String get logicRhs => '右辺';

  @override
  String get logicRhs2 => '右辺2';

  @override
  String get logicChain => '連結';

  @override
  String get logicChainAnd => 'AND';

  @override
  String get logicChainOr => 'OR';

  @override
  String get logicChainXor => 'XOR';

  @override
  String get linkSourceDialog => 'リンク元';

  @override
  String get linkSourceSameSheet => '同じシート';

  @override
  String get linkSourceOtherSheet => '別のシート';

  @override
  String get linkSourceConstant => '定数';

  @override
  String get linkSourceLogic => '論理式の結果';

  @override
  String get linkSourceGlobalConstant => '全体の定数';

  @override
  String get linkTarget => '参照先';

  @override
  String get linkTargetResult => '答え';

  @override
  String get linkTargetInput => '項1';

  @override
  String get linkTargetOperand => '項2';

  @override
  String get transformDialog => '変換';

  @override
  String get transformNone => 'なし';

  @override
  String get transformPow => 'べき乗';

  @override
  String get transformPowExp => '指数';

  @override
  String get transformDiv => '除算';

  @override
  String get transformMul => '乗算';

  @override
  String get transformAdd => '加算';

  @override
  String get transformSub => '減算';

  @override
  String get precision => '精度';

  @override
  String get precisionZero => '小数点なし';

  @override
  String get precision1 => '小数点1桁';

  @override
  String get precision2 => '小数点2桁';

  @override
  String get precision3 => '小数点3桁';

  @override
  String get precision4 => '小数点4桁';

  @override
  String get sheetColor => 'シートの色';

  @override
  String get colorLight => 'ライト';

  @override
  String get colorDark => 'ダーク';

  @override
  String get memoPlaceholder => 'メモを入力...';

  @override
  String get addBrackets => 'カッコを追加';

  @override
  String get removeBrackets => 'カッコを削除';

  @override
  String get bracketStart => '始点';

  @override
  String get bracketEnd => '終点';

  @override
  String get insertItem => '項目を挿入';

  @override
  String get deleteItem => '項目を削除';

  @override
  String get history => '履歴';

  @override
  String get clearHistory => '履歴をクリア';

  @override
  String get noHistory => '履歴がありません';

  @override
  String get addToSheet => 'シートに追加';

  @override
  String get importQrDialog => 'QRでインポート';

  @override
  String get importQrDesc => 'QRコードをスキャンしてシートを取り込みます';

  @override
  String get cameraMode => 'カメラ';

  @override
  String get imageMode => '画像';

  @override
  String get scanning => 'スキャン中...';

  @override
  String get scanComplete => 'スキャン完了';

  @override
  String collectingParts(Object current, Object total) {
    return 'パーツ収集中... ($current/$total)';
  }

  @override
  String get aiCountDialog => 'AIカウント';

  @override
  String get aiCountDesc => '写真を撮ってAIが指定されたアイテムをカウントします';

  @override
  String get aiCountPrompt => 'カウントするもの（例: 人、物）';

  @override
  String get aiCountStart => 'カウント開始';

  @override
  String get aiCounting => 'カウント中...';

  @override
  String get aiCountResult => 'カウント結果';

  @override
  String get homeAiGenerateDialog => 'AIでシートを生成';

  @override
  String get homeAiGenerateDesc => '計算内容を説明するとAIがシートを作成します';

  @override
  String get homeAiGenerateImage => 'または画像を添付して解析';

  @override
  String get mergedReorderSheets => 'シートの並び替え';

  @override
  String get mergedAddSheet => 'シートを追加';

  @override
  String get mergedRemoveSheet => 'シートを外す';

  @override
  String clipboardBar(Object name) {
    return 'クリップボード: $name';
  }

  @override
  String get clipboardBarClear => 'クリア';

  @override
  String get aiModelLabel => 'AIモデル';

  @override
  String get aiModelLocal => 'ローカル';

  @override
  String get aiModelCloudGemma => 'クラウド (Gemma)';

  @override
  String get aiModelCloudGemini => 'クラウド (Gemini)';

  @override
  String get proUpgradeBanner => 'プロ版にアップグレードして全機能を解放';

  @override
  String get decide => '決定';

  @override
  String get noLinkableSheets => 'リンク可能なシートがありません';

  @override
  String get noFormulas => '計算式がありません';

  @override
  String get noLinkableConstants => 'リンク可能な定数がありません';

  @override
  String get sheetConstants => 'シート定数';

  @override
  String get globalConstants => 'グローバル定数';

  @override
  String get selectLinkSource => 'リンク元を選択';

  @override
  String get thisSheet => 'このシート';

  @override
  String get exposedFormulas => '開放された式';

  @override
  String get mergedSheet => '結合シート';

  @override
  String get editColumnName => '列名の編集';

  @override
  String get columnName => '列名';

  @override
  String get columnSettings => '列の設定';

  @override
  String get columnDisplaySettings => '列の表示設定';

  @override
  String get trueLabel => '真';

  @override
  String get falseLabel => '偽';

  @override
  String get opGreaterThan => '> (より大きい)';

  @override
  String get opGreaterEqual => '≥ (以上)';

  @override
  String get opLessThan => '< (より小さい)';

  @override
  String get opLessEqual => '≤ (以下)';

  @override
  String get opEqual => '= (等しい)';

  @override
  String get opNotEqual => '≠ (等しくない)';

  @override
  String get opBetween => '範囲内 (a ≤ x ≤ b)';

  @override
  String get opNotBetween => '範囲外 (x < a または x > b)';

  @override
  String get opDivisible => '倍数判定 (x が n の倍数)';

  @override
  String conditionN(Object n) {
    return '条件 $n';
  }

  @override
  String get leftSide => '左辺 (値)';

  @override
  String get operatorLabel => '演算子';

  @override
  String get rightSide => '右辺 (値)';

  @override
  String get lowerLimit => '下限値 (a)';

  @override
  String get upperLimit => '上限値 (b)';

  @override
  String get divisor => '除数 (n)';

  @override
  String get editLogic => '論理式を編集';

  @override
  String get nameOptional => '名前 (省略可)';

  @override
  String get logicNameHint => '例: 正常範囲チェック';

  @override
  String get addCondition => '条件を追加';

  @override
  String get valueLabel => '数値';

  @override
  String get labelOptional => 'ラベル (省略可)';

  @override
  String get backToCamera => 'カメラに戻る';

  @override
  String get deleteTerm => '項を削除';

  @override
  String get showAllNodes => '全ノードを表示';

  @override
  String get layoutCalculating => '配置計算中…';

  @override
  String get noConnections => '接続なし';

  @override
  String get linkSource => 'リンク元';

  @override
  String get unknownLogic => '不明な論理式';

  @override
  String get noSettingLogicYet => '設定済みの論理式はありません。上のボタンから追加してください。';

  @override
  String get selectLogic => '論理式を選択';

  @override
  String get addLogic => '論理式を追加';

  @override
  String get constantLink => '定数からリンク';

  @override
  String get optionsLabel => 'オプション';

  @override
  String get linkSettingsHint => 'リンクの設定';

  @override
  String get makeLinkSource => 'リンク元にする';

  @override
  String get makeLinkTarget => 'リンク先にする';

  @override
  String get logicLink => '論理式リンク';

  @override
  String get trueValue => '真の場合の値';

  @override
  String get falseValue => '偽の場合の値';

  @override
  String get linking => 'リンク中';

  @override
  String get logicLinking => '論理式リンク中';

  @override
  String get unlink => '解除';

  @override
  String get restoreLink => 'リンクに戻す';

  @override
  String get transformSection => '変換（オプション）';

  @override
  String get noTransform => 'なし';

  @override
  String get transformSqrt => '√ 平方根';

  @override
  String get transformNroot => 'n乗根';

  @override
  String get transformAbs => '|x| 絶対値';

  @override
  String get transformFloor => '⌊x⌋ 切捨';

  @override
  String get transformCeil => '⌈x⌉ 切上';

  @override
  String get transformRound => 'round 四捨五入';

  @override
  String get transformLog10 => 'log10 対数';

  @override
  String get transformReciprocal => '1/x 逆数';

  @override
  String get transformSin => 'sin';

  @override
  String get transformCos => 'cos';

  @override
  String get transformTan => 'tan';

  @override
  String get powExponentQ => '何乗するか（n）：';

  @override
  String get nrootExponentQ => '何乗根か（n）：';

  @override
  String get unitCategoryCommon => 'よく使う';

  @override
  String get unitCategoryCurrency => '通貨/金融';

  @override
  String get unitCategoryRatio => '割合/数';

  @override
  String get unitCategoryTime => '時間';

  @override
  String get unitCategoryWeight => '重さ';

  @override
  String get unitCategoryLength => '長さ';

  @override
  String get unitCategoryVolume => '容量';

  @override
  String get unitCategoryArea => '面積';

  @override
  String get unitCategoryTemp => '温度/気圧';

  @override
  String get unitCategorySpeed => '速度/電力';

  @override
  String get applyNumberToAll => '数値を他の全ての行に適用';

  @override
  String get calcHistoryTitle => '計算履歴';

  @override
  String get calcHistoryEmpty => 'まだ履歴がありません';

  @override
  String get clearHistoryAll => '全削除';

  @override
  String get unitSelectFromCategory => 'カテゴリーから選択';

  @override
  String get editItemSettings => '項目設定';

  @override
  String get calcNameExample => '例: 消費税計算';

  @override
  String get unitSettings => '単位の設定';

  @override
  String get unitForTerm1 => '項1の単位';

  @override
  String get unitForTerm2 => '項2の単位';

  @override
  String get unitForResult => '答えの単位';

  @override
  String get linkSettingsWarning => 'リンク設定があります';

  @override
  String get linkSettingsWarningDesc => '他の行にリンク中の設定があります。どのように適用しますか？';

  @override
  String get skipLinkedApply => 'リンクする値以外を適用';

  @override
  String get overwriteApply => '上書きして適用';

  @override
  String get selectUnitFromCategory => 'カテゴリーから選択';

  @override
  String get customTextInputHint => '自由に文字を入力';

  @override
  String get usedUnits => '使用中の単位を選択';

  @override
  String get editName => '計算の名前';

  @override
  String get precisionDecimalPlaces => '小数点以下の桁数';

  @override
  String get formulaDetails => '計算式の詳細';

  @override
  String get resultSettings => '答えの設定';

  @override
  String get appliedToAllExceptLinked => 'リンク以外に適用しました';

  @override
  String get tooltipMenu => 'メニュー';

  @override
  String get tooltipLinkValues => '値をリンク';

  @override
  String get toolbarCalculator => '電卓';

  @override
  String get toolbarAiGenerate => 'AI生成';

  @override
  String get modeSelect => '表示モードを選択';

  @override
  String get editModeDesc => '計算式を編集できます';

  @override
  String get viewModeDesc => '定数・メモ・計算結果を表示します';

  @override
  String get tableModeDesc => '値のみをシート形式で表示・編集できます';

  @override
  String get aiGenerateCalc => 'AIで計算式を生成';

  @override
  String get noContent => '内容がありません';

  @override
  String get memoEmptyHint => 'メモ（タップして編集）';

  @override
  String defaultCalcName(Object n) {
    return '計算 $n';
  }

  @override
  String defaultConstantName(Object n) {
    return '定数$n';
  }

  @override
  String get previousResult => '直前の残高（答え）';

  @override
  String get logicExpression => '論理式';

  @override
  String logicFormat(Object name) {
    return '$name（論理式）';
  }

  @override
  String constantFormat(Object name) {
    return '$name（定数）';
  }

  @override
  String get sheetTitleUnknown => '名称未設定シート';

  @override
  String get labelFormula => '式';

  @override
  String get labelNoFormula => '計算式未設定';

  @override
  String get cameraPermissionRequired => 'カメラのアクセス許可が必要です。';

  @override
  String get galleryPermissionRequired => '写真へのアクセス許可が必要です。';

  @override
  String get openSettings => '設定を開く';

  @override
  String imagePickFailed(Object error) {
    return '画像の取得に失敗しました: $error';
  }

  @override
  String get enterCountInstruction => '何を数えるか入力してください。';

  @override
  String get countReadFailed => '数字を読み取れませんでした。別の指示を試してください。';

  @override
  String errorOccurred(Object error) {
    return 'エラー: $error';
  }

  @override
  String get selectObjectToCount => 'カウントする対象を選択';

  @override
  String remainingUsesFormat(Object count) {
    return '残りAI使用回数: $count 回 (追加購入)';
  }

  @override
  String get aiImageAnalyzing => 'AIが画像を解析中...';

  @override
  String get reflectToCalc => '電卓に反映';

  @override
  String get changePhoto => '写真を変更';

  @override
  String get countInstruction => 'カウント対象を入力して、AIに画像を解析させましょう。';

  @override
  String get countHint => '何を数えますか？（例：人、ボルト、箱）';

  @override
  String get categorySelectLabel => 'カテゴリーから選択';

  @override
  String get deleteHistoryTitle => '履歴を削除';

  @override
  String deleteHistoryConfirm(Object count) {
    return '選択した$count件の履歴を削除しますか？';
  }

  @override
  String get historyToday => '今日';

  @override
  String get historyYesterday => '昨日';

  @override
  String get fullClearTitle => '全削除';

  @override
  String get fullClearConfirm => 'すべての履歴を削除しますか？';

  @override
  String itemsSelected(Object count) {
    return '$count件選択';
  }

  @override
  String get normalCalc => '計算';

  @override
  String sheetCount(Object count) {
    return '$count枚';
  }

  @override
  String memoCount(Object count) {
    return '$count件';
  }

  @override
  String exposedCount(Object count) {
    return '$count件';
  }

  @override
  String selectAtLeast(Object count) {
    return '$count件以上選択';
  }

  @override
  String selectedCountFormat(Object count) {
    return '$count件選択中';
  }

  @override
  String get noItemsInSelectionMode => '1件以上選択してください';

  @override
  String get aiFormulaGeneration => 'AI計算式生成';

  @override
  String get aiCountTitle => 'AIカウント';

  @override
  String get takePhoto => '写真を撮る';

  @override
  String get chooseFromGallery => 'ギャラリーから選択';

  @override
  String get analyzing => '解析中...';

  @override
  String get reflect => '反映';

  @override
  String get changePicture => '写真を変更';

  @override
  String get countByAi => 'AIでカウント';

  @override
  String get selectImageDesc => '画像を選択してください。AIが画像を解析して、指定した対象の数をカウントします。';

  @override
  String get cameraLabel => 'カメラ';

  @override
  String get galleryLabel => 'ギャラリー';

  @override
  String get markerToggle => 'マーカーの表示/非表示';

  @override
  String get reflectToCalcShort => '電卓に反映';

  @override
  String get analyzingImage => 'AIが画像を解析中...';

  @override
  String get countTargetInstruction => 'カウント対象を入力して、AIに画像を解析させましょう。';

  @override
  String get countHintText => '何を数えますか？（例：人、ボルト、箱）';

  @override
  String remainingUsesText(Object count) {
    return '残りAI使用回数: $count';
  }

  @override
  String get purchaseMore => '追加購入';

  @override
  String get copySuccess => 'コピーしました';

  @override
  String get csvCopied => 'CSVをクリップボードにコピーしました';

  @override
  String get noDataToCopy => 'コピーするデータがありません';

  @override
  String get noDataToShare => '共有するデータがありません';

  @override
  String get encodeFailed => 'データのエンコードに失敗しました';

  @override
  String get sheetLinkSettings => 'シート連動設定';

  @override
  String linkSettingOfRow(Object name) {
    return '$name のリンク設定';
  }

  @override
  String get linkFromCalc => '計算からリンク';

  @override
  String get linkToCalc => '計算へリンク';

  @override
  String get linkToResult => '答えへリンク';

  @override
  String get linkToInput => '項1へリンク';

  @override
  String get linkToOperand => '項2へリンク';

  @override
  String get saveCalc => '計算を追加';

  @override
  String get enterValue => '値を入力';

  @override
  String get editMemoTitle => 'メモを編集';

  @override
  String get memoEditSave => '保存';

  @override
  String get insertToMemo => 'メモに挿入';

  @override
  String get aiPurchaseDescShort => 'AI機能は購入が必要です';

  @override
  String get aiPurchaseDescLong => 'ストアで購入してAI機能をご利用ください。';

  @override
  String get graphHint =>
      'ドラッグ移動  ·  ピンチ/スクロールズーム  ·  ダブルタップで全体表示  ·  シートタップで拡大';

  @override
  String graphShowAllNodes(Object count) {
    return '全 $count ノード';
  }

  @override
  String graphShowLinkedNodes(Object count) {
    return 'リンク済み $count ノード';
  }

  @override
  String get graphCalcCount => '計算';

  @override
  String get graphLogicCount => '論理式';

  @override
  String get graphEdgeCount => '接続';

  @override
  String get graphFitting => '画面にフィット';

  @override
  String get graphShowingAll => '全ノード表示中';

  @override
  String get graphShowingLinked => 'リンク済みのみ表示中';

  @override
  String get formulaCalc => '計算式';

  @override
  String get formulaLogic => '論理式';

  @override
  String get edit => '編集';

  @override
  String sheetLabel(Object name) {
    return 'シート: $name';
  }

  @override
  String get saveWithStored => '保存値で計算';

  @override
  String get saveLabelStored => '保存値で';

  @override
  String get evalTrue => '真';

  @override
  String get evalFalse => '偽';

  @override
  String get evaluateWithStored => '保存値で評価';

  @override
  String logicConditionsCount(Object count) {
    return '条件式 ($count)';
  }

  @override
  String otherItemsCount(Object count) {
    return '他 $count 件…';
  }

  @override
  String get scanQrCode => 'QRコードをスキャン';

  @override
  String get qrScanFailed => 'QRコードの読み取りに失敗しました';

  @override
  String get saveImageToGallery => '画像として保存';

  @override
  String get saving => '保存中...';

  @override
  String get saveSuccess => 'QRコードを写真に保存しました';

  @override
  String saveFailed(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get galleryAccessDenied => '写真ライブラリへのアクセスが拒否されました';

  @override
  String get qRImportFailedTitle => 'インポート失敗';

  @override
  String get qrDataMergeFailed => 'QRデータの結合に失敗しました。最初からスキャンし直してください';

  @override
  String get cutConfirm => '切り取り';

  @override
  String get pasteData => 'データを貼り付け';

  @override
  String copiedName(Object name) {
    return '「$name」をコピー';
  }

  @override
  String get searchConstants => '定数を検索';

  @override
  String graphAllNodesCount(Object count) {
    return '全 $count ノード';
  }

  @override
  String graphLinkedNodesCount(Object count) {
    return 'リンク済み $count ノード';
  }

  @override
  String get graphTooltipShowAll => '全ノード表示中';

  @override
  String get graphTooltipShowLinked => 'リンク済みのみ表示中';

  @override
  String get graphTooltipFit => '画面にフィット';

  @override
  String graphLegendCalc(Object count) {
    return '計算: $count';
  }

  @override
  String graphLegendLogic(Object count) {
    return '論理式: $count';
  }

  @override
  String graphLegendEdges(Object count) {
    return '接続: $count';
  }

  @override
  String get graphNodeCalc => '計算';

  @override
  String get graphNodeLogic => '論理式';

  @override
  String get graphEditLink => '編集';

  @override
  String graphSheetName(Object name) {
    return 'シート: $name';
  }

  @override
  String graphConditionExpressions(Object count) {
    return '条件式 ($count 条件)';
  }

  @override
  String graphMoreItems(Object count) {
    return '他 $count 件…';
  }

  @override
  String get graphEvaluatesTrue => '真';

  @override
  String get graphEvaluatesFalse => '偽';

  @override
  String get graphEvaluateStored => '保存値で評価';

  @override
  String get graphSaveValue => '保存値で計算';

  @override
  String get graphSaveEvaluate => '保存値で評価';

  @override
  String get graphEmptyTitle => 'グラフデータがありません';

  @override
  String get graphEmptyDesc => '計算を作成してリンクを設定すると、グラフが生成されます。';

  @override
  String get confirmDeleteCalc => 'この計算を削除しますか？';

  @override
  String get confirmDeleteRow => 'この行を削除しますか？';

  @override
  String confirmDeleteSelected(Object count) {
    return '選択した$count件を削除しますか？';
  }

  @override
  String get addCalcRow => '計算行を追加';

  @override
  String get calcRowName => '行の名前';

  @override
  String get calcRowNameHint => '例: 消費税計算';

  @override
  String get calcRowType => '種別';

  @override
  String get calcRowValue => '値';

  @override
  String get calcRowFormula => '計算式';

  @override
  String get editCalcRow => '計算行を編集';

  @override
  String get deleteCalcRow => '計算行を削除';

  @override
  String get insertCalcRowAbove => '上に挿入';

  @override
  String get insertCalcRowBelow => '下に挿入';

  @override
  String get moveCalcRowUp => '上に移動';

  @override
  String get moveCalcRowDown => '下に移動';

  @override
  String get duplicateCalcRow => '複製';

  @override
  String get calcRowSettings => '計算の設定';

  @override
  String get changeOperation => '演算子を変更';

  @override
  String get selectOperation => '演算子を選択';

  @override
  String get addOperation => '演算子を追加';

  @override
  String get removeOperation => '演算子を削除';

  @override
  String get termSettings => '項の設定';

  @override
  String calcTerm(Object n) {
    return '項 $n';
  }

  @override
  String get calcOperator => '演算子';

  @override
  String get calcOperand => '被演算子';

  @override
  String get calcOthers => '追加項';

  @override
  String calcTermsCount(Object count) {
    return '$count項';
  }

  @override
  String get calcResultPrecision => '答えの精度';

  @override
  String get showResultOnly => '答えのみ表示';

  @override
  String get showFormulaResult => '式と結果を表示';

  @override
  String get selectSheetFirst => '先にシートを選択してください';

  @override
  String get selectSourceFirst => 'リンク元を選択してください';

  @override
  String get noSourceForLink => 'リンクに利用可能なソースがありません';

  @override
  String get linkExists => 'リンク設定あり';

  @override
  String get linkNotExists => 'リンクなし';

  @override
  String get clearAllLinks => '全リンク解除';

  @override
  String linkCount(Object count) {
    return '$countリンク';
  }

  @override
  String linkingTo(Object dest) {
    return 'リンク先: $dest';
  }

  @override
  String sourceFrom(Object src) {
    return 'ソース: $src';
  }

  @override
  String get linkConfirmReset => 'すべてのリンク設定をリセットしますか？';

  @override
  String get linkConfirmOverwrite => '既存のリンクを上書きしますか？';

  @override
  String get linkSettingsSaved => 'リンク設定を保存しました';

  @override
  String get linkSettingsCleared => 'リンク設定を解除しました';

  @override
  String get logicEvaluatesTrue => '論理式の結果は TRUE です';

  @override
  String get logicEvaluatesFalse => '論理式の結果は FALSE です';

  @override
  String get confirmDeleteLogic => 'この論理式を削除しますか？';

  @override
  String get confirmDeleteMemo => 'このメモを削除しますか？';

  @override
  String get confirmDeleteConstant => 'この定数を削除しますか？';

  @override
  String get noConstantsYet => 'まだ定数がありません';

  @override
  String get addConstantToSheet => 'シートに定数を追加';

  @override
  String get editSheetConstant => 'シート定数を編集';

  @override
  String get constantGroupLabel => 'グループ名';

  @override
  String get constantGroupLabelHint => '例: 材料費、経費';

  @override
  String get selectConstantGroup => 'グループを選択';

  @override
  String get filterConstants => '定数を絞り込み';

  @override
  String get clearFilter => '絞り込み解除';

  @override
  String get allConstants => 'すべての定数';

  @override
  String get recentConstants => '最近使った定数';

  @override
  String get favoriteConstants => 'お気に入り定数';

  @override
  String get customConstants => 'カスタム定数';

  @override
  String get systemConstants => 'システム定数';

  @override
  String get addToFavorites => 'お気に入りに追加';

  @override
  String get removeFromFavorites => 'お気に入りから削除';

  @override
  String get constantsReordered => '定数を並び替えました';

  @override
  String get confirmReorderConstants => '定数の順序をリセットしますか？';

  @override
  String get constantValueUpdated => '定数を更新しました';

  @override
  String get memoSaved => 'メモを保存しました';

  @override
  String get memoDeleted => 'メモを削除しました';

  @override
  String get confirmMemoDelete => 'このメモを削除しますか？';

  @override
  String get noMemos => 'まだメモがありません';

  @override
  String get emptyMemoHint => 'タップしてメモを追加';

  @override
  String get columnVisibility => '列の表示設定';

  @override
  String get configureColumns => '列を設定';

  @override
  String get restoreDefaultColumns => 'デフォルトの列に戻す';

  @override
  String get confirmResetColumns => '列設定をデフォルトに戻しますか？';

  @override
  String get columnsReset => '列設定をリセットしました';

  @override
  String get tableViewMode => '表表示';

  @override
  String get switchToCalcView => '計算ビューに切り替え';

  @override
  String get switchToTableView => '表ビューに切り替え';

  @override
  String get noDataAvailable => 'データがありません';

  @override
  String get dataLoaded => 'データを読み込みました';

  @override
  String get dataSaveError => 'データの保存中にエラーが発生しました';

  @override
  String get dataLoadError => 'データの読み込み中にエラーが発生しました';

  @override
  String get operationSuccess => '操作が完了しました';

  @override
  String get operationFailed => '操作に失敗しました';

  @override
  String get networkError => 'ネットワークエラーが発生しました。もう一度お試しください。';

  @override
  String get unknownError => '不明なエラーが発生しました';

  @override
  String get retry => '再試行';

  @override
  String get confirmAction => '操作の確認';

  @override
  String get undo => '元に戻す';

  @override
  String get redo => 'やり直す';

  @override
  String get changesNotSaved => '保存されていない変更は失われます。破棄しますか？';

  @override
  String get discard => '破棄';

  @override
  String get keepEditing => '編集を続ける';

  @override
  String get hideName => '名称を隠す';

  @override
  String get showName => '名称を出す';

  @override
  String get hideAllNames => 'すべての計算名を非表示';

  @override
  String get showAllNames => 'すべての計算名を表示';

  @override
  String get displaySingleLine => '一行で表示する';

  @override
  String get displayWrapped => '折り返して表示する';

  @override
  String get editWidgetNameColor => 'ウィジェット名・カラーを編集';

  @override
  String get duplicateSheet => 'このシートを複製する';

  @override
  String get copyAsCsv => 'CSV形式でコピーする';

  @override
  String get shareWithQrCode => 'QRコードで共有する';

  @override
  String get logicItemNewDesc => '比較・AND/OR条件の真偽判定';

  @override
  String get sheetTitleHint => '例: 財務計算';

  @override
  String get constantSettings => '定数の設定';

  @override
  String get backgroundColor => '背景カラー';

  @override
  String get widgetName => 'ウィジェット名';

  @override
  String get calculatorTooltip => '電卓';

  @override
  String unitForOtherTerm(Object n) {
    return '項$nの単位';
  }

  @override
  String get unitLabel => '単位';

  @override
  String get numericValue => '数値';

  @override
  String valueSettings(Object term) {
    return '$termの設定';
  }

  @override
  String get linkLogic => '論理式の紐付け';

  @override
  String get linkLogicShort => '論理式リンク';

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
  String get errorResult => 'エラー';

  @override
  String get applyToAllWithLinks => '数値を他の全ての行に適用';

  @override
  String get add => 'Add';

  @override
  String get addRow => '行追加';

  @override
  String get navigateToSheetLabel => 'シートへ移動';

  @override
  String get navigateToSheet => 'シートへ移動';

  @override
  String get allSheetsDisplayMode => '全シート表示モード';

  @override
  String get applyToAllSheets => '全シートに適用';

  @override
  String get editModeShort => '編集';

  @override
  String get viewModeShort => '表示';

  @override
  String get tableModeShort => '表';

  @override
  String get linkGraphDescShort => 'シート間のリンク関係をグラフで可視化';

  @override
  String get addToSheetLabel => 'シートに追加';

  @override
  String get selectSheetToAdd => '追加するシートを選択';

  @override
  String selectSheetToAddCount(Object count) {
    return '追加するシートを選択 ($count)';
  }

  @override
  String itemCountFormat(Object count) {
    return '$count件';
  }

  @override
  String get mergedViewNameColor => '結合ビューの名前・カラー';

  @override
  String get viewName => 'ビュー名';

  @override
  String get viewNameHint => '例: プロジェクト計算';

  @override
  String get backgroundColorLabel => '背景カラー（アプリバー・背景）';

  @override
  String get noSheetsInMerged => 'シートがありません';

  @override
  String get aiLabel => 'ai';

  @override
  String get addThisCalc => 'この計算を追加';

  @override
  String calcNameDefault(Object n) {
    return '計算 $n';
  }

  @override
  String get historyTitle => '計算履歴';

  @override
  String get historyDelete => '削除';

  @override
  String historyDeleteCount(Object count) {
    return '削除 ($count)';
  }

  @override
  String get historyAdd => '追加';

  @override
  String historyAddCount(Object count, Object label) {
    return '$label ($count)';
  }

  @override
  String get historyClearAll => '全削除';

  @override
  String get historyCancel => 'キャンセル';

  @override
  String get historyNoEntries => 'まだ履歴がありません';

  @override
  String historyDeleteConfirm(Object count) {
    return '$count件の履歴を削除しますか？';
  }

  @override
  String get historyDeleteTitle => '履歴を削除';

  @override
  String get historyClearAllTitle => '全削除';

  @override
  String get historyClearAllConfirm => 'すべての履歴を削除しますか？';

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
    return '$count件選択';
  }

  @override
  String get calcHistoryAddMultiple => 'シートに追加';

  @override
  String calcHistoryAddMultipleCount(Object count, Object label) {
    return '$label ($count)';
  }

  @override
  String get calcHistoryDelete => '削除';

  @override
  String calcHistoryDeleteCount(Object count) {
    return '削除 ($count)';
  }

  @override
  String get calcHistoryClearAll => '全削除';

  @override
  String get calcHistoryCancel => 'キャンセル';

  @override
  String get calcHistoryNoEntries => 'まだ履歴がありません';

  @override
  String calcHistoryDeleteConfirm(Object count) {
    return '$count件の履歴を削除しますか？';
  }

  @override
  String get calcHistoryDeleteTitle => '履歴を削除';

  @override
  String get calcHistoryClearAllTitle => '全削除';

  @override
  String get calcHistoryClearAllConfirm => 'すべての履歴を削除しますか？';

  @override
  String get calcHistoryToday => '今日';

  @override
  String get calcHistoryYesterday => '昨日';

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
    return '$count件選択';
  }

  @override
  String get calcHistoryAdd => '追加';

  @override
  String calcHistoryAddCount(Object count, Object label) {
    return '$label ($count)';
  }

  @override
  String calcHistoryDeleteCountFormat(Object count) {
    return '削除 ($count)';
  }

  @override
  String calcHistoryAddCountFormat(Object count, Object label) {
    return '$label ($count)';
  }

  @override
  String calcHistorySelectCountFormat(Object count) {
    return '$count件選択';
  }

  @override
  String get calcHistoryNoEntriesText => 'まだ履歴がありません';

  @override
  String calcHistoryDeleteConfirmText(Object count) {
    return '$count件の履歴を削除しますか？';
  }

  @override
  String get calcHistoryDeleteTitleText => '履歴を削除';

  @override
  String get calcHistoryClearAllTitleText => '全削除';

  @override
  String get calcHistoryClearAllConfirmText => 'すべての履歴を削除しますか？';

  @override
  String get calcHistoryTodayText => '今日';

  @override
  String get calcHistoryYesterdayText => '昨日';

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
    return '$count件選択';
  }

  @override
  String get calcHistoryAddText => '追加';

  @override
  String calcHistoryAddCountText(Object count, Object label) {
    return '$label ($count)';
  }

  @override
  String get calcHistoryDeleteText => '削除';

  @override
  String calcHistoryDeleteCountText(Object count) {
    return '削除 ($count)';
  }

  @override
  String get calcHistoryClearAllText => '全削除';

  @override
  String get calcHistoryCancelText => 'キャンセル';

  @override
  String get listObjectsFromImage => '画像からカウントするものをリストアップ';

  @override
  String linkSourcePrefix(Object label) {
    return 'リンク元: $label';
  }

  @override
  String previousLinkPrefix(Object label) {
    return '元リンク: $label';
  }

  @override
  String logicLinkPrefix(Object label) {
    return '論理式リンク: $label';
  }

  @override
  String rowOfLabel(Object field, Object name) {
    return '$name の $field';
  }

  @override
  String get nameUntitled => '名称未設定';

  @override
  String get numberLabel => '数値';

  @override
  String get unitFreeInput => '自由に文字を入力';

  @override
  String get unitSelectSuggestion => '使用中の単位を選択';

  @override
  String get powExpLabel => '何乗するか（n）：';

  @override
  String get powRootLabel => '何乗根か（n）：';

  @override
  String get linkActiveLabel => 'リンク中';

  @override
  String get logicLinkActiveLabel => '論理式リンク中';

  @override
  String get removeTerm => '項を削除';

  @override
  String get linkSettingsSection => 'リンクの設定';

  @override
  String get linkSourceBtn => 'リンク元にする';

  @override
  String get linkTargetBtn => 'リンク先にする';

  @override
  String get logicAssociation => '論理式の紐付け';

  @override
  String get noLogicItemSet => '設定済みの論理式はありません。上のボタンから追加してください。';

  @override
  String get selectLogicItem => '論理式を選択';

  @override
  String get linkFromConstant => '定数からリンク';

  @override
  String get transformOption => '変換（オプション）';

  @override
  String get precisionLabel => '小数点以下の桁数';

  @override
  String get resultUnit => '答えの単位';

  @override
  String unit1OfLabel(Object name) {
    return '$nameの単位';
  }

  @override
  String get resultSettingsTitle => '答えの設定';

  @override
  String get linkSourceSelectHint =>
      'リンク元の値を選択後、リンク先の値をタップして設定してください。\n複数のリンク先を設定することもできます。';

  @override
  String get selectField => '項目を選択';

  @override
  String get nextArrow => '次へ →';

  @override
  String get reselect => '再選択';

  @override
  String get linkDest => 'リンク先';

  @override
  String get multipleSelectable => '（複数選択可）';

  @override
  String get selectLinkSourceFormula => 'リンク元の計算式を選択してください';

  @override
  String get noOtherFormulas => '他の計算式がありません';

  @override
  String get setLink => 'リンクを設定';

  @override
  String get selectUnitFromCategoryTitle => '単位をカテゴリーから選択';

  @override
  String get transformPowLabel => 'x^n 指数';
}
