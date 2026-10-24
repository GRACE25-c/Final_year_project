import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Expense {
  final String id;
  final String userId;
  final String merchant;
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final String? fileHash;
  final String type;
  final String imageUrl;
  final String? groupId;

  Expense({
    required this.id,
    required this.userId,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    this.fileHash,
    this.type = 'Expense',
    this.imageUrl = '',
    this.groupId,
  });

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'rent':
        return Icons.home;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'health':
        return Icons.medical_services;
      case 'salary':
        return Icons.payments;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.category;
    }
  }

  bool get hasDescription => description.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'merchant': merchant,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'description': description.trim(),
      'type': type,
      'imageUrl': imageUrl,
      'groupId': groupId,
      'fileHash': fileHash,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> data, String id) {
    return Expense(
      id: id,
      userId: data['userId'] ?? '',
      merchant: data['merchant'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? 'Other',
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      description: (data['description']?.toString()) ?? '',
      type: data['type'] ?? 'Expense',
      imageUrl: data['imageUrl'] ?? '',
      groupId: data['groupId'],
      fileHash: data['fileHash'],
    );
  }

  Expense copyWith({
    String? id,
    String? userId,
    String? merchant,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
    String? fileHash,
    String? type,
    String? imageUrl,
    String? groupId,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      description: description ?? this.description,
      fileHash: fileHash ?? this.fileHash,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      groupId: groupId ?? this.groupId,
    );
  }

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Expense.fromMap(data, doc.id);
  }
}
