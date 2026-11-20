import 'package:flutter/material.dart';
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

/// The country code shown inside every mobile number box (not typed, not part of the value).
const String phonePrefix = '+91 ';

/// A stored 10-digit mobile number shown with its country code: "+91 9876543210". Blank stays blank, an existing +91 is not doubled.
String showMobile(String? raw) {
  var d = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) {
    d = d.substring(2);
  } else if (d.length == 11 && d.startsWith('0')) {
    d = d.substring(1);
  }
  return d.isEmpty ? '' : '$phonePrefix$d';
}

/// The "+91" chip at the left edge of every mobile number box: a tinted block, a divider, then the digits.
/// Use as `prefixIcon: const PhonePrefix()` (with `prefixIconConstraints` left as is, it sizes itself).
class PhonePrefix extends StatelessWidget {
  const PhonePrefix({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.06),
          border: Border(right: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Text('+91', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
      ),
    );
  }
}
