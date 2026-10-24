import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// This is a simple Data Model to hold the results
class OCRResult {
  final String text;
  final double? amount;
  final DateTime? date;
  final String? merchant;

  OCRResult({required this.text, this.amount, this.date, this.merchant});
}

class OCRService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  // The main method your GroupDetailScreen is looking for
  Future<Map<String, dynamic>?> scanReceipt(XFile xFile) async {
    try {
      final file = File(xFile.path);
      final inputImage = InputImage.fromFile(file);

      // 1. Perform OCR
      final RecognizedText recognizedText =
          await _recognizer.processImage(inputImage);
      final String fullText = recognizedText.text;

      // 2. Extract Data
      final amount = _extractAmount(fullText);
      final merchant = _extractMerchant(fullText);

      // 3. Return as a Map so it matches your GroupDetailScreen logic: result['amount']
      return {
        'amount': amount,
        'merchant': merchant,
        'text': fullText,
      };
    } catch (e) {
      print("OCR Error: $e");
      return null;
    }
  }

  double? _extractAmount(String t) {
    // Regex to find numbers that look like currency (e.g., 10.50 or 1,000.00)
    final reg = RegExp(r"\b\d{1,3}(?:[,\s]\d{3})*(?:[\.,]\d{2})\b");
    final matches = reg.allMatches(t);
    if (matches.isEmpty) return null;

    double? largest;
    for (final m in matches) {
      String value = m.group(0)!.replaceAll(',', '').replaceAll(' ', '');
      final parsed = double.tryParse(value);
      if (parsed != null) {
        if (largest == null || parsed > largest) {
          largest = parsed;
        }
      }
    }
    return largest;
  }

  String? _extractMerchant(String text) {
    final lines = text.split('\n');
    for (String line in lines) {
      String trimmed = line.trim();
      // Usually, the first non-empty line with letters is the merchant name
      if (trimmed.isNotEmpty &&
          trimmed.length > 2 &&
          RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
        return trimmed;
      }
    }
    return null;
  }

  void dispose() {
    _recognizer.close();
  }
}
