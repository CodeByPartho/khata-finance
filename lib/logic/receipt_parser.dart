/// Receipt text parsing. Pure Dart: extracts a merchant name and a
/// total amount from OCR text. The OCR itself lives in
/// utils/receipt_scan.dart; this file only parses its text output.
class ParsedReceipt {
  final String merchant;
  final double? total;

  const ParsedReceipt({required this.merchant, this.total});
}

double? _parseAmount(String text) {
  final String cleaned = text.replaceAll(',', '').trim();
  return double.tryParse(cleaned);
}

/// Finds the total amount in [text]. Prefers a line that mentions
/// total, grand total, amount due or balance; otherwise falls back
/// to the largest amount found anywhere in the text.
double? extractReceiptTotal(String text) {
  final RegExp amountPattern = RegExp(r'(\d[\d,]*\.\d{2}|\d[\d,]*)');
  final List<String> lines = text.split('\n');
  for (final String line in lines) {
    final String lower = line.toLowerCase();
    if (lower.contains('grand total') ||
        lower.contains('total') ||
        lower.contains('amount due') ||
        lower.contains('balance due') ||
        lower.contains('to pay')) {
      final Iterable<RegExpMatch> matches = amountPattern.allMatches(line);
      double? best;
      for (final RegExpMatch match in matches) {
        final double? value = _parseAmount(match.group(0)!);
        if (value != null && value > 0) {
          best = value;
        }
      }
      if (best != null) {
        return best;
      }
    }
  }
  double? largest;
  for (final RegExpMatch match in amountPattern.allMatches(text)) {
    final double? value = _parseAmount(match.group(0)!);
    if (value != null && value > 0 && (largest == null || value > largest)) {
      largest = value;
    }
  }
  return largest;
}

/// Merchant name: the first line that has letters and is not a
/// receipt header word or a line that is only numbers.
String extractMerchant(String text) {
  final List<String> lines = text.split('\n');
  for (final String raw in lines) {
    final String line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    if (!RegExp(r'[A-Za-z\u0980-\u09FF]').hasMatch(line)) {
      continue;
    }
    final String lower = line.toLowerCase();
    if (lower.contains('receipt') ||
        lower.contains('invoice') ||
        lower.contains('tax')) {
      continue;
    }
    return line;
  }
  return '';
}

ParsedReceipt parseReceiptText(String text) {
  return ParsedReceipt(
    merchant: extractMerchant(text),
    total: extractReceiptTotal(text),
  );
}
