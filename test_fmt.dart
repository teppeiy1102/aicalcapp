import 'dart:core';

class TextEditingSelection {
  final int start;
  final int end;
  TextEditingSelection(this.start, this.end);
}

class TextEditingVal {
  final String text;
  final TextEditingSelection selection;
  TextEditingVal(this.text, this.selection);
  TextEditingVal copyWith({String? text, TextEditingSelection? selection}) {
    return TextEditingVal(text ?? this.text, selection ?? this.selection);
  }
}

TextEditingVal formatEditUpdate(
    TextEditingVal oldValue,
    TextEditingVal newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    if (oldValue.text.length > newValue.text.length && oldValue.selection.start == oldValue.selection.end) {
      if (newValue.selection.start == oldValue.selection.start - 1) { // Backspace
        int deletedOffset = newValue.selection.start;
        if (deletedOffset >= 0 && deletedOffset < oldValue.text.length && oldValue.text[deletedOffset] == ',') {
          if (deletedOffset > 0) {
            String updatedNewText = newValue.text.substring(0, deletedOffset - 1) + newValue.text.substring(deletedOffset);
            newValue = newValue.copyWith(
              text: updatedNewText,
              selection: TextEditingSelection(deletedOffset - 1, deletedOffset - 1),
            );
          }
        }
      } else if (newValue.selection.start == oldValue.selection.start) { // Delete
        int deletedOffset = newValue.selection.start;
        if (deletedOffset >= 0 && deletedOffset < oldValue.text.length && oldValue.text[deletedOffset] == ',') {
          if (deletedOffset < newValue.text.length) {
            String updatedNewText = newValue.text.substring(0, deletedOffset) + newValue.text.substring(deletedOffset + 1);
            newValue = newValue.copyWith(
              text: updatedNewText,
              selection: TextEditingSelection(deletedOffset, deletedOffset),
            );
          }
        }
      }
    }

    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9\.\-]'), '');
    
    if (cleanText.contains('-')) {
      bool isNegative = cleanText.startsWith('-');
      cleanText = cleanText.replaceAll('-', '');
      if (isNegative) cleanText = '-' + cleanText;
    }

    if (cleanText.contains('.')) {
      List<String> parts = cleanText.split('.');
      cleanText = parts[0] + '.' + parts.sublist(1).join('');
    }

    List<String> parts = cleanText.split('.');
    String intPart = parts[0];
    // Don't format the first digit if it's just zero, otherwise `0.5` is fine.
    String decPart = parts.length > 1 ? '.' + parts[1] : '';

    String isNegative = '';
    if (intPart.startsWith('-')) {
      isNegative = '-';
      intPart = intPart.substring(1);
    }

    String formattedInt = '';
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        formattedInt += ',';
      }
      formattedInt += intPart[i];
    }

    String newText = isNegative + formattedInt + decPart;

    int newCursorPos = newValue.selection.end;
    if (newCursorPos >= 0) {
      int cursorWalk = newCursorPos;
      if (cursorWalk > newValue.text.length) cursorWalk = newValue.text.length;
      
      String newStrUntilCursor = newValue.text.substring(0, cursorWalk);
      String cleanUntilCursor = newStrUntilCursor.replaceAll(RegExp(r'[^0-9\.\-]'), '');
      
      int indexInCleanText = cleanUntilCursor.length;
      
      int matchedIndex = 0;
      newCursorPos = 0;
      for (int i = 0; i < newText.length; i++) {
        if (newText[i] != ',') {
          matchedIndex++;
        }
        if (matchedIndex == indexInCleanText) {
          newCursorPos = i + 1;
          break;
        }
      }
      if (indexInCleanText == 0) newCursorPos = 0;
    } else {
      newCursorPos = newText.length;
    }

    return TextEditingVal(
      newText,
      TextEditingSelection(newCursorPos, newCursorPos),
    );
  }

void run(String n, String o, int ns, int os) {
  var old = TextEditingVal(o, TextEditingSelection(os, os));
  var nev = TextEditingVal(n, TextEditingSelection(ns, ns));
  var res = formatEditUpdate(old, nev);
  print('In:  "$n"');
  print('Out: "${res.text}" (cursor: ${res.selection.start})');
}

void main() {
  run('1234', '123', 4, 3);
}
