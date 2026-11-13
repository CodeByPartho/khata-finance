/// Bangla and Banglish quick entry parser. Pure Dart, no new
/// dependency. Turns text like "bazar 500", "বাজার ৫০০" or
/// "salary 25000" into an amount, a category and income or expense.
class ParsedQuickEntry {
  final double amount;
  final bool isIncome;
  final String category;
  final String note;

  const ParsedQuickEntry({
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.note,
  });
}

/// Bangla digits ০-৯ mapped to 0-9.
String convertBanglaDigits(String text) {
  const String bangla = '০১২৩৪৫৬৭৮৯';
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    final int index = bangla.indexOf(text[i]);
    if (index >= 0) {
      out.write(index);
    } else {
      out.write(text[i]);
    }
  }
  return out.toString();
}

/// Category keywords. Each entry is a category name, whether it is
/// income, and the words that match it in Bangla or Banglish.
const List<({String category, bool isIncome, List<String> words})>
    _keywordCategories =
    <({String category, bool isIncome, List<String> words})>[
  (
    category: 'Salary',
    isIncome: true,
    words: <String>[
      'salary',
      'beton',
      'বেতন',
      'chakri',
      'pay',
      'income',
    ],
  ),
  (
    category: 'Freelance',
    isIncome: true,
    words: <String>['freelance', 'client', 'project'],
  ),
  (
    category: 'Business',
    isIncome: true,
    words: <String>['business', 'bebsha', 'ব্যবসা', 'sale', 'dokandar'],
  ),
  (
    category: 'Food',
    isIncome: false,
    words: <String>[
      'bazar',
      'বাজার',
      'khabar',
      'খাবার',
      'khawa',
      'food',
      'restaurant',
      'lunch',
      'dinner',
      'breakfast',
      'snack',
      'mudi',
      'grocery',
      'groceries',
    ],
  ),
  (
    category: 'Transport',
    isIncome: false,
    words: <String>[
      'transport',
      'bus',
      'rickshaw',
      'riksha',
      'vara',
      'ভাড়া',
      'bhara',
      'taxi',
      'uber',
      'pathao',
      'fuel',
      'petrol',
      'travel',
    ],
  ),
  (
    category: 'Bills',
    isIncome: false,
    words: <String>[
      'bill',
      'rent',
      'bhara',
      'basa',
      'বাসা',
      'electricity',
      'current',
      'internet',
      'wifi',
      'mobile',
      'recharge',
      'pani',
      'পানি',
      'gas',
    ],
  ),
  (
    category: 'Shopping',
    isIncome: false,
    words: <String>[
      'shopping',
      'jama',
      'জামা',
      'kapor',
      'কাপড়',
      'shoes',
      'dress',
      'market',
    ],
  ),
  (
    category: 'Health',
    isIncome: false,
    words: <String>[
      'health',
      'medicine',
      'oshudh',
      'ঔষধ',
      'doctor',
      'hospital',
      'pharmacy',
      'checkup',
    ],
  ),
  (
    category: 'Education',
    isIncome: false,
    words: <String>[
      'education',
      'school',
      'course',
      'book',
      'boi',
      'বই',
      'shikkha',
      'শিক্ষা',
      'exam',
      'fee',
      'tuition',
    ],
  ),
  (
    category: 'Entertainment',
    isIncome: false,
    words: <String>[
      'movie',
      'cinema',
      'entertainment',
      'game',
      'streaming',
      'ticket',
    ],
  ),
];

/// Parses [text] into a quick entry. The amount is the first number
/// found (Bangla digits are converted first, commas are ignored).
/// The category comes from the first matching keyword; with no
/// keyword the entry falls back to Other expense. The note is the
/// input text with the amount removed. Returns null when no amount
/// is found.
ParsedQuickEntry? parseQuickEntry(String text) {
  final String normalized = convertBanglaDigits(text).trim();
  if (normalized.isEmpty) {
    return null;
  }
  final RegExp amountPattern = RegExp(r'(\d[\d,]*(\.\d+)?)');
  final RegExpMatch? amountMatch = amountPattern.firstMatch(normalized);
  if (amountMatch == null) {
    return null;
  }
  final double? amount =
      double.tryParse(amountMatch.group(0)!.replaceAll(',', ''));
  if (amount == null || amount <= 0) {
    return null;
  }
  final String lower = normalized.toLowerCase();
  String category = 'Other';
  bool isIncome = false;
  for (final ({String category, bool isIncome, List<String> words}) entry
      in _keywordCategories) {
    bool matched = false;
    for (final String word in entry.words) {
      if (lower.contains(word.toLowerCase())) {
        matched = true;
        break;
      }
    }
    if (matched) {
      category = entry.category;
      isIncome = entry.isIncome;
      break;
    }
  }
  String note = normalized
      .replaceFirst(amountMatch.group(0)!, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (note.isEmpty) {
    note = category;
  }
  return ParsedQuickEntry(
    amount: amount,
    isIncome: isIncome,
    category: category,
    note: note,
  );
}
