import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/exclusions_config.dart';
import '../models/thresholds_config.dart';
import '../services/tokenizer_registry.dart';
import '../models/fs_node.dart';
import '../models/scan_stats.dart';
import '../services/scanner_service.dart';
import '../theme/app_colors.dart';
import '../utils/terminal_utils.dart';
import '../widgets/ascii_view.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/export_dialog.dart';
import '../widgets/header_bar.dart';
import '../widgets/node_detail_drawer.dart';
import '../widgets/path_history_drawer.dart';
import '../widgets/snapshot_diff_dialog.dart';
import '../widgets/stats_view.dart';
import '../widgets/git_history_view.dart';
import '../widgets/dependencies_view.dart';
import 'global_dependencies_screen.dart';
import 'file_hash_screen.dart';
import '../widgets/tree_view.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/home/empty_state_view.dart';
import '../widgets/home/exclusions_banner.dart';
import '../widgets/home/main_tab_bar.dart';
import '../widgets/home/scan_progress_banner.dart';
import '../widgets/viewers/file_viewer_page.dart';

class HomeScreen extends StatefulWidget {
  final List<String> initialArgs;
  const HomeScreen({super.key, this.initialArgs = const []});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _pathController = TextEditingController();
  late TabController _tabController;

  ExclusionsConfig _exclusionsConfig = ExclusionsConfig.defaults();
  ThresholdsConfig _thresholdsConfig = ThresholdsConfig.defaults();
  final TokenizerRegistry _tokenizerRegistry = TokenizerRegistry();
  List<FsNode> _scanResults = [];
  ScanStats? _stats;
  ScanTotals? _scanTotals;
  String _asciiOutput = '';
  bool _isScanning = false;
  ScanProgress? _scanProgress;
  String? _errorMessage;
  FsNode? _selectedNode;
  late File _configFile;
  late File _thresholdsConfigFile;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<String> _pathHistory = [];
  File? _historyFile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _pathController.text = Directory.current.path;
    _loadConfigs();
    _loadPathHistory();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handleCommandLineArgs(),
    );
  }

  Future<void> _handleCommandLineArgs() async {
    final allCandidates = [
      ...widget.initialArgs,
      ...Platform.executableArguments,
    ];

    String? target;
    for (final arg in allCandidates) {
      final trimmed = arg.trim();
      if (trimmed.isEmpty || trimmed.startsWith('-')) continue;
      if (File(trimmed).existsSync() || Directory(trimmed).existsSync()) {
        target = trimmed;
        break;
      }
    }

    final currentDir = Directory.current.path;
    final isSystem32 = currentDir.toLowerCase().contains(r'system32');

    if (target != null && File(target).existsSync()) {
      final file = File(target);
      final stat = await file.stat();
      final name = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : target;
      final ext = name.contains('.') ? '.${name.split('.').last}' : '';
      final node = FsNode(
        name: name,
        type: 'File',
        path: file.absolute.path,
        size: stat.size,
        sizeFormatted: FsNode.formatBytes(stat.size),
        extension: ext,
        lastModified: stat.modified,
      );
      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => FileViewerPage(node: node)));
      }
    } else if (target != null && Directory(target).existsSync()) {
      _pathController.text = Directory(target).absolute.path;
      await _startScan();
    } else if (isSystem32) {
      _pathController.text = '';
    }
  }

  Future<void> _loadConfigs() async {
    final dir = await getApplicationSupportDirectory();
    _configFile = File('${dir.path}${Platform.pathSeparator}exclusions.json');
    _thresholdsConfigFile = File(
      '${dir.path}${Platform.pathSeparator}thresholds.json',
    );

    final cfg = await ExclusionsConfig.loadFromFile(_configFile);
    final thresholdsCfg = await ThresholdsConfig.loadFromFile(
      _thresholdsConfigFile,
    );

    setState(() {
      _exclusionsConfig = cfg;
      _thresholdsConfig = thresholdsCfg;
    });
  }

  Future<void> _saveExclusions(ExclusionsConfig newConfig) async {
    await newConfig.saveToFile(_configFile);
    setState(() => _exclusionsConfig = newConfig);
    if (_scanResults.isNotEmpty) {
      _startScan();
    }
  }

  Future<void> _saveThresholds(ThresholdsConfig newConfig) async {
    await newConfig.saveToFile(_thresholdsConfigFile);
    setState(() => _thresholdsConfig = newConfig);
  }

  Future<void> _loadPathHistory() async {
    final dir = await getApplicationSupportDirectory();
    _historyFile = File(
      '${dir.path}${Platform.pathSeparator}path_history.json',
    );
    try {
      if (await _historyFile!.exists()) {
        final content = await _historyFile!.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is List) {
          final loaded = decoded
              .whereType<String>()
              .where((p) => p.length <= 1024 && Directory(p).existsSync())
              .take(50)
              .toList();
          setState(() => _pathHistory = loaded);
        }
      }
    } catch (_) {}
  }

  Future<void> _persistPathHistory() async {
    try {
      final file = _historyFile;
      if (file == null) return;
      await file.writeAsString(jsonEncode(_pathHistory));
    } catch (_) {}
  }

  void _savePathToHistory(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _pathHistory.remove(trimmed);
      _pathHistory.insert(0, trimmed);
      if (_pathHistory.length > 50) {
        _pathHistory = _pathHistory.sublist(0, 50);
      }
    });
    _persistPathHistory();
  }

  void _removePathFromHistory(int index) {
    if (index < 0 || index >= _pathHistory.length) return;
    setState(() {
      _pathHistory.removeAt(index);
    });
    _persistPathHistory();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  ScannerService? _currentScanner;

  Future<void> _startScan() async {
    final targetPath = _pathController.text.trim();
    if (targetPath.isEmpty) return;

    if (_exclusionsConfig.gitignoreOnly) {
      final gitignoreFile = File(
        '$targetPath${Platform.pathSeparator}.gitignore',
      );
      if (!await gitignoreFile.exists()) {
        setState(() {
          _exclusionsConfig = ExclusionsConfig(
            patterns: _exclusionsConfig.patterns,
            enabled: _exclusionsConfig.enabled,
            gitignoreOnly: false,
          );
        });
        // Persist directly — calling _saveExclusions would re-trigger _startScan
        await _exclusionsConfig.saveToFile(_configFile);
        if (mounted) {
          AppToast.showWarning(
            context,
            'No .gitignore file found in target directory. "Scan based on .gitignore" has been automatically turned off.',
          );
        }
      }
    }

    final scanner = ScannerService(exclusionsConfig: _exclusionsConfig);
    _currentScanner = scanner;

    setState(() {
      _isScanning = true;
      _scanProgress = const ScanProgress(
        stage: ScanStage.initializing,
        message: 'Initializing scan...',
      );
      _errorMessage = null;
      _selectedNode = null;
    });

    try {
      final result = await scanner.scanDirectoryInIsolate(
        targetPath,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _scanProgress = progress);
          }
        },
      );
      final results = result.nodes;
      final stats = ScanStats.fromNodes(result.nodes);

      final buffer = StringBuffer();
      buffer.writeln('.');
      for (int i = 0; i < results.length; i++) {
        final child = results[i];
        final isLast = i == results.length - 1;
        final branch = isLast ? '└── ' : '├── ';
        final ext = isLast ? '    ' : '│   ';
        buffer.writeln('$branch${child.name}');
        if (child.isDirectory) {
          buffer.write(child.toAsciiTree(prefix: ext));
        }
      }

      if (mounted) {
        setState(() {
          _scanResults = results;
          _scanTotals = result.totals;
          _stats = stats;
          _asciiOutput = buffer.toString();
          _isScanning = false;
          _scanProgress = null;
          _currentScanner = null;
        });
        _savePathToHistory(targetPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isScanning = false;
          _scanProgress = null;
          _currentScanner = null;
        });
      }
    }
  }

  void _cancelScan() {
    _currentScanner?.cancelScan();
    setState(() {
      _isScanning = false;
      _scanProgress = null;
      _currentScanner = null;
      _errorMessage = 'Scan was cancelled by user.';
    });
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        config: _exclusionsConfig,
        thresholdsConfig: _thresholdsConfig,
        onSave: _saveExclusions,
        onSaveThresholds: _saveThresholds,
      ),
    );
  }

  void _openExportDialog() {
    showDialog(
      context: context,
      builder: (_) => ExportDialog(
        rootPath: _pathController.text.trim(),
        excludedPatterns: _exclusionsConfig.patterns,
        structure: _scanResults,
      ),
    );
  }

  void _openCompareDialog() {
    showDialog(
      context: context,
      builder: (_) => SnapshotDiffDialog(currentNodes: _scanResults),
    );
  }

  void _showSnack(String message) {
    AppToast.showInfo(context, message);
  }

  Future<void> _openTerminal() async {
    final targetPath = _pathController.text.trim();
    if (targetPath.isEmpty) {
      _showSnack('Enter a directory path first.');
      return;
    }
    if (!Directory(targetPath).existsSync()) {
      _showSnack('Directory does not exist: $targetPath');
      return;
    }
    try {
      final canonicalPath = await Directory(targetPath).resolveSymbolicLinks();
      final terminal = await detectDefaultTerminal();
      final args = terminal.argsFor(canonicalPath);
      await Process.start(
        terminal.executable,
        args,
        workingDirectory: canonicalPath,
      );
    } catch (e) {
      _showSnack('Failed to open terminal: $e');
    }
  }

  Future<void> _openExplorer() async {
    final targetPath = _pathController.text.trim();
    final pathToOpen =
        (targetPath.isNotEmpty && Directory(targetPath).existsSync())
        ? targetPath
        : Directory.current.path;
    try {
      await Process.run('explorer.exe', [pathToOpen]);
    } catch (e) {
      _showSnack('Failed to open Explorer: $e');
    }
  }

  Future<void> _openFileFromSystem() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select JSON File to View',
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final stat = await file.stat();
      final name = file.path.split(Platform.pathSeparator).last;
      final ext = name.contains('.') ? '.${name.split('.').last}' : '';

      final node = FsNode(
        name: name,
        type: 'File',
        path: file.path,
        size: stat.size,
        sizeFormatted: FsNode.formatBytes(stat.size),
        extension: ext,
        lastModified: stat.modified,
      );

      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => FileViewerPage(node: node)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: PathHistoryDrawer(
        paths: _pathHistory,
        onPathTap: (path) {
          _pathController.text = path;
          _startScan();
        },
        onPathRemove: _removePathFromHistory,
      ),
      backgroundColor: AppColors.neutral12,
      body: Column(
        children: [
          CustomTitleBar(
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            onSettingsPressed: _openSettingsDialog,
            onFileOpenPressed: _openFileFromSystem,
            onComparePressed: _openCompareDialog,
            onExportPressed: _openExportDialog,
            onOpenTerminalPressed: _openTerminal,
            onOpenExplorerPressed: _openExplorer,
            onGlobalDependenciesPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GlobalDependenciesScreen(),
                ),
              );
            },
            onFileHashPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FileHashScreen(),
                ),
              );
            },
            hasResults: _scanResults.isNotEmpty,
          ),
          HeaderBar(
            pathController: _pathController,
            isScanning: _isScanning,
            onScanPressed: _startScan,
            onCancelPressed: _cancelScan,
          ),
          scanExclusionsBanner(context, _exclusionsConfig),
          if (_isScanning) scanProgressBanner(_scanProgress),
          appMainTabBar(_tabController),
          Expanded(
            child: _errorMessage != null
                ? homeErrorState(context, _errorMessage!)
                : _scanResults.isEmpty
                ? homeEmptyState(context)
                : Row(
                    children: [
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            DirectoryTreeView(
                              nodes: _scanResults,
                              rootPath: _pathController.text.trim(),
                              onNodeTap: (node) =>
                                  setState(() => _selectedNode = node),
                            ),
                            AsciiView(
                              asciiContent: _asciiOutput,
                              nodes: _scanResults,
                            ),
                            StatsView(
                              stats:
                                  _stats ?? ScanStats.fromNodes(_scanResults),
                              nodes: _scanResults,
                              thresholdsConfig: _thresholdsConfig,
                              tokenizerRegistry: _tokenizerRegistry,
                              scanTotals: _scanTotals,
                              rootPath: _pathController.text.trim(),
                            ),
                            GitHistoryView(
                              rootPath: _pathController.text.trim(),
                            ),
                            DependenciesView(
                              nodes: _scanResults,
                              rootPath: _pathController.text.trim(),
                            ),
                          ],
                        ),
                      ),
                      NodeDetailPanel(
                        selectedNode: _selectedNode,
                        onClose: () => setState(() => _selectedNode = null),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}