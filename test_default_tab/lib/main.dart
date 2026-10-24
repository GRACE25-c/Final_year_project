import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tab Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      // The home MUST be the DefaultTabController or a widget containing it
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Expense Trakio Tab Test'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
                Tab(icon: Icon(Icons.history), text: 'History'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              Center(
                child: Text(
                  'Dashboard Placeholder',
                  style: TextStyle(fontSize: 20),
                ),
              ),
              Center(
                child: Text(
                  'History Placeholder',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
