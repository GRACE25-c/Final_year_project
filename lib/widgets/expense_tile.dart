import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class ExpenseTile extends StatelessWidget {
  final Expense e;

  const ExpenseTile({super.key, required this.e});

  // Helper to show the confirmation dialog
  Future<bool> _showDeleteDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Delete Transaction?"),
            content: const Text("This action cannot be undone."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Delete",
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // Determine type based on amount (Positive = Income, Negative = Expense)
    final bool isIncome = e.amount > 0;
    final double displayAmount = e.amount.abs();

    return Dismissible(
      key: Key(e.id + e.date.toString()),
      direction: DismissDirection.endToStart,
      // Logic for swiping to delete
      confirmDismiss: (direction) => _showDeleteDialog(context),
      onDismissed: (direction) {
        FirestoreService().deleteExpense(e.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Deleted ${e.merchant}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isIncome
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome ? Icons.account_balance_wallet : Icons.shopping_cart,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
          title: Text(
            e.merchant,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          // ... inside your ListTile in ExpenseTile.dart

          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Show Date and Category in a row
              Row(
                children: [
                  Text(
                    DateFormat('MMM dd').format(e.date),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.category,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),

              // 2. Show Description if it exists
              if (e.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    e.description,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),

// ... rest of the ListTile
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${isIncome ? '+' : '-'}\$${displayAmount.toStringAsFixed(2)}",
                style: TextStyle(
                  color: isIncome ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () async {
                  bool confirm = await _showDeleteDialog(context);
                  if (confirm) {
                    await FirestoreService().deleteExpense(e.id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
