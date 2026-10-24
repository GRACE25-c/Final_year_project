import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // WRAP EVERYTHING IN MATERIALAPP
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Tab Test"),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Tab 1'),
                Tab(text: 'Tab 2'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              Center(child: Text('Tab 1 Content')),
              Center(child: Text('Tab 2 Content')),
            ],
          ),
        ),
      ),
    );
  }
}
