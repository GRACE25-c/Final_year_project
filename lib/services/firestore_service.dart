import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

// Adds a single category to the user's custom list in their main document
  Future<void> addUserCustomCategory(String uid, String categoryName) async {
    await _db.collection('users').doc(uid).set({
      'customCategories': FieldValue.arrayUnion([categoryName.trim()])
    }, SetOptions(merge: true));
  }
  // --- CATEGORY METHODS ---

  Stream<QuerySnapshot> streamCategories(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .snapshots();
  }

  Future<void> addCustomCategory(
      String uid, String name, int iconCode, int colorValue) async {
    await _db.collection('users').doc(uid).collection('categories').add({
      'name': name,
      'icon': iconCode,
      'color': colorValue,
    });
  }

  Future<void> deleteCategory(String uid, String catId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(catId)
        .delete();
  }

  // --- INDIVIDUAL EXPENSE METHODS ---

  Future<void> addExpense(Expense expense) async {
    await _db.collection('expenses').add({
      'userId': expense.userId,
      'description': expense.description,
      'merchant': expense.merchant,
      'amount': expense.amount,
      'category': expense.category,
      'date': expense.date,
      'fileHash': expense.fileHash, // CRITICAL: Save the fingerprint here
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Expense>> streamUserExpenses(String uid) {
    return _db
        .collection('expenses')
        .where('userId', isEqualTo: uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Expense.fromFirestore(d)).toList());
  }

  Future<void> deleteExpense(String id) async {
    await _db.collection('expenses').doc(id).delete();
  }

  // --- GROUP WALLET METHODS ---

  Future<void> createGroup(
      String groupName, String uid, String creatorName) async {
    DocumentReference groupRef = await _db.collection('groups').add({
      'name': groupName,
      'ownerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [uid], // ID list for Security Rules/Queries
      'members_info': {
        // Store names for display in Member List
        uid: {
          'name': creatorName,
          'role': 'creator',
          'joinedAt': FieldValue.serverTimestamp(),
        }
      }
    });
  }

  Future<void> joinGroup(String groupId, String uid, String name) async {
    await _db.collection('groups').doc(groupId).update({
      // 1. Update the ID list for Security Rules
      'members': FieldValue.arrayUnion([uid]),

      // 2. Add to the members_info MAP using dot notation
      // This ensures 'name' displays in your Member Tab
      'members_info.$uid': {
        'name': name,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      }
    });
  }

  // --- GROUP EXPENSE METHODS ---
// ... other imports and class definition

  Future<void> addGroupExpense(String groupId, Expense expense) async {
    // 1. Generate a document reference first to get the unique ID
    final docRef =
        _db.collection('groups').doc(groupId).collection('expenses').doc();

    // 2. Use copyWith to inject that ID into your expense object
    final expenseWithId = expense.copyWith(id: docRef.id);

    // 3. Save the mapped data to Firestore
    await docRef.set(expenseWithId.toMap());
  }

// Add this for the delete functionality you requested:
  Future<void> deleteGroupExpense(String groupId, String expenseId) async {
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  Stream<List<Expense>> streamGroupExpenses(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Expense.fromMap(doc.data(), doc.id))
            .toList());
  } // <--- Properly closed the stream method here

  Future<void> updateGroupBudget(String groupId, double newLimit) async {
    await _db.collection('groups').doc(groupId).update({
      'budgetLimit': newLimit,
    });
  }

  // --- EXCEL EXPORT ---

  Future<void> exportExpensesToExcel(
      List<Expense> filteredList, String fileName) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Report'];

    // Add Headers
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Category'),
      TextCellValue('Merchant/Description'),
      TextCellValue('Amount'),
    ]);

    for (var e in filteredList) {
      sheet.appendRow([
        TextCellValue(DateFormat('dd-MM-yyyy').format(e.date)),
        TextCellValue(e.category),
        TextCellValue(e.description), // Merchant name usually stored here
        TextCellValue(e.amount.toStringAsFixed(2)),
      ]);
    }

    // Save and Share logic...
    final bytes = excel.encode();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.xlsx');
    await file.writeAsBytes(bytes!);

    await Share.shareXFiles([XFile(file.path)],
        text: 'Expense Report: $fileName');
  }

  Stream<List<String>> streamUserCategories(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data()!.containsKey('customCategories')) {
        return List<String>.from(doc.data()!['customCategories']);
      }
      return [];
    });
  }

  Future<void> deleteGroup(String groupId, String uid, String ownerId) async {
    if (uid != ownerId) {
      throw Exception("Only the group owner can delete this wallet.");
    }
    try {
      await _db.collection('groups').doc(groupId).delete();
    } catch (e) {
      throw Exception("Failed to delete group: $e");
    }
  }
}
