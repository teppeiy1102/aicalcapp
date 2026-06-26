#!/usr/bin/env python3
"""Fix callers of _termLabel, _getSourceLabel, _getSourceRowName, _getLogicLabel to pass context."""
import re
import os

filepath = 'lib/calculator_row.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

original = content

# Fix _termLabel calls: _termLabel('xxx') -> _termLabel('xxx', context)
content = re.sub(r"_termLabel\('([^']+)'\)", r"_termLabel('\1', context)", content)

# Fix _getSourceLabel calls: _getSourceLabel(source) -> _getSourceLabel(source, context)
content = re.sub(r"_getSourceLabel\(([^)]+)\)", r"_getSourceLabel(\1, context)", content)

# Fix _getSourceRowName calls: _getSourceRowName(source) -> _getSourceRowName(source, context)
content = re.sub(r"_getSourceRowName\(([^)]+)\)", r"_getSourceRowName(\1, context)", content)

# Fix _getLogicLabel calls: _getLogicLabel(logicId) -> _getLogicLabel(logicId, context)
content = re.sub(r"_getLogicLabel\(([^)]+)\)", r"_getLogicLabel(\1, context)", content)

if content != original:
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'Fixed {filepath}')
else:
    print(f'No changes needed for {filepath}')