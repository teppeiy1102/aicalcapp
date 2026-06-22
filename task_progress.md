# Localization Todo List

## Phase 1: Add missing keys to ARB files ✅
- [x] Add 200+ new localization keys to app_en.arb (616 total)
- [x] Add matching translations to app_ja.arb (616 total)

## Phase 2: Update generated localization files ✅
- [x] Update lib/l10n/app_localizations.dart (generated - 1110 new lines)
- [x] Update lib/l10n/app_localizations_en.dart (607 new lines)
- [x] Update lib/l10n/app_localizations_ja.dart (602 new lines)

## Phase 3: Update source files to use l10n (partial)
- [x] Add import to lib/widget_page.dart (library file for all part files)
- [x] Update lib/link_graph_page.dart (graph hints, tooltips, labels)
- [ ] lib/calculator_widget_sheets.dart (column labels, operator labels, logic editor)
- [ ] lib/calculator_widget_source_picker.dart (source picker dialog)
- [ ] lib/memo_ai_widgets.dart (AI count page, memo widgets)
- [ ] lib/calculator_widget_calc.dart (inline calculator)
- [ ] lib/calc_input_widgets.dart (input widgets)
- [ ] lib/widget_page.dart (remaining hardcoded strings)
- [ ] lib/main.dart (remaining hardcoded strings)
- [ ] lib/calculator_widget.dart (remaining hardcoded strings)
- [ ] lib/calculator_row.dart (remaining hardcoded strings)

## Phase 4: Verify and test
- [ ] Run flutter analyze to check for errors
- [ ] Verify all strings are properly localized