import 'dart:typed_data';
import 'package:hf_tokenizers/hf_tokenizers.dart' as hf;

class BpeTokenizer {
  final String name;
  final hf.Tokenizer _tokenizer;

  BpeTokenizer._(this.name, this._tokenizer);

  /// Load BpeTokenizer from JSON bytes via hf_tokenizers FFI
  static BpeTokenizer fromBytes(Uint8List bytes, String name) {
    final tk = hf.Tokenizer.fromBytes(bytes);
    return BpeTokenizer._(name, tk);
  }

  /// Returns exact token count matching HuggingFace reference implementation
  int countTokens(String text) {
    if (text.isEmpty) return 0;
    try {
      final ids = _tokenizer.encode(text, addSpecialTokens: false);
      return ids.length;
    } catch (_) {
      return 0;
    }
  }

  void dispose() {
    _tokenizer.close();
  }
}
