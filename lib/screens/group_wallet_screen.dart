import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_detail_screen.dart';
import 'scan_screen.dart'; // Make sure to import your scanner file
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

class GroupWalletScreen extends StatefulWidget {
  const GroupWalletScreen({super.key});

  @override
  State<GroupWalletScreen> createState() => _GroupWalletScreenState();
}

class _GroupWalletScreenState extends State<GroupWalletScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _joinIdController = TextEditingController();
  final TextEditingController _joinNameController = TextEditingController();
  final TextEditingController _createNameController = TextEditingController();
  bool _isProcessing = false;

  Widget _buildAnalysisItem(String title, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(amount,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Wrap(
        children: [
          const Padding(
            padding: EdgeInsets.all(15.0),
            child: Text("Scan Receipt",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.indigo),
            title: const Text('Take a Photo'),
            onTap: () {
              Navigator.pop(context);
              _navigateToScanner(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.indigo),
            title: const Text('Upload from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _navigateToScanner(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _navigateToScanner(ImageSource source) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptScannerScreen(source: source),
      ),
    );
  }

  void _showCreateGroupDialog(FirestoreService fs, String uid) {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Create Shared Wallet"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  hintText: "Enter Group Name (e.g. Roommates)",
                  labelText: "Group Name",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _createNameController,
                decoration: const InputDecoration(
                  hintText: "Enter Your Name",
                  labelText: "Your Display Name",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  _isProcessing ? null : () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : () async {
                      String gName = _groupNameController.text.trim();
                      String creatorName = _createNameController.text.trim();

                      if (gName.isNotEmpty && creatorName.isNotEmpty) {
                        setDialogState(() => _isProcessing = true);
                        try {
                          // Pass both the Group Name AND the Creator Name to your service
                          await fs.createGroup(gName, uid, creatorName);

                          _groupNameController.clear();
                          _createNameController.clear();
                          if (mounted) Navigator.pop(dialogContext);
                        } catch (e) {
                          print("Error creating group: $e");
                        } finally {
                          setDialogState(() => _isProcessing = false);
                        }
                      }
                    },
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinGroupDialog(FirestoreService fs, String uid) {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Join Shared Wallet"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _joinIdController,
                decoration:
                    const InputDecoration(hintText: "Paste Group ID here"),
              ),
              const SizedBox(height: 16),
              // 2. ADD THIS NEW TEXTFIELD
              TextField(
                controller: _joinNameController,
                decoration: const InputDecoration(hintText: "Enter your name"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                // 3. Ensure BOTH values are pulled
                String groupId = _joinIdController.text.trim();
                String name = _joinNameController.text.trim();

                if (groupId.isNotEmpty && name.isNotEmpty) {
                  try {
                    // 4. Pass all 3 required arguments
                    await fs.joinGroup(groupId, uid, name);
                    Navigator.pop(dialogContext);
                  } catch (e) {
                    print("Error joining: $e");
                  }
                }
              },
              child: const Text("Join"),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteGroup(String groupId, String name, FirestoreService fs,
      String uid, String ownerId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Group?"),
        content: Text(
            "Are you sure you want to delete '$name'? This will remove the shared wallet for all members."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              try {
                await fs.deleteGroup(groupId, uid, ownerId);
                if (!mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Group '$name' deleted.")));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")));
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final fs = FirestoreService();
    final String uid = auth.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Shared Wallets",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
            const Text("Manage expenses with friends or family",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: _buildActionButton(
                        icon: Icons.add_circle_outline,
                        label: "Create",
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () => _showCreateGroupDialog(fs, uid))),
                const SizedBox(width: 15),
                Expanded(
                    child: _buildActionButton(
                        icon: Icons.group_add_outlined,
                        label: "Join",
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () => _showJoinGroupDialog(fs, uid))),
              ],
            ),
            const SizedBox(height: 30),
            const Text("Your Groups",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .where('members', arrayContains: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_outlined,
                              size: 80, color: Colors.grey[300]),
                          const Text("No active groups found",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var group = snapshot.data!.docs[index];
                      String groupId = group.id;
                      String groupName = group['name'] ?? "No Name";
                      String ownerId = group['ownerId'] ?? "";
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child:
                                  const Icon(Icons.group, color: Colors.white)),
                          title: Text(groupName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Row(
                            children: [
                              Text("ID: $groupId",
                                  style: const TextStyle(fontSize: 10)),
                              const SizedBox(width: 8),
                              // --- NEW: Copy ID Button ---
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                      ClipboardData(text: groupId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text("ID for '$groupName' copied!"),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  );
                                },
                                child: Icon(Icons.copy,
                                    size: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.7)),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (ownerId == uid)
                                IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent),
                                    onPressed: () => _confirmDeleteGroup(
                                        groupId, groupName, fs, uid, ownerId)),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => GroupDetailScreen(
                                      groupId: groupId, groupName: groupName))),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
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
    );
  }
}
