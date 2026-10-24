import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firestore_service.dart';
import '../models/expense.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart'; // Ensure intl is in your pubspec.yaml

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final FirestoreService _fs = FirestoreService();
  // State for the currently selected month
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final String uid = authService.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Monthly Analysis",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildMonthPicker(), // New Month Selection UI
          Expanded(
            child: StreamBuilder<List<Expense>>(
              stream: _fs.streamUserExpenses(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final allData = snapshot.data ?? [];

                // FILTERING LOGIC: Only items matching selected month/year
                final filteredData = allData.where((item) {
                  return item.date.month == _selectedMonth.month &&
                      item.date.year == _selectedMonth.year;
                }).toList();

                Map<String, double> incomeMap = {};
                Map<String, double> expenseMap = {};
                double totalIncome = 0;
                double totalExpense = 0;

                for (var item in filteredData) {
                  if (item.amount > 0) {
                    incomeMap[item.category] =
                        (incomeMap[item.category] ?? 0) + item.amount;
                    totalIncome += item.amount;
                  } else {
                    double absVal = item.amount.abs();
                    expenseMap[item.category] =
                        (expenseMap[item.category] ?? 0) + absVal;
                    totalExpense += absVal;
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildSummaryHeader(totalIncome, totalExpense),
                      const SizedBox(height: 24),
                      _buildChartCard("Income Sources", incomeMap, totalIncome,
                          Colors.teal),
                      const SizedBox(height: 20),
                      _buildChartCard("Expense Categories", expenseMap,
                          totalExpense, Colors.orange),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // New Widget: Month Navigation
  Widget _buildMonthPicker() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 184, 177, 177),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedMonth =
                    DateTime(_selectedMonth.year, _selectedMonth.month - 1);
              });
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedMonth =
                    DateTime(_selectedMonth.year, _selectedMonth.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(double income, double expense) {
    return Row(
      children: [
        _summaryBox("Income", income, Colors.teal, Icons.add_circle_outline),
        const SizedBox(width: 12),
        _summaryBox(
            "Expense", expense, Colors.redAccent, Icons.remove_circle_outline),
      ],
    );
  }

  Widget _summaryBox(String label, double amount, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 195, 186, 186),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: const Color.fromARGB(255, 161, 155, 155),
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                "₹${amount.toStringAsFixed(0)}", // Changed to Rupee for your UI consistency
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, Map<String, double> categories,
      double total, Color themeColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: categories.isEmpty
                ? const Center(child: Text("No data for this month"))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _generateSections(categories, total),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          ...categories.entries
              .map((e) => _buildLegendItem(e.key, e.value, total)),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateSections(
      Map<String, double> map, double total) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.cyan
    ];
    int index = 0;

    return map.entries.map((entry) {
      final percentage = total > 0 ? (entry.value / total) * 100 : 0;
      final color = colors[index % colors.length];
      index++;
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: "${percentage.toStringAsFixed(0)}%",
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Widget _buildLegendItem(String name, double value, double total) {
    double percentage = total > 0 ? (value / total) * 100 : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${percentage.toStringAsFixed(1)}%",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color.fromARGB(255, 138, 150, 153),
                  fontSize: 13,
                  fontWeight: FontWeight.w400),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "₹${value.toStringAsFixed(2)}",
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
