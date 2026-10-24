import 'dart:io';
import 'package:crypto/crypto.dart'; // Add this import
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BillScannerService {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, String>?> scanBill({required ImageSource source}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return null;

    // --- NEW: DUPLICATE DETECTION LAYER ---
    final File imageFile = File(image.path);
    final bytes = await imageFile.readAsBytes();
    final String fileHash =
        sha256.convert(bytes).toString(); // Digital Fingerprint

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Check if this specific file hash already exists for this user
      final duplicateQuery = await _db
          .collection('receipts')
          .where('userId', isEqualTo: uid) // Corrected syntax
          .where('fileHash', isEqualTo: fileHash) // Corrected syntax
          .get();
      if (duplicateQuery.docs.isNotEmpty) {
        // You could also throw a custom error here to catch in your UI
        print("Duplicate file detected. Skipping OCR.");
        return {'error': 'duplicate'};
      }
    }
    // ---------------------------------------

    final inputImage = InputImage.fromFilePath(image.path);
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);

    String total = "";
    String date = "";
    String merchant = "";
    String category = "General";

    final RegExp priceRegex = RegExp(r'(\d+\.\d{2})');
    final RegExp dateRegex =
        RegExp(r'(\d{2}/\d{2}/\d{4}|\d{2}-\d{2}-\d{4}|\d{4}/\d{2}/\d{2})');

    if (recognizedText.blocks.isNotEmpty &&
        recognizedText.blocks[0].lines.isNotEmpty) {
      merchant = recognizedText.blocks[0].lines[0].text;
    }

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String text = line.text;

        if (text.toLowerCase().contains('total') ||
            text.toLowerCase().contains('amt')) {
          final match = priceRegex.firstMatch(text);
          if (match != null) total = match.group(0)!;
        }

        if (dateRegex.hasMatch(text)) {
          date = dateRegex.firstMatch(text)!.group(0)!;
        }
      }
    }

    category = _inferCategory(merchant);

    return {
      'total': total,
      'date': date,
      'merchant': merchant,
      'category': category,
      'imagePath': image.path,
      'fileHash': fileHash, // Return the hash so your UI/Save logic can use it
    };
  }

  String _inferCategory(String merchantName) {
    String name = merchantName.toLowerCase();
    if (name.contains('starbucks') ||
        name.contains('kfc') ||
        name.contains('food')) {
      return "Food & Drink";
    }
    if (name.contains('uber') ||
        name.contains('shell') ||
        name.contains('fuel')) {
      return "Transport";
    }
    if (name.contains('amazon') || name.contains('walmart')) return "Shopping";
    return "General";
  }

  void dispose() => _textRecognizer.close();
}
