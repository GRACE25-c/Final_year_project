import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // --- 1. CATEGORY MANAGEMENT ---
  void _showAddCategoryDialog() {
    final TextEditingController categoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Category"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: TextField(
          controller: categoryController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Category Name (e.g. Health)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () async {
              if (categoryController.text.isNotEmpty && user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .update({
                  'customCategories':
                      FieldValue.arrayUnion([categoryController.text.trim()])
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Category Added!")));
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // --- 2. THEME SELECTION ---
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select App Theme"),
        content: Wrap(
          spacing: 15,
          runSpacing: 15,
          children: [
            _themeCircle(Colors.blue, "Classic Blue"),
            _themeCircle(Colors.teal, "Nature Teal"),
            _themeCircle(Colors.deepPurple, "Royal Purple"),
            _themeCircle(Colors.indigo, "Midnight"),
          ],
        ),
      ),
    );
  }

// Add this helper inside _SettingsScreenState
  void _deleteCategory(String categoryName) async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'customCategories': FieldValue.arrayRemove([categoryName])
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$categoryName deleted")),
    );
  }

  void _showDeleteConfirmation(String categoryName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Category?"),
        content: Text(
            "Are you sure you want to remove '$categoryName'? \n\nNote: Existing transactions with this category will remain, but you won't be able to select this tag for new ones."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _deleteCategory(categoryName);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _themeCircle(Color color, String name) {
    return GestureDetector(
      onTap: () {
        Provider.of<ThemeProvider>(context, listen: false)
            .setSelectedTheme(color);

        Navigator.pop(context); // Close the dialog
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(backgroundColor: color, radius: 25),
          const SizedBox(height: 4),
          Text(name.split(' ').last, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // FIX: Handling the "White Screen" by providing feedback during loading/error
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("User profile not found."));
          }

          return ListView(
            padding: const EdgeInsets.all(10),
            children: [
              // Profile Header
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: const Icon(Icons.person,
                          size: 40, color: Colors.blue),
                    ),
                    const SizedBox(height: 10),
                    Text(user?.email ?? "",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- SECTION: CATEGORIES ---
              _buildSectionTitle("Personalization"),
              _buildSettingsTile(
                icon: Icons.category,
                color: Colors.orange,
                title: "Custom Categories",
                subtitle: "Create your own expense tags",
                onTap: _showAddCategoryDialog,
              ),
              _buildSettingsTile(
                icon: Icons.palette,
                color: Colors.pink,
                title: "App Theme",
                subtitle: "Choose from 4 colors",
                onTap: _showThemeDialog,
              ),
// Add this to your ListView in SettingsScreen
              _buildSectionTitle("Manage Customizations"),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox();
                  }

                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  List<String> customCategories =
                      List<String>.from(data['customCategories'] ?? []);

                  return ExpansionTile(
                    leading:
                        const Icon(Icons.edit_attributes, color: Colors.orange),
                    title: const Text("Edit Categories"),
                    subtitle: Text("${customCategories.length} custom tags"),
                    children: customCategories
                        .map((cat) => ListTile(
                              title: Text(cat),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_sweep,
                                    color: Colors.redAccent),
                                onPressed: () => _showDeleteConfirmation(cat),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),

// 3. Referral Tile
              _buildSettingsTile(
                icon: Icons.share,
                color: Colors.green,
                title: "Refer to a Friend",
                subtitle: "Invite others to use the app",
                onTap: () {
                  Share.share(
                      "Check out Expense Trakio! Managing money with friends made easy.");
                },
              ),
              // --- SECTION: LOGOUT ---
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text("Sign Out",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => auth.signOut(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 3. DYNAMIC GROUP ID LIST ---
  Widget _buildGroupIdsList() {
    // Use the email from the 'user' variable defined at the top of your state class
    final userEmail = user?.email;

    if (userEmail == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      // This stream listens for ANY changes in the 'groups' collection where you are a member
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: userEmail)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: LinearProgressIndicator()),
          );
        }

        final groups = snapshot.data?.docs ?? [];

        return ExpansionTile(
          leading: const Icon(Icons.group_work, color: Colors.blue),
          title: const Text("My Group IDs"),
          subtitle: Text("${groups.length} active groups"),
          // Added 'initiallyExpanded' so you can see changes immediately during testing
          children: groups.isEmpty
              ? [
                  const ListTile(
                      title: Text("No groups found",
                          style: TextStyle(fontSize: 12, color: Colors.grey)))
                ]
              : groups.map((doc) {
                  final groupData = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(groupData['name'] ?? "Unnamed Group",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text("ID: ${doc.id}",
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: IconButton(
                      icon:
                          const Icon(Icons.copy, size: 18, color: Colors.blue),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: doc.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Group ID copied!")),
                        );
                      },
                    ),
                  );
                }).toList(),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey))
          : null,
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showJoinGroupDialog() {
    final TextEditingController idController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Join a Group"),
        content: TextField(
          controller: idController,
          decoration: const InputDecoration(
            hintText: "Paste Group ID here",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              String groupId = idController.text.trim();
              if (groupId.isNotEmpty && user?.email != null) {
                try {
                  // Adds the current user's email to the members array of that Group ID
                  await FirebaseFirestore.instance
                      .collection('groups')
                      .doc(groupId)
                      .update({
                    'members': FieldValue.arrayUnion([user!.email])
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Joined successfully!"),
                        backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Invalid Group ID or Error: $e"),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }
}
