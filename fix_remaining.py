#!/usr/bin/env python3
"""Fix remaining callers that need context parameter."""
import re

filepath = 'lib/calculator_row.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

original = content

# Fix _getLinkChipLabel calls - multiline pattern
# _getLinkChipLabel(\nsource,\n2,\n)
# -> _getLinkChipLabel(\nsource,\n2,\ncontext)
content = re.sub(
    r"(_getLinkChipLabel\([^,]+,\s*\n\s*2)\s*,\s*\n(\s*\))",
    r"\1,\n\2, context)",
    content
)

if content != original:
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'Fixed {filepath}')
else:
    print(f'No changes needed for {filepath}')