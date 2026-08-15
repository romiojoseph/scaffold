import 'dart:io';

class UrlUtils {
  UrlUtils._();

  /// Opens a URL in the system browser, returning false if it could not be
  /// opened so callers can fall back to copying the link.
  static Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }

    try {
      if (Platform.isWindows) {
        await Process.run('cmd.exe', ['/c', 'start', '', url]);
      } else {
        await Process.run('open', [url]);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}