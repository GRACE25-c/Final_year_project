import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'scan_screen.dart'; // Ensure this points to your ReceiptScannerScreen file
import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  double groupBudgetLimit = 5000.0;
  final FirestoreService _fs = FirestoreService();
  bool _isFabMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  void _toggleFabMenu() => setState(() => _isFabMenuOpen = !_isFabMenuOpen);

  Future<void> exportToExcel(List<Expense> expenses, String groupName) async {
    var excel = excel_lib.Excel.createExcel();
    excel_lib.Sheet sheetObject = excel['Monthly Report'];

    // 1. Add Header Row
    List<String> headers = [
      "Date",
      "Category",
      "Merchant",
      "Amount",
      "Type",
      "Notes"
    ];
    sheetObject
        .appendRow(headers.map((e) => excel_lib.TextCellValue(e)).toList());

    // 2. Add Data Rows
    for (var x in expenses) {
      sheetObject.appendRow([
        excel_lib.TextCellValue(DateFormat('dd-MM-yyyy').format(x.date)),
        excel_lib.TextCellValue(x.category),
        excel_lib.TextCellValue(x.merchant),
        excel_lib.DoubleCellValue(x.amount),
        excel_lib.TextCellValue(x.type),
        excel_lib.TextCellValue(x.description),
      ]);
    }

    // 3. Save the file to the device
    var fileBytes = excel.save();
    final directory = await getTemporaryDirectory();
    final filePath = "${directory.path}/${groupName}_Report.xlsx";

    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    // 4. Share the file
    await Share.shareXFiles([XFile(filePath)],
        text: 'Monthly Expense Report for $groupName');
  }
  // --- NAVIGATION & PICKER LOGIC ---

  void _navigateToScanner(ImageSource source) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptScannerScreen(
          source: source,
          groupId: widget
              .groupId, // Passes the ID so scanner knows it's a group expense
        ),
      ),
    );
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Upload Group Receipt",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Select from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _navigateToScanner(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- DATABASE & BUDGET LOGIC ---

  Future<void> _loadGroupData() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      if (doc.exists && doc.data()!.containsKey('budgetLimit')) {
        setState(() {
          groupBudgetLimit = (doc.data()!['budgetLimit'] as num).toDouble();
        });
      }
    } catch (e) {
      debugPrint("Error loading group data: $e");
    }
  }

  void _showEditBudgetDialog() {
    final TextEditingController budgetController =
        TextEditingController(text: groupBudgetLimit.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Group Budget Limit"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: budgetController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Enter amount",
            prefixText: "₹ ",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () async {
              double? newLimit = double.tryParse(budgetController.text);
              if (newLimit != null) {
                setState(() => groupBudgetLimit = newLimit);
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .update({'budgetLimit': newLimit});
              }
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- MANUAL ENTRY LOGIC ---
  void _showManualEntrySheet({bool isIncome = false}) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController merchantController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController otherCategoryController =
        TextEditingController();

    DateTime selectedDate = DateTime.now();

    // 1. Initialize the default selection
    String selectedCategory = isIncome ? 'Salary' : 'General';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        // 2. Listen to the user's document for custom categories
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Default categories if data hasn't loaded yet
          List<String> categories = isIncome
              ? ['Salary', 'Gift', 'Investment', 'Other']
              : [
                  'Food',
                  'Transport',
                  'Shopping',
                  'Entertainment',
                  'General',
                  'Other'
                ];

          if (snapshot.hasData && snapshot.data!.exists) {
            Map<String, dynamic> userData =
                snapshot.data!.data() as Map<String, dynamic>;
            if (userData.containsKey('customCategories')) {
              List<String> custom =
                  List<String>.from(userData['customCategories']);
              // Merge custom categories with default ones
              categories.addAll(custom);
              categories = categories.toSet().toList(); // Remove duplicates
            }
          }

          return StatefulBuilder(
            builder: (context, setSheetState) => Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20,
                  right: 20,
                  top: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Text(isIncome ? "Add Income" : "Add Expense",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  TextField(
                    controller: amountController,
                    textAlign: TextAlign.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                        hintText: "0.00", prefixText: "₹ "),
                  ),
                  // 3. The Dropdown now uses the dynamic 'categories' list
                  DropdownButtonFormField<String>(
                    initialValue: categories.contains(selectedCategory)
                        ? selectedCategory
                        : categories.first,
                    items: categories
                        .map((cat) =>
                            DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (val) =>
                        setSheetState(() => selectedCategory = val!),
                    decoration: const InputDecoration(labelText: "Category"),
                  ),
                  if (selectedCategory == "Other")
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: otherCategoryController,
                        cursorColor: const Color(0xFF1A5276),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.edit_note,
                              color: Colors.black87, size: 28),
                          labelText: "New Category",
                          labelStyle: const TextStyle(
                              color: Color(0xFF1A5276), fontSize: 14),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          suffixIcon: IconButton(
                            onPressed: () => otherCategoryController.clear(),
                            icon: const Icon(Icons.cancel,
                                color: Colors.grey, size: 20),
                          ),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: Color(0xFF1A5276), width: 1.5),
                          ),
                        ),
                      ),
                    ),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, size: 20),
                    title: Text(
                      "Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: const Icon(Icons.edit, size: 16),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        // If you are inside a showModalBottomSheet with StatefulBuilder
                        setSheetState(() {
                          selectedDate = picked;
                        });

                        // Also update the parent state so the main class knows about the change
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  const Divider(height: 1),
                  TextField(
                      controller: merchantController,
                      decoration: const InputDecoration(labelText: "Merchant")),
                  TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: "Notes")),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      // 1. Close the bottom sheet immediately
                      Navigator.pop(context);

                      try {
                        final uid =
                            FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
                        double amt =
                            double.tryParse(amountController.text) ?? 0.0;
                        String finalCategory = (selectedCategory == "Other" &&
                                otherCategoryController.text.isNotEmpty)
                            ? otherCategoryController.text.trim()
                            : selectedCategory;
                        if (selectedCategory == "Other" &&
                            otherCategoryController.text.isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update({
                            'customCategories':
                                FieldValue.arrayUnion([finalCategory])
                          });
                        }
                        final newExpense = Expense(
                          id: '', // Firestore generates this
                          userId: uid,
                          merchant: merchantController.text,
                          amount: isIncome ? amt : -amt,
                          category: finalCategory,
                          date: selectedDate, // Uses the actual date picked
                          description: descController.text,
                          type: isIncome ? 'income' : 'expense',
                          imageUrl: '',
                        );

                        // 2. Add to Firestore in the background
                        await _fs.addGroupExpense(widget.groupId, newExpense);

                        // 3. Show a quick confirmation
                        _showSuccessSnackBar(
                            "Transaction saved as $finalCategory");
                      } catch (e) {
                        // Show error if the save fails
                        _showErrorSnackBar("Failed to save: $e");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isIncome ? Colors.green : Colors.blue,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Save",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddMemberDialog() {
    final TextEditingController emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Invite Member"),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            hintText: "Enter user email",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              String email = emailController.text.trim();
              if (email.isNotEmpty) {
                try {
                  // 1. Find the user by email in the 'users' collection
                  var userQuery = await FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();

                  if (userQuery.docs.isEmpty) {
                    _showErrorSnackBar("No user found with this email.");
                    return;
                  }

                  var userData = userQuery.docs.first.data();
                  String newUserUid = userQuery.docs.first.id;
                  String newUserName = userData['name'] ?? "Unknown Member";

                  // 2. Update the Group document with BOTH the ID and the Info Map
                  await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .update({
                    'members':
                        FieldValue.arrayUnion([newUserUid]), // Security/ID list
                    'members_info.$newUserUid': {
                      // UI Display Map
                      'name': newUserName,
                      'role': 'member',
                      'joinedAt': FieldValue.serverTimestamp(),
                    }
                  });

                  if (mounted) Navigator.pop(context);
                  _showSuccessSnackBar("Member added successfully!");
                } catch (e) {
                  _showErrorSnackBar("Failed to invite: $e");
                }
              }
            },
            child: const Text("Invite"),
          ),
        ],
      ),
    );
  }

  // --- MEMBER TAB ---
  Widget _buildMembersTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        Map<String, dynamic> membersInfo = data['members_info'] ?? {};
        String ownerId = data['ownerId'] ?? "";
        String currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? "";

        List<String> memberUids = membersInfo.keys.toList();

        if (memberUids.isEmpty) {
          return const Center(child: Text("No members found."));
        }

        return ListView.builder(
          itemCount: memberUids.length,
          itemBuilder: (context, index) {
            String memberUid = memberUids[index];
            var memberData = membersInfo[memberUid] as Map<String, dynamic>?;

            // Safety check: if data for this UID is missing, skip rendering it
            if (memberData == null) return const SizedBox.shrink();

            String displayName = memberData['name'] ?? "Unknown";
            bool isCreator = memberUid == ownerId;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isCreator
                    ? Colors.orange
                    : Theme.of(context).colorScheme.primary,
                child: Text(
                  // CHANGE: Show only the first letter for a cleaner look
                  displayName.isNotEmpty ? displayName.toUpperCase() : "?",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(isCreator ? "Creator" : "Member"),
              trailing: currentUserUid == ownerId && memberUid != ownerId
                  ? IconButton(
                      icon: const Icon(Icons.person_remove_outlined,
                          color: Colors.red),
                      onPressed: () =>
                          _confirmRemoveMemberMap(memberUid, displayName),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  void _confirmRemoveMemberMap(String memberUid, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Member?"),
        content: Text("Are you sure you want to remove $name?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .update({
                  // Delete the specific entry from the Map using dot notation
                  'members_info.$memberUid': FieldValue.delete(),
                  // Also remove from the ID list for security rules
                  'members': FieldValue.arrayRemove([memberUid])
                });
                if (mounted) Navigator.pop(context);
                _showSuccessSnackBar("Member removed");
              } catch (e) {
                _showErrorSnackBar("Failed to remove: $e");
              }
            },
            child: const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- DASHBOARD UI ---
  Widget _buildCurrentStatusTab(List<Expense> expenses) {
    final now = DateTime.now();

    // 1. MONTHLY TOTALS (for the Progress Bar and Warning)
    double monthlySpent = expenses
        .where((e) =>
            e.amount < 0 &&
            e.date.month == now.month &&
            e.date.year == now.year)
        .fold(0.0, (sum, e) => sum + e.amount.abs());

    double monthlyIncome = expenses
        .where((e) =>
            e.amount > 0 &&
            e.date.month == now.month &&
            e.date.year == now.year)
        .fold(0.0, (sum, e) => sum + e.amount);

    // 2. ALL-TIME TOTALS (for the Health Score)
    double allTimeSpent = expenses
        .where((e) => e.amount < 0)
        .fold(0.0, (sum, e) => sum + e.amount.abs());

    double allTimeIncome = expenses
        .where((e) => e.amount > 0)
        .fold(0.0, (sum, e) => sum + e.amount);

    // 3. HEALTH SCORE CALCULATION (Based on All-Time)
    double healthScore = 0;
    if (allTimeIncome > 0) {
      healthScore =
          ((allTimeIncome - allTimeSpent) / allTimeIncome).clamp(0.0, 1.0);
    } else {
      healthScore = allTimeSpent == 0 ? 1.0 : 0.0;
    }

    // 4. MONTHLY BUDGET PROGRESS (for the top bar)
    double monthlyProgress = groupBudgetLimit > 0
        ? ((groupBudgetLimit - monthlySpent) / groupBudgetLimit).clamp(0.0, 1.0)
        : 0;

    // 5. Category Map (remains monthly for the Breakdown chart)
    Map<String, double> categoryMap = {};
    for (var e in expenses.where((e) =>
        e.amount < 0 && e.date.month == now.month && e.date.year == now.year)) {
      categoryMap.update(e.category, (val) => val + e.amount.abs(),
          ifAbsent: () => e.amount.abs());
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Shows monthly spent vs monthly limit
          _buildSummaryHeader(monthlySpent, monthlyIncome, monthlyProgress),

          _buildBudgetExceededWarning(monthlySpent),

          // --- HEALTH SCORE SECTION (Now using all-time healthScore) ---
          _buildHealthScoreCard(healthScore),

          if (categoryMap.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Monthly Breakdown",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16))),
            ),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 45,
                  sections: categoryMap.entries.map((entry) {
                    final colors = [
                      Colors.blue,
                      Colors.orange,
                      Colors.redAccent,
                      Colors.green,
                      Colors.purple,
                      Colors.teal
                    ];
                    int index = categoryMap.keys.toList().indexOf(entry.key);
                    double percentage = (entry.value / monthlySpent) * 100;

                    return PieChartSectionData(
                      color: colors[index % colors.length],
                      value: entry.value,
                      title: "${entry.key}\n${percentage.toStringAsFixed(0)}%",
                      radius: 60,
                      titleStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(),
          ],

          expenses.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text("No transactions yet"))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) =>
                      _buildExpenseTile(expenses[index]),
                ),
        ],
      ),
    );
  }

  Widget _buildBudgetExceededWarning(double totalSpent) {
    if (totalSpent <= groupBudgetLimit) return const SizedBox.shrink();

    double exceededAmount = totalSpent - groupBudgetLimit;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Budget Limit Exceeded!",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "You are ₹${exceededAmount.toStringAsFixed(2)} over your set limit of ₹${groupBudgetLimit.toStringAsFixed(0)}.",
                  style: TextStyle(color: Colors.red[900], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense) {
    final bool isIncome =
        expense.type == 'income'; // Logic check for income type
    final Color statusColor = isIncome ? Colors.green : Colors.redAccent;

    // Use the same colors and opacity as your Home Screen
    final Color bgColor =
        isIncome ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        children: [
          // 1. The Category Icon (matches Home Screen style)
          CircleAvatar(
            radius: 22,
            backgroundColor: bgColor,
            child: Icon(
              expense.categoryIcon, // Uses the logic from your model
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // 2. Center Info: Category and Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.category,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (expense.description.isNotEmpty)
                  Text(
                    expense.description,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  DateFormat('dd MMM').format(expense.date),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),

          // 3. Right Side: Amount and Delete
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹${expense.amount.abs().toStringAsFixed(2)}",
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              GestureDetector(
                onTap: () => _confirmDelete(expense),
                child: const Icon(Icons.delete_outline,
                    color: Colors.grey, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _confirmDelete(Expense e) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Transaction?"),
        content: const Text(
            "Are you sure you want to remove this entry? This cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // 1. Close the dialog immediately so the UI feels responsive
              Navigator.pop(context);

              try {
                // 2. Perform the deletion in the background
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('expenses')
                    .doc(e.id)
                    .delete();

                // 3. Show success message
                _showSuccessSnackBar("Transaction deleted");
              } catch (err) {
                // 4. Show error message if it fails
                _showErrorSnackBar("Delete failed: $err");
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  Widget _buildSummaryHeader(double spent, double income, double score) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(25))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderMetric("Spent", "₹${spent.toStringAsFixed(2)}"),
              _buildHeaderMetric("Income", "₹${income.toStringAsFixed(2)}"),
            ],
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(
              value: score,
              backgroundColor: Colors.white24,
              color: score < 0.2 ? Colors.redAccent : Colors.greenAccent,
              minHeight: 8),
          const SizedBox(height: 5),
          Text("${(score * 100).toStringAsFixed(0)}% Budget Remaining",
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildHeaderMetric(String label, String value) => Column(children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
      ]);

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row for Manual Entry (+ and -)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: "group_inc",
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _showManualEntrySheet(isIncome: true),
            ),
            const SizedBox(width: 15), // Horizontal gap
            FloatingActionButton.small(
              heroTag: "group_exp",
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.remove, color: Colors.white),
              onPressed: () => _showManualEntrySheet(isIncome: false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Centered Scan Button
        FloatingActionButton.extended(
          heroTag: "group_scan",
          elevation: 4,
          backgroundColor: Theme.of(context).colorScheme.primary,
          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
          label: const Text("Scan", style: TextStyle(color: Colors.white)),
          onPressed: () => _showPickerOptions(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Start with the StreamBuilder first
    return StreamBuilder<List<Expense>>(
      stream: _fs.streamGroupExpenses(widget.groupId),
      builder: (context, snapshot) {
        // 2. Define 'expenses' right here so the whole Scaffold can see it
        final expenses = snapshot.data ?? [];

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.groupName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.file_download),
                  // Now 'expenses' is defined and usable here!
                  onPressed: expenses.isEmpty
                      ? null
                      : () => exportToExcel(expenses, widget.groupName),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note),
                  onPressed: _showEditBudgetDialog,
                )
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.speed), text: "Status"),
                  Tab(icon: Icon(Icons.history), text: "History"),
                  Tab(icon: Icon(Icons.group), text: "Members")
                ],
              ),
            ),
            body: snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _buildCurrentStatusTab(expenses),
                      _buildHistoryTab(expenses),
                      _buildMembersTab(),
                    ],
                  ),
            floatingActionButton: _buildFab(),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(List<Expense> allExpenses) {
    if (allExpenses.isEmpty) {
      return const Center(
        child: Text("No transaction history yet.",
            style: TextStyle(color: Colors.grey)),
      );
    }
    Map<String, List<Expense>> monthlyGroups = {};
    for (var e in allExpenses) {
      String monthKey = DateFormat('MMMM yyyy').format(e.date);
      monthlyGroups.putIfAbsent(monthKey, () => []).add(e);
    }
    return ListView.builder(
      itemCount: monthlyGroups.keys.length,
      itemBuilder: (context, index) {
        String month = monthlyGroups.keys.elementAt(index);
        List<Expense> monthExpenses = monthlyGroups[month]!;
        double monthTotal = monthExpenses.fold(0, (sum, e) => sum + e.amount);
        return ExpansionTile(
          title:
              Text(month, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Net balance: ₹${monthTotal.toStringAsFixed(2)}",
              style: TextStyle(
                  color: monthTotal >= 0 ? Colors.green : Colors.red)),
          children: monthExpenses.map((e) => _buildExpenseTile(e)).toList(),
        );
      },
    );
  }

  Widget _buildHealthScoreCard(double score) {
    // Logic to determine status text and color
    String status = score > 0.7
        ? "Excellent"
        : score > 0.4
            ? "Good"
            : "Warning";
    Color statusColor = score > 0.7
        ? Colors.green
        : score > 0.4
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 50,
            width: 50,
            child: CircularProgressIndicator(
              value: score, // Progress based on 0.0 to 1.0
              strokeWidth: 8,
              backgroundColor: Colors.grey,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Group Health Score",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                status,
                style:
                    TextStyle(color: statusColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
