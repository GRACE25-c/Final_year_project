import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/expense.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptScannerScreen extends StatefulWidget {
  final ImageSource source;
  final String? groupId;
  const ReceiptScannerScreen({super.key, required this.source, this.groupId});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  String? _fileHash;
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  String? _selectedCategory;
  File? _selectedImage;
  bool _isScanning = false;

  // These act as the base defaults
  final List<String> _defaultCategories = [
    'Food & Drinks',
    'Transport',
    'Shopping',
    'Bills',
    'Entertainment',
    'Other'
  ];

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processBill(widget.source);
    });
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  Future<void> _processBill(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) {
      if (_selectedImage == null) Navigator.pop(context);
      return;
    }

    final bytes = await pickedFile.readAsBytes();
    final String fileHash = sha256.convert(bytes).toString();

    setState(() {
      _selectedImage = File(pickedFile.path);
      _fileHash = fileHash;
      _isScanning = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      RegExp amountRegExp = RegExp(r'(\d+[\.,]\d{2})');
      String detectedAmount = "";

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final match = amountRegExp.firstMatch(line.text);
          if (match != null) {
            detectedAmount = match.group(0)!.replaceAll(',', '.');
          }
        }
      }

      if (recognizedText.blocks.isNotEmpty &&
          recognizedText.blocks.first.lines.isNotEmpty) {
        _descriptionController.text =
            recognizedText.blocks.first.lines.first.text;
      }

      // --- UPDATED: Smart Category Keyword Logic ---
      String textToScan = recognizedText.text.toLowerCase();
      String category = 'Other';

      // 1. Check Standard Keywords
      if (textToScan.contains('restaur') ||
          textToScan.contains('cafe') ||
          textToScan.contains('food')) {
        category = 'Food & Drinks';
      } else if (textToScan.contains('uber') ||
          textToScan.contains('fuel') ||
          textToScan.contains('petrol')) {
        category = 'Transport';
      } else if (textToScan.contains('market') ||
          textToScan.contains('store') ||
          textToScan.contains('mart')) {
        category = 'Shopping';
      }

      // 2. NEW: Check against User's Custom Categories (like "Health")
      final userUid = FirebaseAuth.instance.currentUser?.uid;
      if (userUid != null) {
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userUid)
            .get();
        if (userDoc.exists && userDoc.data()!.containsKey('customCategories')) {
          List<String> customs =
              List<String>.from(userDoc.data()!['customCategories']);
          for (var customName in customs) {
            if (textToScan.contains(customName.toLowerCase())) {
              category = customName;
              break;
            }
          }
        }
      }

      setState(() {
        _amountController.text = detectedAmount;
        _selectedCategory = category;
        _isScanning = false;
      });
    } catch (e) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error scanning: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.groupId != null ? "Verify Group Receipt" : "Verify Receipt"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      // --- UPDATED: Wrapped Body in StreamBuilder for Dynamic Categories ---
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          List<String> dynamicCategories = List.from(_defaultCategories);

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            if (data.containsKey('customCategories')) {
              List<String> customs =
                  List<String>.from(data['customCategories']);
              // Insert custom categories before "Other"
              dynamicCategories.insertAll(
                  dynamicCategories.length - 1, customs);
            }
          }
          dynamicCategories = dynamicCategories.toSet().toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _processBill(ImageSource.gallery),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.indigo.withOpacity(0.1)),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(_selectedImage!,
                                fit: BoxFit.contain))
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  size: 50, color: Colors.indigo),
                              SizedBox(height: 10),
                              Text("Change Image",
                                  style: TextStyle(color: Colors.indigo)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 20),
                if (_isScanning)
                  const LinearProgressIndicator(color: Colors.indigo),
                const SizedBox(height: 20),

                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                      labelText: "Total Amount",
                      prefixText: "₹ ",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)))),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 15),

                // --- UPDATED: Dynamic Dropdown ---
                DropdownButtonFormField<String>(
                  initialValue: dynamicCategories.contains(_selectedCategory)
                      ? _selectedCategory
                      : dynamicCategories.first,
                  decoration: const InputDecoration(
                      labelText: "Category",
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)))),
                  items: dynamicCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                      labelText: "Date",
                      suffixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)))),
                  readOnly: true,
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now());
                    if (pickedDate != null) {
                      setState(() => _dateController.text =
                          DateFormat('dd/MM/yyyy').format(pickedDate));
                    }
                  },
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                      labelText: "Description / Store",
                      hintText: "e.g. Starbucks",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)))),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      // 1. Basic validation - do this before anything else
                      if (_amountController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Please enter amount")));
                        return;
                      }

                      // 2. CAPTURE SENSITIVE DATA: Context-related objects must be saved
                      // into local variables before we pop the screen.
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return;

                      // Capture current state values
                      final amountVal =
                          double.tryParse(_amountController.text) ?? 0.0;
                      final merchantVal = _descriptionController.text.trim();
                      final dateVal = _dateController.text;
                      final categoryVal = _selectedCategory ?? 'Other';
                      final hashVal = _fileHash;

                      // 3. POP IMMEDIATELY: This stops the "Not Responding" error
                      // by giving control back to the System UI.
                      navigator.pop();

                      // 4. BACKGROUND WORK: Everything from here on uses local variables.
                      try {
                        // DUPLICATE CHECK
                        Query query;
                        if (widget.groupId != null) {
                          query = FirebaseFirestore.instance
                              .collection('groups')
                              .doc(widget.groupId)
                              .collection('expenses')
                              .where('fileHash', isEqualTo: hashVal);
                        } else {
                          query = FirebaseFirestore.instance
                              .collection('expenses')
                              .where('userId', isEqualTo: uid)
                              .where('fileHash', isEqualTo: hashVal);
                        }

                        final querySnapshot = await query.get();
                        if (querySnapshot.docs.isNotEmpty) {
                          messenger.showSnackBar(const SnackBar(
                            backgroundColor: Colors.orange,
                            content:
                                Text("Receipt already exists. Skipping save."),
                          ));
                          return;
                        }

                        // SAVE EXPENSE
                        Expense newExpense = Expense(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          userId: uid,
                          merchant: merchantVal.isEmpty
                              ? "Unknown Store"
                              : merchantVal,
                          amount: -amountVal,
                          category: categoryVal,
                          date: DateFormat('dd/MM/yyyy').parse(dateVal),
                          description: merchantVal,
                          type: 'Expense',
                          imageUrl: '',
                          fileHash: hashVal,
                        );

                        if (widget.groupId != null) {
                          await FirestoreService()
                              .addGroupExpense(widget.groupId!, newExpense);
                        } else {
                          await FirestoreService().addExpense(newExpense);
                        }

                        messenger.showSnackBar(const SnackBar(
                            backgroundColor: Colors.green,
                            content: Text("Receipt saved successfully!")));
                      } catch (e) {
                        debugPrint("Background process error: $e");
                        messenger.showSnackBar(SnackBar(
                            backgroundColor: Colors.red,
                            content: Text("Error: $e")));
                      }
                    },
                    child: const Text("Confirm & Save",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _amountController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
