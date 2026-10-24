import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _merchant = TextEditingController();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final DateTime _date = DateTime.now();

  String _category = 'Other';
  String _transactionType = 'Expense';
  File? _selectedImage;
  bool _saving = false;
  bool _isProcessing = false;

  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _desc.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // --- LOGIC METHODS ---

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndProcessImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndProcessImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _isProcessing = true;
        });
        await _processImageWithMLKit(pickedFile.path);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _processImageWithMLKit(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final lines = recognizedText.text.split('\n');

      String detectedAmount = "";
      RegExp amountRegExp = RegExp(r'(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})');

      for (String line in lines) {
        final match = amountRegExp.firstMatch(line);
        if (match != null) {
          detectedAmount = match.group(0)!.replaceAll(',', '');
        }
      }

      setState(() {
        _isProcessing = false;
        if (lines.isNotEmpty) {
          _merchant.text = lines[0];
          _desc.text = "Scanned from receipt";
        }
        if (detectedAmount.isNotEmpty) _amount.text = detectedAmount;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('ML Kit Error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _saveExpense() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final fs = FirestoreService();

    // 1. Validation (Trimmed to catch "space-only" inputs)
    if (_merchant.text.trim().isEmpty || _amount.text.trim().isEmpty) {
      _showError("Please fill Merchant and Amount");
      return;
    }

    // 2. Auth Guard
    final user = auth.currentUser;
    if (user == null) {
      _showError("User session expired. Please log in again.");
      return;
    }

    setState(() => _saving = true);

    try {
      String cleanAmount = _amount.text.replaceAll(RegExp(r'[^\d.]'), '');
      double parsedAmount = double.tryParse(cleanAmount) ?? 0.0;

      final entry = Expense(
        id: '',
        userId: user.uid,
        merchant: _merchant.text.trim(),
        amount: parsedAmount,
        category: _category,
        date: _date,
        description: _desc.text.trim(),
        type: _transactionType,
        imageUrl: '',
      );

      await fs.addExpense(entry);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Save failed: ${e.toString()}');
      }
    }
  }

  // --- UI DIALOGS ---
  void _showAddCategoryDialog() {
    final catNameController = TextEditingController();
    final fs = FirestoreService();
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser!.uid;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Manage Categories"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: catNameController,
                decoration: InputDecoration(
                  hintText: "New Category Name",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: () async {
                      if (catNameController.text.isNotEmpty) {
                        await fs.addCustomCategory(
                          uid,
                          catNameController.text,
                          Icons.category.codePoint,
                          Colors.blue.value,
                        );
                        catNameController.clear();
                      }
                    },
                  ),
                ),
              ),
              const Divider(height: 30),
              Flexible(
                child: StreamBuilder<QuerySnapshot>(
                  stream: fs.streamCategories(uid),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var docs = snapshot.data!.docs;
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index];
                        return ListTile(
                          dense: true,
                          title: Text(data['name']),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () async {
                              await fs.deleteCategory(uid, data.id);
                            },
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final fs = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: Text('Add $_transactionType')),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Scanning Receipt...")
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // --- IMAGE PREVIEW ---
                  if (_selectedImage != null)
                    Container(
                      height: 150,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  // --- CAPTURE BOX ---
                  GestureDetector(
                    onTap: _showPickerOptions,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border:
                            Border.all(color: Colors.blue.shade200, width: 2),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedImage == null
                                ? Icons.receipt_long
                                : Icons.check_circle,
                            size: 40,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedImage == null
                                ? "Capture Receipt"
                                : "Receipt Added",
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (_selectedImage == null)
                            const Text(
                              "Scan bill from camera or gallery",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'Expense',
                        label: Text('Expense'),
                        icon: Icon(Icons.remove_circle_outline),
                      ),
                      ButtonSegment(
                        value: 'Income',
                        label: Text('Income'),
                        icon: Icon(Icons.add_circle_outline),
                      ),
                    ],
                    selected: {_transactionType},
                    onSelectionChanged: (set) =>
                        setState(() => _transactionType = set.first),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _merchant,
                    decoration: const InputDecoration(
                        labelText: 'Merchant', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amount,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  // --- Add this below the Amount TextField ---
                  const SizedBox(height: 16),
                  TextField(
                    controller:
                        _desc, // This connects the input to your _desc variable
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'e.g. Lunch with friends',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: fs.streamCategories(auth.currentUser!.uid),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const LinearProgressIndicator();
                            }
                            var docs = snapshot.data!.docs;
                            bool exists =
                                docs.any((d) => d['name'] == _category);
                            return DropdownButtonFormField<String>(
                              initialValue: exists
                                  ? _category
                                  : (docs.isNotEmpty
                                      ? docs.first['name'].toString()
                                      : null),
                              onChanged: (v) {
                                if (v != null) setState(() => _category = v);
                              },
                              hint: const Text("Select Category"),
                              items: docs.map((doc) {
                                return DropdownMenuItem(
                                  value: doc['name'].toString(),
                                  child: Text(doc['name'].toString()),
                                );
                              }).toList(),
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder()),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.blue),
                        onPressed: _showAddCategoryDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_saving ? "Saving..." : "Confirm & Save"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
