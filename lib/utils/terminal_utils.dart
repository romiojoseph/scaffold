import 'dart:io';

class TerminalInfo {
  final String executable;
  final List<String> args;
  const TerminalInfo(this.executable, this.args);

  List<String> argsFor(String path) => [...args, path];
}

Future<TerminalInfo> detectDefaultTerminal() async {
  // Check for Windows Terminal first (most common default).
  final wtPath = await findWindowsTerminal();
  if (wtPath != null) {
    return TerminalInfo(wtPath, ['-d']);
  }

  // Check registry for delegation setting.
  final result = await Process.run('reg', [
    'query',
    r'HKCU\Console',
    '/v',
    'DelegationTerminal',
  ]);
  if (result.exitCode == 0) {
    final output = result.stdout.toString();
    if (output.contains('{E12CFF52-A429-4CEC-B159-25F7522982BC}')) {
      final wt = await findWindowsTerminal();
      if (wt != null) return TerminalInfo(wt, ['-d']);
    }
  }

  // Fallback: cmd.exe with cd.
  return TerminalInfo('cmd.exe', [
    '/c',
    'start',
    'cmd.exe',
    '/k',
    'cd',
    '/d',
  ]);
}

Future<String?> findWindowsTerminal() async {
  // Try PATH first.
  final which = await Process.run('where', ['wt.exe']);
  if (which.exitCode == 0) {
    final lines = which.stdout.toString().trim().split('\n');
    if (lines.isNotEmpty) return lines.first.trim();
  }

  // Try known Store location.
  final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
  if (localAppData.isNotEmpty) {
    final storeDir = Directory('$localAppData\\Microsoft\\WindowsApps');
    if (await storeDir.exists()) {
      await for (final entity in storeDir.list()) {
        if (entity.path.toLowerCase().contains('windowsterminal') &&
            entity.path.toLowerCase().endsWith('.exe')) {
          return entity.path;
        }
      }
    }
  }

  return null;
}