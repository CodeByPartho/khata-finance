/// One named book: a separate ledger with its own transactions,
/// budgets, wallets, goals and debts. The default book is Personal.
class Book {
  final String id;
  final String name;

  const Book({required this.id, required this.name});

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'name': name};
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Book',
    );
  }
}
