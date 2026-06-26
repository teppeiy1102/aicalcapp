#!/usr/bin/env python3
"""Fix const keyword errors where AppLocalizations is used."""
import re
import os

files = [
    'lib/main.dart',
    'lib/widget_page.dart',
    'lib/calculator_widget.dart',
    'lib/calculator_widget_table.dart',
    'lib/calculator_widget_source_picker.dart',
    'lib/calculator_widget_view.dart',
    'lib/calculator_row.dart',
    'lib/link_graph_page.dart',
    'lib/memo_ai_widgets.dart',
    'lib/calc_input_widgets.dart',
]

for filepath in files:
    if not os.path.exists(filepath):
        continue
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    
    # Fix: Remove 'const' before Text() that contains AppLocalizations
    content = re.sub(r'const Text\(AppLocalizations\.of\(context\)!', 'Text(AppLocalizations.of(context)!', content)
    
    # Fix: Remove 'const' before SnackBar() that contains AppLocalizations
    content = re.sub(r'const SnackBar\(\s*content:\s*Text\(AppLocalizations', 'SnackBar(\n          content: Text(AppLocalizations', content)
    
    # Fix: Remove 'const' before SnackBar with multiline content containing AppLocalizations
    content = re.sub(r'const SnackBar\(\s*\n\s*content:\s*Text\(AppLocalizations', 'SnackBar(\n          content: Text(AppLocalizations', content)
    
    # Fix: Remove 'const' before Text() with multiline AppLocalizations
    content = re.sub(r'const Text\(\s*\n\s*AppLocalizations', 'Text(\n                    AppLocalizations', content)
    
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Fixed {filepath}')
    else:
        print(f'No changes needed for {filepath}')