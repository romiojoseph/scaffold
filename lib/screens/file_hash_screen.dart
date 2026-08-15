import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/file_crypto_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/clipboard_utils.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_icon.dart';
import '../widgets/common/app_text_field.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/file_hash/hash_controls_bar.dart';
import '../widgets/file_hash/hash_stat_cards.dart';
import '../widgets/file_hash/hash_table.dart';

class FileHashScreen extends StatefulWidget {
  const FileHashScreen({super.key});

  @override
  State<FileHashScreen> createState() => _FileHashScreenState();
}

class _FileHashScreenState extends State<FileHashScreen> {
  final FileCryptoService _cryptoService = FileCryptoService();
  final TextEditingController _searchController = TextEditingController();

  // Hash State
  final List<FileHashResult> _hashResults = [];
  final Set<String> _pendingHashPaths = {};
  bool _isHashing = false;
  String _searchFilter = '';
  bool _excludeFilePathOnExport = false;

  // Encrypt State
  final List<String> _selectedEncryptFiles = [];
  final TextEditingController _encryptPasswordController =
      TextEditingController();
  final TextEditingController _encryptConfirmPasswordController =
      TextEditingController();
  bool _obscureEncryptPassword = true;
  bool _obscureEncryptConfirmPassword = true;
  bool _isEncrypting = false;
  String? _currentEncryptingPath;
  final List<CryptoOperationResult> _encryptResults = [];

  // Decrypt State
  final List<String> _selectedDecryptFiles = [];
  final TextEditingController _decryptPasswordController =
      TextEditingController();
  bool _obscureDecryptPassword = true;
  bool _isDecrypting = false;
  String? _currentDecryptingPath;
  final List<CryptoOperationResult> _decryptResults = [];

  // Cancellation
  bool _isCancelled = false;

  bool get _isBusy => _isHashing || _isEncrypting || _isDecrypting;

  void _cancelCurrentOperation() {
    if (!_isBusy) return;
    setState(() {
      _isCancelled = true;
    });
    AppToast.showInfo(context, 'Cancelling operation...');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _encryptPasswordController.dispose();
    _encryptConfirmPasswordController.dispose();
    _decryptPasswordController.dispose();
    super.dispose();
  }

  // --- HASH METHODS ---

  Future<void> _pickFilesToHash() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Select Files to Hash',
    );

    if (result == null || result.files.isEmpty) return;

    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where(
          (p) =>
              !_hashResults.any((r) => r.filePath == p) &&
              !_pendingHashPaths.contains(p),
        )
        .toList();

    if (paths.isEmpty) return;

    _isCancelled = false;
    setState(() {
      _pendingHashPaths.addAll(paths);
      _isHashing = true;
    });

    for (final path in paths) {
      if (!mounted || _isCancelled) break;
      try {
        final hashResult = await _cryptoService.hashFile(path);
        if (mounted && !_isCancelled) {
          setState(() {
            _pendingHashPaths.remove(path);
            _hashResults.add(hashResult);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _pendingHashPaths.remove(path));
          if (!_isCancelled) {
            AppToast.showError(context, 'Failed to hash $path: $e');
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        if (_isCancelled) {
          _pendingHashPaths.clear();
        }
        _isHashing = false;
        _isCancelled = false;
      });
    }
  }

  void _clearAllHashes() {
    setState(() {
      _hashResults.clear();
      _pendingHashPaths.clear();
    });
  }

  void _removeHashItem(String filePath) {
    setState(() {
      _hashResults.removeWhere((r) => r.filePath == filePath);
      _pendingHashPaths.remove(filePath);
    });
  }

  Future<void> _exportCsv() async {
    if (_hashResults.isEmpty) return;
    final csvContent = _cryptoService.exportToCsv(
      _hashResults,
      includeFilePath: !_excludeFilePathOnExport,
    );
    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Save Hashes as CSV',
      fileName: 'hashes_${DateTime.now().millisecondsSinceEpoch}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsString(csvContent);
      if (mounted) {
        AppToast.showSuccess(context, 'Exported CSV to $outputPath');
      }
    }
  }

  Future<void> _exportJson() async {
    if (_hashResults.isEmpty) return;
    final jsonContent = _cryptoService.exportToJson(
      _hashResults,
      includeFilePath: !_excludeFilePathOnExport,
    );
    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Save Hashes as JSON',
      fileName: 'hashes_${DateTime.now().millisecondsSinceEpoch}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsString(jsonContent);
      if (mounted) {
        AppToast.showSuccess(context, 'Exported JSON to $outputPath');
      }
    }
  }

  void _copyToClipboard(String text, String message) async {
    final success = await ClipboardUtils.copy(text);
    if (!mounted) return;
    if (success) {
      AppToast.showSuccess(context, message);
    } else {
      AppToast.showError(context, 'Failed to copy to clipboard');
    }
  }

  // --- ENCRYPT METHODS ---

  Future<void> _pickEncryptFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Select Files to Encrypt',
    );
    if (result == null) return;
    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => !_selectedEncryptFiles.contains(p))
        .toList();

    setState(() {
      _selectedEncryptFiles.addAll(paths);
      _encryptResults.clear();
    });
  }

  Future<void> _runEncryption() async {
    final password = _encryptPasswordController.text;
    final confirm = _encryptConfirmPasswordController.text;

    if (password.isEmpty) {
      AppToast.showWarning(context, 'Enter an encryption password');
      return;
    }
    if (password != confirm) {
      AppToast.showError(context, 'Passwords do not match');
      return;
    }
    if (_selectedEncryptFiles.isEmpty) {
      AppToast.showWarning(context, 'Select at least one file to encrypt');
      return;
    }

    _isCancelled = false;
    setState(() {
      _isEncrypting = true;
      _encryptResults.clear();
    });

    // Sequential encryption to bound memory consumption
    for (int i = 0; i < _selectedEncryptFiles.length; i++) {
      if (_isCancelled || !mounted) break;
      final filePath = _selectedEncryptFiles[i];
      if (mounted) {
        setState(() => _currentEncryptingPath = filePath);
      }
      final res = await _cryptoService.encryptFile(
        filePath: filePath,
        password: password,
      );
      if (mounted && !_isCancelled) {
        setState(() {
          _encryptResults.add(res);
        });
      }
    }

    if (mounted) {
      setState(() {
        _isEncrypting = false;
        _currentEncryptingPath = null;
      });
      if (_isCancelled) {
        AppToast.showWarning(context, 'Encryption cancelled');
        setState(() => _isCancelled = false);
      } else {
        final successCount = _encryptResults.where((r) => r.isSuccess).length;
        if (successCount == _selectedEncryptFiles.length) {
          AppToast.showSuccess(
            context,
            'Successfully encrypted $successCount files (.enc created)',
          );
        } else {
          AppToast.showWarning(
            context,
            'Encrypted $successCount of ${_selectedEncryptFiles.length} files',
          );
        }
      }
    }
  }

  // --- DECRYPT METHODS ---

  Future<void> _pickDecryptFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Select .enc Files to Decrypt',
      type: FileType.custom,
      allowedExtensions: ['enc'],
    );
    if (result == null) return;
    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => !_selectedDecryptFiles.contains(p))
        .toList();

    setState(() {
      _selectedDecryptFiles.addAll(paths);
      _decryptResults.clear();
    });
  }

  Future<void> _runDecryption() async {
    final password = _decryptPasswordController.text;
    if (password.isEmpty) {
      AppToast.showWarning(context, 'Enter the decryption password');
      return;
    }
    if (_selectedDecryptFiles.isEmpty) {
      AppToast.showWarning(context, 'Select at least one .enc file to decrypt');
      return;
    }

    _isCancelled = false;
    setState(() {
      _isDecrypting = true;
      _decryptResults.clear();
    });

    // Sequential decryption
    for (int i = 0; i < _selectedDecryptFiles.length; i++) {
      if (_isCancelled || !mounted) break;
      final filePath = _selectedDecryptFiles[i];
      if (mounted) {
        setState(() => _currentDecryptingPath = filePath);
      }
      final res = await _cryptoService.decryptFile(
        filePath: filePath,
        password: password,
      );
      if (mounted && !_isCancelled) {
        setState(() {
          _decryptResults.add(res);
        });
      }
    }

    if (mounted) {
      setState(() {
        _isDecrypting = false;
        _currentDecryptingPath = null;
      });
      if (_isCancelled) {
        AppToast.showWarning(context, 'Decryption cancelled');
        setState(() => _isCancelled = false);
      } else {
        final successCount = _decryptResults.where((r) => r.isSuccess).length;
        if (successCount == _selectedDecryptFiles.length) {
          AppToast.showSuccess(
            context,
            'Successfully decrypted $successCount files',
          );
        } else {
          AppToast.showError(
            context,
            'Decrypted $successCount of ${_selectedDecryptFiles.length} files (check passwords)',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSizeBytes = _hashResults.fold<int>(
      0,
      (sum, r) => sum + r.fileSizeBytes,
    );

    final filteredHashResults = _hashResults.where((r) {
      if (_searchFilter.isEmpty) return true;
      final q = _searchFilter.toLowerCase();
      return r.fileName.toLowerCase().contains(q) ||
          r.sha256.toLowerCase().contains(q) ||
          r.sha512.toLowerCase().contains(q);
    }).toList();

    return PopScope(
      canPop: !_isBusy,
      child: Scaffold(
        backgroundColor: AppColors.neutral12,
        body: SafeArea(
          child: Column(
            children: [
              // Top App Bar
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.neutral13,
                  border: Border(
                    bottom: BorderSide(color: AppColors.neutral11),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: AppIcon(
                        AppSvgIcon.arrowLeftBold,
                        size: 16,
                        color: _isBusy
                            ? AppColors.neutral8
                            : AppColors.neutral4,
                      ),
                      onPressed: _isBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                      tooltip: _isBusy
                          ? 'Operation in progress'
                          : 'Back to Scanner',
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'File Hash & Encryption',
                      style: AppTypography.subtitle(
                        color: AppColors.neutral4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_isBusy) ...[
                      const Spacer(),
                      AppButton(
                        label: 'Cancel',
                        svgIcon: AppSvgIcon.xBold,
                        variant: AppButtonVariant.ghost,
                        foregroundColor: AppColors.neutral6,
                        hoverForegroundColor: AppColors.neutral4,
                        size: AppButtonSize.small,
                        onPressed: _cancelCurrentOperation,
                      ),
                    ],
                  ],
                ),
              ),

              // Content Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // --- SECTION 1: HASHING ---
                    Row(
                      children: [
                        Text(
                          'File Hashes (SHA-256 / SHA-512)',
                          style: AppTypography.heading6(
                            color: AppColors.neutral5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    hashStatCards(
                      totalFiles:
                          _hashResults.length + _pendingHashPaths.length,
                      totalSizeBytes: totalSizeBytes,
                      hashedCount: _hashResults.length,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    hashControlsBar(
                      searchController: _searchController,
                      searchFilter: _searchFilter,
                      onFilterChanged: (val) =>
                          setState(() => _searchFilter = val),
                      onAddFiles: _pickFilesToHash,
                      onClearAll: _clearAllHashes,
                      onExportCsv: _exportCsv,
                      onExportJson: _exportJson,
                      excludeFilePathOnExport: _excludeFilePathOnExport,
                      onToggleExcludeFilePath: () => setState(
                        () => _excludeFilePathOnExport =
                            !_excludeFilePathOnExport,
                      ),
                      isHashing: _isHashing,
                      hasResults: _hashResults.isNotEmpty,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    hashTable(
                      results: filteredHashResults,
                      pendingFilePaths: _pendingHashPaths,
                      onCopy: _copyToClipboard,
                      onRemove: _removeHashItem,
                    ),

                    const SizedBox(height: AppSpacing.massive),

                    // --- SECTION 2: ENCRYPT & DECRYPT ---
                    Row(
                      children: [
                        Text(
                          'AES-256-GCM File Encryption & Decryption (PBKDF2 Key Derivation)',
                          style: AppTypography.heading6(
                            color: AppColors.neutral5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encrypt Card
                        Expanded(child: _buildEncryptCard()),
                        const SizedBox(width: AppSpacing.lg),

                        // Decrypt Card
                        Expanded(child: _buildDecryptCard()),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEncryptCard() {
    final passwordsMatch =
        _encryptPasswordController.text.isNotEmpty &&
        _encryptPasswordController.text ==
            _encryptConfirmPasswordController.text;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: ShapeDecoration(
        color: AppColors.neutral13,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.neutral11, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Encrypt to .enc',
                style: AppTypography.subtitle(
                  color: AppColors.neutral4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // File select row
          Row(
            children: [
              AppButton(
                label: 'Add Files to Encrypt',
                svgIcon: AppSvgIcon.fileCode,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.medium,
                onPressed: _isEncrypting ? null : _pickEncryptFiles,
              ),
              const SizedBox(width: AppSpacing.md),
              if (_selectedEncryptFiles.isNotEmpty)
                Text(
                  '${_selectedEncryptFiles.length} files selected',
                  style: AppTypography.body(color: AppColors.neutral6),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_selectedEncryptFiles.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.neutral12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.neutral11),
              ),
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView(
                shrinkWrap: true,
                children: _selectedEncryptFiles.map((p) {
                  final isCurrent =
                      _isEncrypting && _currentEncryptingPath == p;
                  final isDone = _encryptResults.any((r) => r.inputPath == p);
                  final result = _encryptResults
                      .where((r) => r.inputPath == p)
                      .firstOrNull;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        if (isCurrent)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryBase,
                              ),
                            ),
                          )
                        else if (isDone && result != null)
                          AppIcon(
                            result.isSuccess
                                ? AppSvgIcon.checkCircleFill
                                : AppSvgIcon.xBold,
                            size: 14,
                            color: result.isSuccess
                                ? AppColors.successBase
                                : AppColors.dangerBase,
                          )
                        else
                          const AppIcon(
                            AppSvgIcon.file,
                            size: 14,
                            color: AppColors.neutral6,
                          ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            p.split(RegExp(r'[/\\]')).last,
                            style: AppTypography.caption(
                              color: isCurrent
                                  ? AppColors.primaryBase
                                  : (isDone
                                        ? AppColors.neutral2
                                        : AppColors.neutral4),
                              fontWeight: isCurrent
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_isEncrypting)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            icon: const AppIcon(
                              AppSvgIcon.xBold,
                              size: 12,
                              color: AppColors.neutral7,
                            ),
                            splashRadius: 12,
                            onPressed: () =>
                                setState(() => _selectedEncryptFiles.remove(p)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Passwords using AppTextField
          AppTextField(
            controller: _encryptPasswordController,
            hintText: 'Enter encryption password...',
            size: AppInputSize.medium,
            obscureText: _obscureEncryptPassword,
            onChanged: (_) => setState(() {}),
            suffixIcon: IconButton(
              icon: AppIcon(
                _obscureEncryptPassword
                    ? AppSvgIcon.eyeSlashFill
                    : AppSvgIcon.eyeDuotone,
                size: 16,
                color: AppColors.neutral7,
              ),
              onPressed: () => setState(
                () => _obscureEncryptPassword = !_obscureEncryptPassword,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _encryptConfirmPasswordController,
            hintText: 'Re-enter password...',
            size: AppInputSize.medium,
            obscureText: _obscureEncryptConfirmPassword,
            onChanged: (_) => setState(() {}),
            suffixIcon: IconButton(
              icon: AppIcon(
                _obscureEncryptConfirmPassword
                    ? AppSvgIcon.eyeSlashFill
                    : AppSvgIcon.eyeDuotone,
                size: 16,
                color: AppColors.neutral7,
              ),
              onPressed: () => setState(
                () => _obscureEncryptConfirmPassword =
                    !_obscureEncryptConfirmPassword,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          AppButton(
            label: _isEncrypting
                ? 'Encrypting (${_encryptResults.length + 1}/${_selectedEncryptFiles.length})...'
                : 'Encrypt Selected',
            variant: AppButtonVariant.primary,
            size: AppButtonSize.medium,
            isLoading: _isEncrypting,
            onPressed:
                (!_isEncrypting &&
                    _selectedEncryptFiles.isNotEmpty &&
                    passwordsMatch)
                ? _runEncryption
                : null,
          ),

          // Results
          if (_encryptResults.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.neutral12, thickness: 2),
            ..._encryptResults.map((r) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    AppIcon(
                      r.isSuccess
                          ? AppSvgIcon.checkCircleFill
                          : AppSvgIcon.xBold,
                      size: 16,
                      color: r.isSuccess
                          ? AppColors.successBase
                          : AppColors.dangerBase,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        r.isSuccess
                            ? 'Output: ${r.outputPath}'
                            : 'Error: ${r.errorMessage}',
                        style: AppTypography.body(
                          color: r.isSuccess
                              ? AppColors.neutral5
                              : AppColors.dangerBase,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDecryptCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: ShapeDecoration(
        color: AppColors.neutral13,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.neutral11, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Decrypt .enc File',
                style: AppTypography.subtitle(
                  color: AppColors.neutral4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // File select row
          Row(
            children: [
              AppButton(
                label: 'Add .enc Files',
                svgIcon: AppSvgIcon.fileCode,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.medium,
                onPressed: _isDecrypting ? null : _pickDecryptFiles,
              ),
              const SizedBox(width: AppSpacing.md),
              if (_selectedDecryptFiles.isNotEmpty)
                Text(
                  '${_selectedDecryptFiles.length} files selected',
                  style: AppTypography.body(color: AppColors.neutral6),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_selectedDecryptFiles.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.neutral12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.neutral11),
              ),
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView(
                shrinkWrap: true,
                children: _selectedDecryptFiles.map((p) {
                  final isCurrent =
                      _isDecrypting && _currentDecryptingPath == p;
                  final isDone = _decryptResults.any((r) => r.inputPath == p);
                  final result = _decryptResults
                      .where((r) => r.inputPath == p)
                      .firstOrNull;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        if (isCurrent)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.infoBase,
                              ),
                            ),
                          )
                        else if (isDone && result != null)
                          AppIcon(
                            result.isSuccess
                                ? AppSvgIcon.checkCircleFill
                                : AppSvgIcon.xBold,
                            size: 14,
                            color: result.isSuccess
                                ? AppColors.successBase
                                : AppColors.dangerBase,
                          )
                        else
                          const AppIcon(
                            AppSvgIcon.fileArchive,
                            size: 14,
                            color: AppColors.neutral6,
                          ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            p.split(RegExp(r'[/\\]')).last,
                            style: AppTypography.caption(
                              color: isCurrent
                                  ? AppColors.infoBase
                                  : (isDone
                                        ? AppColors.neutral2
                                        : AppColors.neutral4),
                              fontWeight: isCurrent
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_isDecrypting)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            icon: const AppIcon(
                              AppSvgIcon.xBold,
                              size: 12,
                              color: AppColors.neutral7,
                            ),
                            splashRadius: 12,
                            onPressed: () =>
                                setState(() => _selectedDecryptFiles.remove(p)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Password using AppTextField
          AppTextField(
            controller: _decryptPasswordController,
            hintText: 'Enter decryption password...',
            size: AppInputSize.medium,
            obscureText: _obscureDecryptPassword,
            onChanged: (_) => setState(() {}),
            suffixIcon: IconButton(
              icon: AppIcon(
                _obscureDecryptPassword
                    ? AppSvgIcon.eyeSlashFill
                    : AppSvgIcon.eyeDuotone,
                size: 16,
                color: AppColors.neutral7,
              ),
              onPressed: () => setState(
                () => _obscureDecryptPassword = !_obscureDecryptPassword,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          AppButton(
            label: _isDecrypting
                ? 'Decrypting (${_decryptResults.length + 1}/${_selectedDecryptFiles.length})...'
                : 'Decrypt Selected',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.medium,
            isLoading: _isDecrypting,
            onPressed:
                (!_isDecrypting &&
                    _selectedDecryptFiles.isNotEmpty &&
                    _decryptPasswordController.text.isNotEmpty)
                ? _runDecryption
                : null,
          ),

          // Results
          if (_decryptResults.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.neutral12, thickness: 2),
            ..._decryptResults.map((r) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    AppIcon(
                      r.isSuccess
                          ? AppSvgIcon.checkCircleFill
                          : AppSvgIcon.xBold,
                      size: 16,
                      color: r.isSuccess
                          ? AppColors.successBase
                          : AppColors.dangerBase,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        r.isSuccess
                            ? 'Restored: ${r.outputPath}'
                            : 'Error: ${r.errorMessage}',
                        style: AppTypography.body(
                          color: r.isSuccess
                              ? AppColors.neutral5
                              : AppColors.dangerBase,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
