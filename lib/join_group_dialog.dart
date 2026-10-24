import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MaterialApp(
    home: SharedWalletHomeScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class SharedWalletHomeScreen extends StatelessWidget {
  const SharedWalletHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Soft background color
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                "Shared Wallets",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D4263),
                ),
              ),
              const Text(
                "Manage expenses with friends or family",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Action Buttons Row
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.add_circle_outline,
                    label: "Create",
                    onTap: () {}, // Logic for Create
                  ),
                  const SizedBox(width: 15),
                  _buildActionButton(
                    icon: Icons.person_add_alt_1_outlined,
                    label: "Join",
                    onTap: () {
                      // TRIGGER YOUR DIALOG HERE
                      showDialog(
                        context: context,
                        builder: (context) => const JoinGroupDialog(),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 40),
              const Text(
                "Your Groups",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              _buildGroupCard("Roommate", "ID: n1u7DlnW87ViWsEX9Kq"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF2D4263),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF2D4263).withOpacity(0.1),
            child: const Icon(Icons.group, color: Color(0xFF2D4263)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}

class JoinGroupDialog extends StatefulWidget {
  const JoinGroupDialog({super.key});

  @override
  _JoinGroupDialogState createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<JoinGroupDialog> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedName();
  }

  _loadSavedName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? "";
    });
  }

  _saveName(String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Join Shared Wallet", textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _idController,
            decoration: const InputDecoration(
              labelText: "Group ID",
              hintText: "Paste Group ID here",
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: "Your Name",
              hintText: "Enter your name for the member list",
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.blueGrey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: const StadiumBorder(),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
          ),
          onPressed: () {
            if (_idController.text.isNotEmpty &&
                _nameController.text.isNotEmpty) {
              _saveName(_nameController.text);

              // SUCCESS! Logic to add to member list goes here
              print("Joining ${_idController.text} as ${_nameController.text}");

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Joined Group Successfully!")),
              );
            }
          },
          child: const Text("Join",
              style:
                  TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
