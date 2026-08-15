import 'dart:io';
import 'package:flutter/services.dart';

class ClipboardUtils {
  ClipboardUtils._();

  /// Safely copies text to the system clipboard, retrying if Windows clipboard is temporarily locked.
  static Future<bool> copy(String text, {int maxAttempts = 5}) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await Clipboard.setData(ClipboardData(text: text));
        return true;
      } catch (_) {
        if (attempt == maxAttempts - 1) {
          // Fallback on Windows if native clipboard API failed: powershell / clip
          if (Platform.isWindows) {
            try {
              final process = await Process.start('clip', []);
              process.stdin.write(text);
              await process.stdin.close();
              final exitCode = await process.exitCode;
              if (exitCode == 0) return true;
            } catch (_) {}
          }
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 60));
      }
    }
    return false;
  }
}
