// lib/utils/formatters.dart
import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) return newValue;

    var buffer = StringBuffer();
    var cleanText = text.replaceAll(RegExp(r'[^\d]'), '');

    for (int i = 0; i < cleanText.length; i++) {
      buffer.write(cleanText[i]);
      var index = i + 1;
      
      // 010-1234-5678 형식 지원
      if (index == 3 || index == 7) {
        if (index < cleanText.length) buffer.write('-');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
        text: string,
        selection: TextSelection.collapsed(offset: string.length));
  }
}

// 💡 팁: 생년월일 포매터도 여기 미리 만들어두면 좋겠죠?
class BirthDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    var buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var index = i + 1;
      if ((index == 4 || index == 6) && index < text.length) buffer.write('-');
    }

    var string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}