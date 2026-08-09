import 'package:flutter/services.dart';
import 'bpe_tokenizer.dart';

class TokenizerRegistry {
  BpeTokenizer? _tokenizer;

  /// Loads single tokenizer asset asynchronously
  Future<BpeTokenizer?> getTokenizer() async {
    if (_tokenizer != null) return _tokenizer;

    try {
      final byteData = await rootBundle.load('assets/third_party/tokenizer/tokenizer.json');
      final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      _tokenizer = BpeTokenizer.fromBytes(bytes, 'Default');
      return _tokenizer;
    } catch (_) {
      return null;
    }
  }
}
