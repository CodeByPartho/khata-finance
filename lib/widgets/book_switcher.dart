import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../state/finance_provider.dart';

/// Book switcher for the Home app bar: shows the active book and
/// lets the user switch books or create a new one.
class BookSwitcher extends StatelessWidget {
  const BookSwitcher({super.key});

  Future<void> _newBookDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('New book'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Book name',
              hintText: 'For example: Shop',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  Navigator.of(dialogContext).pop(false);
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (saved != true || !context.mounted) {
      return;
    }
    await context.read<FinanceProvider>().addBook(controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final List<Book> books = provider.books;
    final Book active = provider.activeBook;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.book_outlined),
      tooltip: 'Switch book (now: ${active.name})',
      onSelected: (String value) {
        if (value == '__new__') {
          _newBookDialog(context);
        } else {
          context.read<FinanceProvider>().switchBook(value);
        }
      },
      itemBuilder: (BuildContext context) {
        final List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[];
        for (final Book book in books) {
          items.add(
            PopupMenuItem<String>(
              value: book.id,
              child: Row(
                children: <Widget>[
                  Icon(
                    book.id == active.id
                        ? Icons.check
                        : Icons.book_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(book.name),
                ],
              ),
            ),
          );
        }
        items.add(const PopupMenuDivider());
        items.add(
          const PopupMenuItem<String>(
            value: '__new__',
            child: Row(
              children: <Widget>[
                Icon(Icons.add, size: 18),
                SizedBox(width: 8),
                Text('New book'),
              ],
            ),
          ),
        );
        return items;
      },
    );
  }
}
