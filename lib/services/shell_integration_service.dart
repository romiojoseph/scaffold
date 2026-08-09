import 'dart:io';

/// Registers an "Open with Scaffold" entry in the Windows folder
/// right-click context menu via HKCU registry keys (no admin needed).
class ShellIntegrationService {
  ShellIntegrationService._();

  static const String _root = r'HKCU\Software\Classes';

  static const List<String> _contexts = [
    r'Directory\shell\Scaffold',
    r'Directory\Background\shell\Scaffold',
    r'Drive\shell\Scaffold',
  ];

  /// The folder placeholder used in the command line:
  /// %1 = folder passed by Explorer, %V = folder window path (background menu).
  static const Map<String, String> _argByContext = {
    r'Directory\shell\Scaffold': '%1',
    r'Directory\Background\shell\Scaffold': '%V',
    r'Drive\shell\Scaffold': '%1',
  };

  static const String _progId = 'Scaffold.JsonFile';
  static const String _jsonBackupValue = 'Scaffold.PreviousJsonAssociation';

  static Future<bool> isInstalled() async {
    final result = await Process.run(
      'reg',
      ['query', '$_root\\Directory\\shell\\Scaffold'],
    );
    return result.exitCode == 0;
  }

  static Future<bool> isJsonDefaultInstalled() async {
    final result = await Process.run(
      'reg',
      ['query', '$_root\\.json', '/ve'],
    );
    return result.exitCode == 0 && result.stdout.toString().contains(_progId);
  }

  static Future<bool> installJsonDefault() async {
    final exePath = Platform.resolvedExecutable;
    final jsonExtKey = '$_root\\.json';
    final progIdKey = '$_root\\$_progId';
    final current = await Process.run('reg', ['query', jsonExtKey, '/ve']);
    if (current.exitCode == 0 && !current.stdout.toString().contains('    $_progId')) {
      final line = current.stdout.toString().split('\n').firstWhere((line) => line.contains('REG_'), orElse: () => '');
      final previous = line.split(RegExp(r'\s{2,}')).last.trim();
      if (previous.isNotEmpty && (await _run('reg', ['add', progIdKey, '/v', _jsonBackupValue, '/d', previous, '/f'])).exitCode != 0) return false;
    }
    
    // Register ProgID
    final commands = <List<String>>[
      ['add', progIdKey, '/ve', '/d', 'JSON File', '/f'],
      ['add', progIdKey, '/v', 'FriendlyTypeName', '/d', 'JSON File', '/f'],
      ['add', '$progIdKey\\DefaultIcon', '/ve', '/d', '"$exePath",0', '/f'],
      [
      'add',
      '$progIdKey\\shell\\open\\command',
      '/ve',
      '/d',
      '"$exePath" "%1"',
      '/f',
      ],
    ];
    for (final command in commands) { if ((await _run('reg', command)).exitCode != 0) return false; }

    // Register .json extension association under HKCU
    if ((await _run('reg', ['add', jsonExtKey, '/ve', '/d', _progId, '/f'])).exitCode != 0) return false;
    if ((await _run('reg', ['add', '$jsonExtKey\\OpenWithProgids', '/v', _progId, '/t', 'REG_NONE', '/f'])).exitCode != 0) return false;
    return true;
  }

  static Future<bool> uninstallJsonDefault() async {
    final jsonExtKey = '$_root\\.json';
    final progIdKey = '$_root\\$_progId';
    final backup = await Process.run('reg', ['query', progIdKey, '/v', _jsonBackupValue]);
    final previous = backup.exitCode == 0 ? backup.stdout.toString().split(RegExp(r'\s{2,}')).last.trim() : '';
    final restore = previous.isNotEmpty
        ? await _run('reg', ['add', jsonExtKey, '/ve', '/d', previous, '/f'])
        : await _run('reg', ['delete', jsonExtKey, '/ve', '/f']);
    if (restore.exitCode != 0) return false;
    final openWith = await _run('reg', ['delete', '$jsonExtKey\\OpenWithProgids', '/v', _progId, '/f']);
    final progId = await _run('reg', ['delete', progIdKey, '/f']);
    return openWith.exitCode == 0 && progId.exitCode == 0;
  }

  static Future<void> install() async {
    final exePath = Platform.resolvedExecutable;
    for (final context in _contexts) {
      final key = '$_root\\$context';
      await _run('reg', ['add', key, '/ve', '/d', 'Open with Scaffold', '/f']);
      await _run('reg', ['add', key, '/v', 'Icon', '/d', exePath, '/f']);
      await _run('reg', [
        'add',
        '$key\\command',
        '/ve',
        '/d',
        '"$exePath" "${_argByContext[context]}"',
        '/f',
      ]);
    }
  }

  static Future<void> uninstall() async {
    for (final context in _contexts) {
      await _run('reg', ['delete', '$_root\\$context', '/f']);
    }
  }

  static Future<ProcessResult> _run(String executable, List<String> args) {
    return Process.run(executable, args);
  }
}
