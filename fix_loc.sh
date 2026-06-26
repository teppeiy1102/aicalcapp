#! /bin/sh
cd lib

# Fix const Text('...') with localization keys
sed -i '' "s/const Text('数値',/Text(l10n.valueLabel,/g" calculator_row.dart
sed -i '' "s/const Text('単位',/Text(l10n.unitLabel,/g" calculator_row.dart
sed -i '' "s/const Text('解除',/Text(l10n.unlink,/g" calculator_row.dart
sed -i '' "s/const Text('リンクに戻す',/Text(l10n.restoreLink,/g" calculator_row.dart
sed -i '' "s/const Text('真の場合の値',/Text(l10n.trueValue,/g" calculator_row.dart
sed -i '' "s/const Text('偽の場合の値',/Text(l10n.falseValue,/g" calculator_row.dart
sed -i '' "s/const Text('リンクの設定',/Text(l10n.linkSettingsHint,/g" calculator_row.dart
sed -i '' "s/const Text('リンク元にする',/Text(l10n.makeLinkSource,/g" calculator_row.dart
sed -i '' "s/const Text('リンク先にする',/Text(l10n.makeLinkTarget,/g" calculator_row.dart
sed -i '' "s/const Text('論理式の紐付け',/Text(l10n.logicLink,/g" calculator_row.dart
sed -i '' "s/const Text('論理式を追加',/Text(l10n.addLogic,/g" calculator_row.dart
sed -i '' "s/const Text('論理式を選択',/Text(l10n.selectLogic,/g" calculator_row.dart
sed -i '' "s/const Text('定数からリンク',/Text(l10n.constantLink,/g" calculator_row.dart
sed -i '' "s/const Text('変換（オプション）',/Text(l10n.transformSection,/g" calculator_row.dart
sed -i '' "s/const Text('数値を他の全ての行に適用',/Text(l10n.applyNumberToAll,/g" calculator_row.dart
sed -i '' "s/const Text('計算式の詳細',/Text(l10n.formulaDetails,/g" calculator_row.dart
sed -i '' "s/const Text('答えの設定',/Text(l10n.resultSettings,/g" calculator_row.dart
sed -i '' "s/const Text('小数点以下の桁数',/Text(l10n.precisionDecimalPlaces,/g" calculator_row.dart
sed -i '' "s/const Text('項を削除',/Text(l10n.deleteTerm,/g" calculator_row.dart
sed -i '' "s/tooltip: '電卓',/tooltip: l10n.calculatorTooltip,/g" calculator_row.dart
sed -i '' "s/child: const Text('保存'/child: Text(l10n.save/g" calculator_row.dart