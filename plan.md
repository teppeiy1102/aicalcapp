# Localization Implementation Plan

## Problem
- `main.dart` doesn't use `AppLocalizations` - all UI strings are hardcoded in Japanese
- `AppLocalizations.of(context)` is only used in `pro_guard.dart`, `link_graph_page.dart`, `store_page.dart`
- `MaterialApp` doesn't have `localizationsDelegates` or `supportedLocales` configured

## Steps
1. ✅ Add import, localizationsDelegates, and supportedLocales to MaterialApp in main.dart
2. 🔲 Replace hardcoded strings with AppLocalizations in main.dart
3. 🔲 Check/update other files (calculator_widget_view.dart, calculator_widget.dart, etc.)