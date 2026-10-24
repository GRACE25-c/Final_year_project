import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/expense.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManualEntrySheet extends StatefulWidget {
  final String type; // 'income' or 'expense'

  const ManualEntrySheet({super.key, required this.type});

  @override
  State<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<ManualEntrySheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _customCategoryController =
      TextEditingController(); // For "Other"

  DateTime _selectedDate = DateTime.now();
  late String _selectedCategory;
  bool _isCreatingCustom = false;

  final List<String> _expenseCategories = [
    'Food',
    'Transport',
    'Rent',
    'Shopping',
    'Entertainment',
    'Other'
  ];
  final List<String> _incomeCategories = [
    'Salary',
    'Freelance',
    'Gift',
    'Investment',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.type == 'income'
        ? _incomeCategories.first
        : _expenseCategories.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _merchantController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  // --- HELPER: BUDGET ALERT DIALOG ---
  Future<bool> _showBudgetWarning(
      double currentSpent, double limit, double newAmount) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Budget Limit Exceeded!"),
            content: Text(
                "Adding this ₹${newAmount.toStringAsFixed(2)} will put you over your ₹${limit.toStringAsFixed(0)} limit.\n\nDo you still want to save it?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel")),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Save Anyway",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    bool isIncome = widget.type == 'income';
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid ?? "";

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Add ${widget.type.toUpperCase()}",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Amount Field (₹ Symbol)
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: "₹ ",
                hintText: "0.00",
                border: InputBorder.none,
              ),
            ),

            // Merchant/Source
            TextField(
              controller: _merchantController,
              decoration: InputDecoration(
                labelText: isIncome ? "Source" : "Merchant Name",
                prefixIcon: const Icon(Icons.storefront),
              ),
            ),
            const SizedBox(height: 15),

            // DYNAMIC CATEGORY SECTION
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                List<String> categories = isIncome
                    ? List.from(_incomeCategories)
                    : List.from(_expenseCategories);

                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  if (data.containsKey('customCategories')) {
                    categories
                        .addAll(List<String>.from(data['customCategories']));
                  }
                }

                if (_isCreatingCustom) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customCategoryController,
                          autofocus: true,
                          decoration: const InputDecoration(
                              labelText: "New Category",
                              prefixIcon: Icon(Icons.edit_note)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.grey),
                        onPressed: () =>
                            setState(() => _isCreatingCustom = false),
                      )
                    ],
                  );
                }

                return DropdownButtonFormField<String>(
                  initialValue: categories.contains(_selectedCategory)
                      ? _selectedCategory
                      : categories.first,
                  items: categories
                      .toSet()
                      .map((cat) =>
                          DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (val) {
                    if (val == 'Other') {
                      setState(() => _isCreatingCustom = true);
                    } else {
                      setState(() => _selectedCategory = val!);
                    }
                  },
                  decoration: const InputDecoration(
                      labelText: "Category",
                      prefixIcon: Icon(Icons.category_outlined)),
                );
              },
            ),

            const SizedBox(height: 15),

            // Description
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                  labelText: "Description",
                  prefixIcon: Icon(Icons.description_outlined)),
            ),

            // Date Row
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                  "Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}"),
              trailing: TextButton(
                  onPressed: () => _selectDate(context),
                  child: const Text("Change")),
            ),

            const SizedBox(height: 20),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isIncome ? Colors.green : Colors.redAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () async {
                  final double? enteredAmount =
                      double.tryParse(_amountController.text);
                  if (uid.isEmpty || enteredAmount == null) return;

                  final fs = FirestoreService();

                  // --- UPDATED BUDGET CHECK LOGIC ---
                  if (!isIncome) {
                    // 1. Get Actual Budget from Firestore
                    var userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .get();
                    double budgetLimit =
                        (userDoc.data()?['budgetLimit'] ?? 15000.0).toDouble();

                    // 2. Calculate Current Monthly Spent
                    final expenses = await fs.streamUserExpenses(uid).first;
                    double currentSpent = expenses
                        .where((e) =>
                            e.amount < 0 &&
                            e.date.month == DateTime.now().month)
                        .fold(0.0, (sum, e) => sum + e.amount.abs());

                    if (currentSpent + enteredAmount > budgetLimit) {
                      bool proceed = await _showBudgetWarning(
                          currentSpent, budgetLimit, enteredAmount);
                      if (!proceed) return;
                    }
                  }

                  // Handle Custom Category
                  String finalCategory = _isCreatingCustom
                      ? _customCategoryController.text.trim()
                      : _selectedCategory;
                  // AUTO-FORMAT: Ensures "health" becomes "Health"
                  if (finalCategory.isNotEmpty) {
                    finalCategory = finalCategory[0].toUpperCase() +
                        finalCategory.substring(1).toLowerCase();
                  }

                  if (_isCreatingCustom && finalCategory.isNotEmpty) {
                    await fs.addUserCustomCategory(uid, finalCategory);
                  }
                  Expense newEntry = Expense(
                    id: '',
                    userId: uid,
                    amount: isIncome ? enteredAmount : -enteredAmount,
                    merchant: _merchantController.text.trim().isEmpty
                        ? 'General'
                        : _merchantController.text.trim(),
                    description: _descController.text.trim(),
                    date: _selectedDate,
                    category: finalCategory,
                    type: widget.type,
                  );

                  await fs.addExpense(newEntry);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("Confirm",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }
}
