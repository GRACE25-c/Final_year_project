import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:expense_trakio/services/auth_service.dart';
import 'package:expense_trakio/services/firestore_service.dart';
import 'package:expense_trakio/models/expense.dart';
import 'package:expense_trakio/widgets/manual_entry_sheet.dart';
import 'package:expense_trakio/screens/scan_screen.dart';
import 'package:expense_trakio/screens/analysis_screen.dart';
import 'package:expense_trakio/screens/group_wallet_screen.dart';
import 'package:expense_trakio/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  double _monthlyBudget = 0;
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUserBudget();
  }

  Future<void> _loadUserBudget() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      var doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data()!.containsKey('budgetLimit')) {
        setState(() {
          _monthlyBudget = (doc.data()!['budgetLimit'] as num).toDouble();
        });
      }
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _showManualEntrySheet(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualEntrySheet(type: type),
    );
  }

  String getHealthStatus(double score) {
    if (score >= 80) return "Excellent Health";
    if (score >= 50) return "Good Health";
    if (score >= 20) return "Fair Health";
    return "Poor Financial Health";
  }

  void _confirmDelete(Expense e) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete?"),
        content: const Text("Remove this transaction permanently?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance
                    .collection('expenses')
                    .doc(e.id)
                    .delete();
                _showSuccessSnackBar("Transaction deleted");
              } catch (err) {
                _showErrorSnackBar("Delete failed: $err");
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
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
              child: Text("Scan Receipt",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.indigo),
              title: const Text('Upload from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _navigateToScanner(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _navigateToScanner(ImageSource source) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ReceiptScannerScreen(source: source)));
  }

  void _showEditBudgetDialog() {
    final TextEditingController budgetController =
        TextEditingController(text: _monthlyBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Monthly Budget"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: budgetController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: "Enter amount",
              prefixText: "₹ ",
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor),
            onPressed: () async {
              double? newLimit = double.tryParse(budgetController.text);
              if (newLimit != null) {
                setState(() => _monthlyBudget = newLimit);
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .set({'budgetLimit': newLimit}, SetOptions(merge: true));
                }
              }
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final fs = FirestoreService();
    final uid = auth.currentUser?.uid ?? "";

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _index == 0
            ? AppBar(
                toolbarHeight: 0,
                bottom: const TabBar(
                  indicatorColor: Colors.blue,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(icon: Icon(Icons.dashboard), text: "Dashboard"),
                    Tab(icon: Icon(Icons.history), text: "History")
                  ],
                ),
              )
            : null,
        body: IndexedStack(
          index: _index,
          children: [
            StreamBuilder<List<Expense>>(
              stream: fs.streamUserExpenses(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final expenses = snap.data ?? [];
                final filteredForDashboard = expenses
                    .where((e) =>
                        e.date.month == _selectedDate.month &&
                        e.date.year == _selectedDate.year)
                    .toList();
                double allTimeSpent = 0;
                double allTimeIncome = 0;
                for (var e in expenses) {
                  e.amount < 0
                      ? allTimeSpent += e.amount.abs()
                      : allTimeIncome += e.amount;
                }
                return TabBarView(
                  children: [
                    _buildDashboard(uid, auth, fs, filteredForDashboard,
                        allTimeSpent, allTimeIncome),
                    _buildHistoryTab(expenses),
                  ],
                );
              },
            ),
            const AnalysisScreen(),
            const GroupWalletScreen(),
            const SettingsScreen(),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _index == 0 ? _buildFAB() : null,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.analytics_rounded), label: 'Analysis'),
            BottomNavigationBarItem(
                icon: Icon(Icons.group_work_rounded), label: 'Groups'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(
      String uid,
      AuthService auth,
      FirestoreService fs,
      List<Expense> list, // Current month expenses
      double totalSpent, // All-time spent
      double totalIncome // All-time income
      ) {
    // 1. Calculate specific MONTHLY values
    double monthlySpent = 0;
    double monthlyIncome = 0;

    for (var e in list) {
      e.amount < 0 ? monthlySpent += e.amount.abs() : monthlyIncome += e.amount;
    }

    // 2. Health Score: (Income - Expense) / Income
    double healthScore = 0;
    if (totalIncome > 0) {
      // Formula: (Lifetime Income - Lifetime Expense) / Lifetime Income
      healthScore =
          ((totalIncome - totalSpent) / totalIncome * 100).clamp(0, 100);
    } else {
      // If no income exists, health is 100 if no spending, else 0
      healthScore = totalSpent == 0 ? 100 : 0;
    }

    // 3. Limit Graph: Spent / Budget
    double progress = _monthlyBudget > 0
        ? (monthlySpent / _monthlyBudget).clamp(0.0, 1.0)
        : 0.0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeader(
              auth,
              fs,
              list,
              monthlySpent,
              monthlyIncome,
              progress, // Monthly Limit Tracking
              healthScore,
              totalSpent, // All-time Spent
              totalIncome),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
            child: Text("Recent Activity",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ),
        list.isEmpty
            ? const SliverFillRemaining(
                child: Center(child: Text("No transactions this month")))
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildExpenseTile(list[i]),
                      childCount: list.length),
                ),
              ),
      ],
    );
  }

  Widget _buildHistoryTab(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No transaction history found",
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Grouping logic: Organize expenses by month/year
    final groupedData = _groupExpensesByMonth(expenses);
    final sortedKeys = groupedData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 100),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        DateTime monthKey = sortedKeys[index];
        List<Expense> monthExpenses = groupedData[monthKey]!;

        // Calculate monthly net balance
        double netBalance =
            monthExpenses.fold(0, (sum, item) => sum + item.amount);
        String monthDisplay = DateFormat('MMMM yyyy').format(monthKey);

        return Theme(
          // This removes the highlight color when the tile is expanded
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: Colors.grey,
            collapsedIconColor: Colors.grey,
            title: Text(
              monthDisplay,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87),
            ),
            subtitle: Text(
              "Net balance: ₹${netBalance.toStringAsFixed(2)}",
              style: TextStyle(
                color: netBalance >= 0 ? Colors.green : Colors.redAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            // map each expense in this month to your existing _buildExpenseTile
            children: monthExpenses.map((e) => _buildExpenseTile(e)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
      AuthService auth,
      FirestoreService fs,
      List<Expense> list,
      double spent,
      double income,
      double progress,
      double healthScore,
      double allTimeSpent,
      double allTimeIncome) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Expense Trakio",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                      icon:
                          const Icon(Icons.file_download, color: Colors.white),
                      onPressed: () =>
                          fs.exportExpensesToExcel(list, "General_Report")),
                  IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () => auth.signOut()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildBudgetCard(spent, _monthlyBudget, _monthlyBudget - spent,
              progress, allTimeIncome, allTimeSpent),
          const SizedBox(height: 15),
          _buildHealthScoreSection(healthScore, spent, _monthlyBudget),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(double monthlySpent, double budget, double remaining,
      double percent, double allTimeIncome, double allTimeSpent) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monthly Limit",
                  style: TextStyle(color: Colors.white70)),
              GestureDetector(
                onTap: _showEditBudgetDialog,
                child: Row(
                  children: [
                    Text("₹${budget.toStringAsFixed(0)}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    const SizedBox(width: 5),
                    const Icon(Icons.edit, color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              color: percent > 0.9 ? Colors.redAccent : Colors.greenAccent),
          const SizedBox(height: 10),
          // Inside your header/budget card widget:
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Spent: ₹${allTimeSpent.toStringAsFixed(2)}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Text("Total Income: ₹${allTimeIncome.toStringAsFixed(2)}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScoreSection(double score, double spent, double budget) {
    bool isOverBudget = budget > 0 && spent > budget;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isOverBudget
            ? Border.all(color: Colors.redAccent, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            height: 40,
            width: 40,
            child: CircularProgressIndicator(
              value: isOverBudget ? 1.0 : (score / 100),
              color: isOverBudget
                  ? Colors.red
                  : (score > 50 ? Colors.green : Colors.orange),
              backgroundColor: Colors.grey,
              strokeWidth: 5,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isOverBudget ? "EXPENSE EXCEEDED" : "Health Score",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOverBudget ? Colors.red : Colors.black)),
                Text(
                    isOverBudget
                        ? "Over limit by ₹${(spent - budget).toStringAsFixed(2)}"
                        : getHealthStatus(score),
                    style: TextStyle(
                        color: isOverBudget ? Colors.redAccent : Colors.grey,
                        fontSize: 12)),
              ],
            ),
          ),
          if (isOverBudget)
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Smaller Row for Add and Remove
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 45, // Smaller footprint
                height: 45,
                child: FloatingActionButton(
                  heroTag: "inc",
                  mini: true, // This makes the button smaller automatically
                  backgroundColor:
                      const Color(0xFF4CAF50), // Matches your green
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                  onPressed: () => _showManualEntrySheet('income'),
                ),
              ),
              const SizedBox(width: 15),
              SizedBox(
                width: 45,
                height: 45,
                child: FloatingActionButton(
                  heroTag: "exp",
                  mini: true,
                  backgroundColor: const Color(0xFFFF5252), // Matches your red
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child:
                      const Icon(Icons.remove, color: Colors.white, size: 24),
                  onPressed: () => _showManualEntrySheet('expense'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Smaller Scan Button
          SizedBox(
            width: 110, // Reduced from 140
            height: 50, // Reduced from 60
            child: FloatingActionButton.extended(
              heroTag: "scan",
              backgroundColor: const Color(0xFF00695C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              icon: const Icon(Icons.qr_code_scanner,
                  color: Colors.white, size: 20),
              label: const Text(
                "Scan",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showPickerOptions(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense) {
    final bool isIncome = expense.amount > 0;
    final Color statusColor = isIncome ? Colors.green : Colors.redAccent;
    String datePart = DateFormat('dd MMM').format(expense.date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isIncome
                ? Colors.green.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
            child: Icon(expense.categoryIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.category,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                if (expense.description.isNotEmpty)
                  Text(expense.description,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                Text(datePart,
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("₹${expense.amount.abs().toStringAsFixed(2)}",
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              GestureDetector(
                  onTap: () => _confirmDelete(expense),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.grey, size: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Map<DateTime, List<Expense>> _groupExpensesByMonth(List<Expense> expenses) {
    Map<DateTime, List<Expense>> groups = {};
    for (var expense in expenses) {
      // This creates a key for the 1st of every month (e.g., 2026-04-01)
      DateTime monthKey = DateTime(expense.date.year, expense.date.month);

      if (groups[monthKey] == null) {
        groups[monthKey] = [];
      }
      groups[monthKey]!.add(expense);
    }

    // Sort individual transactions inside each month so newest is on top
    groups.forEach((key, list) {
      list.sort((a, b) => b.date.compareTo(a.date));
    });

    return groups;
  }
} // <--- This final brace closes the class!
