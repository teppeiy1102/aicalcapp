1. calculator_widget_links.dart からリンク先を選ぶ UI (`_showSheetLinkSettingsDialog`) を独立した Widget (`_LinkPickerSheet` など) として切り出すか、元の関数が `Future<Map<String, dynamic>?>` を返すように変更する。
2. そのピッカーを `calculator_row.dart` の「真の場合の値」「偽の場合の値」でも呼べるようにし、それらの値を `trueLinkSource`, `falseLinkSource` などのフィールドに保存できるようにする。
3. `calculator_row.dart` の UI を更新し、そこでもリンク元を選べるボタン (`onPickLinkSource`) を表示するようにする。
