import 'package:flutter/services.dart';

/// What a person may type into a field. Anything else is dropped as they type or paste, so a letter never appears in a phone
/// number and a number never runs past its length. The backend checks the same rules again.

/// Mobile number: digits only, at most 10.
final List<TextInputFormatter> phoneFormat = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)];

/// Pincode: digits only, at most 6.
final List<TextInputFormatter> pincodeFormat = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)];

/// Whole number, optionally limited in length (an odometer reading, a quantity).
List<TextInputFormatter> digitsFormat([int? max]) => [FilteringTextInputFormatter.digitsOnly, if (max != null) LengthLimitingTextInputFormatter(max)];

/// An amount or a size: digits and one dot, at most [places] decimals.
List<TextInputFormatter> decimalFormat([int places = 2]) => [FilteringTextInputFormatter.allow(RegExp('^\\d*\\.?\\d{0,$places}'))];

/// GST number: capital letters and digits, at most 15.
final List<TextInputFormatter> gstFormat = [_UpperAlnum(15)];

/// PAN: capital letters and digits, at most 10.
final List<TextInputFormatter> panFormat = [_UpperAlnum(10)];

class _UpperAlnum extends TextInputFormatter {
  const _UpperAlnum(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final cleaned = newValue.text.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    final text = cleaned.length > max ? cleaned.substring(0, max) : cleaned;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
