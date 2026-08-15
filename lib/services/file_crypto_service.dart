import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:ffi/ffi.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/argon2.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

// ============================================================================
// 1. DATA MODELS & ENUMS (2026 Standard)
// ============================================================================

enum CryptoMode {
  encrypt('Encryption'),
  decrypt('Decryption');

  final String label;
  const CryptoMode(this.label);
}

enum KdfAlgorithm {
  argon2id(0x01, 'Argon2id (OWASP 2026)'),
  pbkdf2Sha256(0x02, 'PBKDF2-HMAC-SHA256 (Legacy)');

  final int id;
  final String label;
  const KdfAlgorithm(this.id, this.label);

  static KdfAlgorithm fromId(int id) {
    for (final kdf in values) {
      if (kdf.id == id) return kdf;
    }
    throw UnsupportedError('Unsupported KDF ID: 0x${id.toRadixString(16)}');
  }
}

enum CipherAlgorithm {
  aes256Gcm(0x01, 'AES-256-GCM');

  final int id;
  final String label;
  const CipherAlgorithm(this.id, this.label);

  static CipherAlgorithm fromId(int id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    throw UnsupportedError('Unsupported Cipher ID: 0x${id.toRadixString(16)}');
  }
}

class FileHashResult {
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final String sha256;
  final String sha512;
  final DateTime processedAt;
  final Duration elapsed;

  const FileHashResult({
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.sha256,
    required this.sha512,
    required this.processedAt,
    this.elapsed = Duration.zero,
  });

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'filePath': filePath,
    'fileSizeBytes': fileSizeBytes,
    'sha256': sha256,
    'sha512': sha512,
    'processedAt': processedAt.toIso8601String(),
    'elapsedMs': elapsed.inMilliseconds,
  };
}

class CryptoOperationResult {
  final String inputPath;
  final String? outputPath;
  final bool isSuccess;
  final String? errorMessage;
  final CryptoMode mode;
  final int bytesProcessed;
  final Duration elapsed;
  final KdfAlgorithm? kdfAlgorithm;
  final CipherAlgorithm? cipherAlgorithm;

  const CryptoOperationResult({
    required this.inputPath,
    this.outputPath,
    required this.isSuccess,
    this.errorMessage,
    this.mode = CryptoMode.encrypt,
    this.bytesProcessed = 0,
    this.elapsed = Duration.zero,
    this.kdfAlgorithm,
    this.cipherAlgorithm,
  });

  Map<String, dynamic> toJson() => {
    'inputPath': inputPath,
    'outputPath': outputPath,
    'isSuccess': isSuccess,
    'errorMessage': errorMessage,
    'mode': mode.name,
    'bytesProcessed': bytesProcessed,
    'elapsedMs': elapsed.inMilliseconds,
    'kdf': kdfAlgorithm?.label,
    'cipher': cipherAlgorithm?.label,
  };
}

// ============================================================================
// 2. BINARY CONTAINER HEADER SPECIFICATION (FCRY v1)
// ============================================================================
/// Layout:
/// [0..3]   4B Magic: 'FCRY' (0x46, 0x43, 0x52, 0x59)
/// [4]      1B Format Version: 0x01
/// [5]      1B Cipher ID: 0x01 (AES-256-GCM)
/// [6]      1B KDF ID: 0x01 (Argon2id) / 0x02 (PBKDF2-SHA256)
/// [7]      1B Salt Length (S = 16 or 32)
/// [8..8+S-1] Salt bytes
/// [8+S]    1B Nonce Length (N = 12)
/// [9+S..9+S+N-1] Nonce bytes
/// [9+S+N..12+S+N] 4B uint32 KDF Iterations / Passes
/// [13+S+N..16+S+N] 4B uint32 KDF Memory (in KiB)
/// [17+S+N..20+S+N] 4B uint32 KDF Parallelism / Lanes
/// [21+S+N..28+S+N] 8B uint64 Original File Size (Bytes)
/// [29+S+N..60+S+N] 32B SHA-256 of UTF-8 Original Filename (AAD metadata binding)
/// [61+S+N..EOF-16] Ciphertext
/// [EOF-16..EOF] 16B AEAD Tag
class _FcryHeader {
  static const List<int> magic = [0x46, 0x43, 0x52, 0x59]; // 'FCRY'
  static const int currentVersion = 0x01;

  final int version;
  final CipherAlgorithm cipher;
  final KdfAlgorithm kdf;
  final Uint8List salt;
  final Uint8List nonce;
  final int kdfIterations;
  final int kdfMemoryKiB;
  final int kdfParallelism;
  final int originalFileSize;
  final Uint8List originalFilenameHash;
  final Uint8List rawHeaderBytes;

  const _FcryHeader({
    required this.version,
    required this.cipher,
    required this.kdf,
    required this.salt,
    required this.nonce,
    required this.kdfIterations,
    required this.kdfMemoryKiB,
    required this.kdfParallelism,
    required this.originalFileSize,
    required this.originalFilenameHash,
    required this.rawHeaderBytes,
  });

  static _FcryHeader createV1({
    required Uint8List salt,
    required Uint8List nonce,
    required int originalFileSize,
    required String originalFileName,
    int iterations = 3,
    int memoryKiB = 65536, // 64 MiB (OWASP 2026)
    int parallelism = 4,
  }) {
    final nameHash = Uint8List.fromList(
      crypto.sha256.convert(utf8.encode(originalFileName)).bytes,
    );

    final bb = BytesBuilder(copy: false)
      ..add(magic)
      ..addByte(currentVersion)
      ..addByte(CipherAlgorithm.aes256Gcm.id)
      ..addByte(KdfAlgorithm.argon2id.id)
      ..addByte(salt.length)
      ..add(salt)
      ..addByte(nonce.length)
      ..add(nonce);

    final numBuf = ByteData(20)
      ..setUint32(0, iterations, Endian.big)
      ..setUint32(4, memoryKiB, Endian.big)
      ..setUint32(8, parallelism, Endian.big)
      ..setUint64(12, originalFileSize, Endian.big);

    bb.add(numBuf.buffer.asUint8List());
    bb.add(nameHash);

    final raw = bb.toBytes();

    return _FcryHeader(
      version: currentVersion,
      cipher: CipherAlgorithm.aes256Gcm,
      kdf: KdfAlgorithm.argon2id,
      salt: salt,
      nonce: nonce,
      kdfIterations: iterations,
      kdfMemoryKiB: memoryKiB,
      kdfParallelism: parallelism,
      originalFileSize: originalFileSize,
      originalFilenameHash: nameHash,
      rawHeaderBytes: raw,
    );
  }

  static _FcryHeader? tryParse(Uint8List headerPrefix) {
    if (headerPrefix.length < 4) return null;
    for (int i = 0; i < 4; i++) {
      if (headerPrefix[i] != magic[i]) return null;
    }

    try {
      final reader = ByteData.sublistView(headerPrefix);
      int offset = 4;

      final version = reader.getUint8(offset++);
      if (version != 0x01) return null;

      final cipher = CipherAlgorithm.fromId(reader.getUint8(offset++));
      final kdf = KdfAlgorithm.fromId(reader.getUint8(offset++));

      final saltLen = reader.getUint8(offset++);
      if (headerPrefix.length < offset + saltLen + 1) return null;
      final salt = Uint8List.fromList(
        headerPrefix.sublist(offset, offset + saltLen),
      );
      offset += saltLen;

      final nonceLen = reader.getUint8(offset++);
      if (headerPrefix.length < offset + nonceLen + 20 + 32) return null;
      final nonce = Uint8List.fromList(
        headerPrefix.sublist(offset, offset + nonceLen),
      );
      offset += nonceLen;

      final iterations = reader.getUint32(offset, Endian.big);
      offset += 4;
      final memoryKiB = reader.getUint32(offset, Endian.big);
      offset += 4;
      final parallelism = reader.getUint32(offset, Endian.big);
      offset += 4;
      final originalSize = reader.getUint64(offset, Endian.big);
      offset += 8;

      final nameHash = Uint8List.fromList(
        headerPrefix.sublist(offset, offset + 32),
      );
      offset += 32;

      final rawHeader = Uint8List.fromList(headerPrefix.sublist(0, offset));

      return _FcryHeader(
        version: version,
        cipher: cipher,
        kdf: kdf,
        salt: salt,
        nonce: nonce,
        kdfIterations: iterations,
        kdfMemoryKiB: memoryKiB,
        kdfParallelism: parallelism,
        originalFileSize: originalSize,
        originalFilenameHash: nameHash,
        rawHeaderBytes: rawHeader,
      );
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// 3. WINDOWS CNG (bcrypt.dll) FFI BINDINGS & NATIVE WRAPPER
// ============================================================================

typedef _BCryptGenRandomPtr =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Void> hAlgorithm,
      ffi.Pointer<ffi.Uint8> pbBuffer,
      ffi.Uint32 cbBuffer,
      ffi.Uint32 dwFlags,
    );
typedef _BCryptGenRandom =
    int Function(
      ffi.Pointer<ffi.Void> hAlgorithm,
      ffi.Pointer<ffi.Uint8> pbBuffer,
      int cbBuffer,
      int dwFlags,
    );

final class _WindowsCng {
  static final _WindowsCng instance = _WindowsCng._();
  bool _isAvailable = false;
  ffi.DynamicLibrary? _bcrypt;

  _BCryptGenRandom? _cngGenRandom;

  _WindowsCng._() {
    if (Platform.isWindows) {
      try {
        _bcrypt = ffi.DynamicLibrary.open('bcrypt.dll');
        _cngGenRandom = _bcrypt!
            .lookupFunction<_BCryptGenRandomPtr, _BCryptGenRandom>(
              'BCryptGenRandom',
            );
        _isAvailable = true;
      } catch (_) {
        _isAvailable = false;
      }
    }
  }

  bool get isAvailable => _isAvailable;

  /// Cryptographically secure random byte generation accelerated via Windows CNG
  Uint8List generateSecureBytes(int length) {
    if (_isAvailable && _cngGenRandom != null) {
      final ptr = calloc<ffi.Uint8>(length);
      try {
        // BCRYPT_USE_SYSTEM_PREFERRED_RNG = 0x00000002
        final status = _cngGenRandom!(
          ffi.Pointer.fromAddress(0),
          ptr,
          length,
          0x00000002,
        );
        if (status == 0) {
          return Uint8List.fromList(ptr.asTypedList(length));
        }
      } catch (_) {
        // Fallback below
      } finally {
        calloc.free(ptr);
      }
    }

    // High-entropy fallback
    final rng = Random.secure();
    final bytes = Uint8List(length);
    final byteData = ByteData.sublistView(bytes);
    int i = 0;
    while (i + 4 <= length) {
      byteData.setUint32(i, rng.nextInt(0xFFFFFFFF), Endian.little);
      i += 4;
    }
    while (i < length) {
      bytes[i++] = rng.nextInt(256);
    }
    return bytes;
  }
}

// ============================================================================
// 4. PERSISTENT WORKER ISOLATE & ZERO-COPY STREAMING ENGINE
// ============================================================================

enum _IsolateCommandType { hashFile, encryptFile, decryptFile, shutdown }

class _IsolateRequest {
  final int id;
  final _IsolateCommandType type;
  final String inputPath;
  final String? outputPath;
  final String? password;

  _IsolateRequest({
    required this.id,
    required this.type,
    required this.inputPath,
    this.outputPath,
    this.password,
  });
}

class _IsolateProgress {
  final int requestId;
  final double progress; // 0.0 to 1.0

  _IsolateProgress(this.requestId, this.progress);
}

class _IsolateResponse {
  final int requestId;
  final bool isSuccess;
  final dynamic result; // FileHashResult or CryptoOperationResult
  final String? errorMessage;

  _IsolateResponse({
    required this.requestId,
    required this.isSuccess,
    this.result,
    this.errorMessage,
  });
}

class _WorkerIsolateManager {
  static final _WorkerIsolateManager instance = _WorkerIsolateManager._();
  _WorkerIsolateManager._();

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  int _nextRequestId = 1;

  final Map<int, Completer<_IsolateResponse>> _pending = {};
  final Map<int, void Function(double progress)> _progressHandlers = {};

  Future<void> _ensureStarted() async {
    if (_isolate != null && _sendPort != null) return;

    final initPort = ReceivePort();
    _isolate = await Isolate.spawn(_workerEntryPoint, initPort.sendPort);
    _sendPort = await initPort.first as SendPort;
    initPort.close();

    _receivePort = ReceivePort();
    _sendPort!.send(_receivePort!.sendPort);

    _receivePort!.listen((message) {
      if (message is _IsolateProgress) {
        _progressHandlers[message.requestId]?.call(message.progress);
      } else if (message is _IsolateResponse) {
        final completer = _pending.remove(message.requestId);
        _progressHandlers.remove(message.requestId);
        completer?.complete(message);
      }
    });
  }

  Future<_IsolateResponse> sendRequest(
    _IsolateCommandType type, {
    required String inputPath,
    String? outputPath,
    String? password,
    void Function(double progress)? onProgress,
  }) async {
    await _ensureStarted();
    final reqId = _nextRequestId++;
    final completer = Completer<_IsolateResponse>();
    _pending[reqId] = completer;

    if (onProgress != null) {
      _progressHandlers[reqId] = onProgress;
    }

    _sendPort!.send(
      _IsolateRequest(
        id: reqId,
        type: type,
        inputPath: inputPath,
        outputPath: outputPath,
        password: password,
      ),
    );

    return completer.future;
  }

  void dispose() {
    _sendPort?.send(
      _IsolateRequest(id: 0, type: _IsolateCommandType.shutdown, inputPath: ''),
    );
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort = null;
    _pending.clear();
    _progressHandlers.clear();
  }

  static void _workerEntryPoint(SendPort initSendPort) {
    final commandPort = ReceivePort();
    initSendPort.send(commandPort.sendPort);

    SendPort? clientReplyPort;

    commandPort.listen((message) async {
      if (message is SendPort) {
        clientReplyPort = message;
        return;
      }

      if (message is! _IsolateRequest) return;
      if (message.type == _IsolateCommandType.shutdown) {
        commandPort.close();
        return;
      }

      final reply = clientReplyPort;
      if (reply == null) return;

      void reportProgress(double p) {
        reply.send(_IsolateProgress(message.id, p));
      }

      try {
        switch (message.type) {
          case _IsolateCommandType.hashFile:
            final res = await _workerExecuteHash(
              message.inputPath,
              onProgress: reportProgress,
            );
            reply.send(
              _IsolateResponse(
                requestId: message.id,
                isSuccess: true,
                result: res,
              ),
            );
            break;

          case _IsolateCommandType.encryptFile:
            final res = await _workerExecuteEncrypt(
              inputPath: message.inputPath,
              outputPath: message.outputPath!,
              password: message.password!,
              onProgress: reportProgress,
            );
            reply.send(
              _IsolateResponse(
                requestId: message.id,
                isSuccess: res.isSuccess,
                result: res,
                errorMessage: res.errorMessage,
              ),
            );
            break;

          case _IsolateCommandType.decryptFile:
            final res = await _workerExecuteDecrypt(
              inputPath: message.inputPath,
              outputPath: message.outputPath!,
              password: message.password!,
              onProgress: reportProgress,
            );
            reply.send(
              _IsolateResponse(
                requestId: message.id,
                isSuccess: res.isSuccess,
                result: res,
                errorMessage: res.errorMessage,
              ),
            );
            break;

          default:
            break;
        }
      } catch (e) {
        reply.send(
          _IsolateResponse(
            requestId: message.id,
            isSuccess: false,
            errorMessage: e.toString(),
          ),
        );
      }
    });
  }

  // --- WORKER STREAMING CRYPTO WORKLOADS ---

  static const int _chunkSize = 2 * 1024 * 1024; // 2MB Chunk Buffer

  static Future<FileHashResult> _workerExecuteHash(
    String filePath, {
    required void Function(double progress) onProgress,
  }) async {
    final sw = Stopwatch()..start();
    final file = File(filePath);
    final totalSize = await file.length();
    final fileName = filePath.split(RegExp(r'[/\\]')).last;

    final sha256Sink = _DigestSink();
    final sha512Sink = _DigestSink();

    final sha256Converter = crypto.sha256.startChunkedConversion(sha256Sink);
    final sha512Converter = crypto.sha512.startChunkedConversion(sha512Sink);

    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      int bytesReadTotal = 0;
      final buffer = Uint8List(_chunkSize);

      while (bytesReadTotal < totalSize) {
        final readBytes = await raf.readInto(buffer);
        if (readBytes == 0) break;

        final chunkView = Uint8List.sublistView(buffer, 0, readBytes);
        sha256Converter.add(chunkView);
        sha512Converter.add(chunkView);

        bytesReadTotal += readBytes;
        if (totalSize > 0) {
          onProgress(bytesReadTotal / totalSize);
        }
      }
    } finally {
      await raf?.close();
      sha256Converter.close();
      sha512Converter.close();
    }

    sw.stop();

    return FileHashResult(
      fileName: fileName,
      filePath: filePath,
      fileSizeBytes: totalSize,
      sha256: sha256Sink.digest.toString(),
      sha512: sha512Sink.digest.toString(),
      processedAt: DateTime.now(),
      elapsed: sw.elapsed,
    );
  }

  static Future<CryptoOperationResult> _workerExecuteEncrypt({
    required String inputPath,
    required String outputPath,
    required String password,
    required void Function(double progress) onProgress,
  }) async {
    final sw = Stopwatch()..start();
    final inFile = File(inputPath);
    if (!await inFile.exists()) {
      return CryptoOperationResult(
        inputPath: inputPath,
        outputPath: outputPath,
        isSuccess: false,
        errorMessage: 'Source file does not exist',
        mode: CryptoMode.encrypt,
      );
    }

    final fileSize = await inFile.length();
    final fileName = inputPath.split(RegExp(r'[/\\]')).last;

    // 1. Generate Nonce & Salt
    final salt = _WindowsCng.instance.generateSecureBytes(16);
    final nonce = _WindowsCng.instance.generateSecureBytes(12);

    // 2. Build 2026 Header
    final header = _FcryHeader.createV1(
      salt: salt,
      nonce: nonce,
      originalFileSize: fileSize,
      originalFileName: fileName,
      iterations: 3,
      memoryKiB: 65536,
      parallelism: 4,
    );

    // 3. Derive 256-bit Key via Argon2id (OWASP 2026)
    final key = _deriveArgon2idKey(
      password: password,
      salt: salt,
      iterations: header.kdfIterations,
      memoryKiB: header.kdfMemoryKiB,
      parallelism: header.kdfParallelism,
      keyLength: 32,
    );

    // 4. Initialize AEAD AES-256-GCM with AAD binding
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      128, // 16 bytes tag (128 bits)
      nonce,
      header.rawHeaderBytes, // Header cryptographically bound as AAD
    );
    cipher.init(true, params);

    RandomAccessFile? inRaf;
    RandomAccessFile? outRaf;
    final outFile = File(outputPath);
    int processedBytes = 0;
    final inBuffer = Uint8List(_chunkSize);

    try {
      inRaf = await inFile.open(mode: FileMode.read);
      outRaf = await outFile.open(mode: FileMode.write);

      // Write unencrypted authenticated header
      await outRaf.writeFrom(header.rawHeaderBytes);

      while (processedBytes < fileSize) {
        final readBytes = await inRaf.readInto(inBuffer);
        if (readBytes == 0) break;

        final inChunk = Uint8List.sublistView(inBuffer, 0, readBytes);
        final outChunk = Uint8List(
          readBytes + 16,
        ); // Accommodate block buffering
        final outLen = cipher.processBytes(inChunk, 0, readBytes, outChunk, 0);

        if (outLen > 0) {
          await outRaf.writeFrom(outChunk, 0, outLen);
        }

        processedBytes += readBytes;
        if (fileSize > 0) {
          onProgress(processedBytes / fileSize);
        }
      }

      // Finalize cipher and write tag
      final finalBlock = Uint8List(32);
      final finalLen = cipher.doFinal(finalBlock, 0);
      if (finalLen > 0) {
        await outRaf.writeFrom(finalBlock, 0, finalLen);
      }
    } catch (e) {
      if (await outFile.exists()) {
        try {
          await outFile.delete();
        } catch (_) {}
      }
      return CryptoOperationResult(
        inputPath: inputPath,
        outputPath: outputPath,
        isSuccess: false,
        errorMessage: 'Encryption failed: $e',
        mode: CryptoMode.encrypt,
      );
    } finally {
      await inRaf?.close();
      await outRaf?.close();
    }

    sw.stop();

    return CryptoOperationResult(
      inputPath: inputPath,
      outputPath: outputPath,
      isSuccess: true,
      mode: CryptoMode.encrypt,
      bytesProcessed: fileSize,
      elapsed: sw.elapsed,
      kdfAlgorithm: KdfAlgorithm.argon2id,
      cipherAlgorithm: CipherAlgorithm.aes256Gcm,
    );
  }

  static Future<CryptoOperationResult> _workerExecuteDecrypt({
    required String inputPath,
    required String outputPath,
    required String password,
    required void Function(double progress) onProgress,
  }) async {
    final sw = Stopwatch()..start();
    final inFile = File(inputPath);
    if (!await inFile.exists()) {
      return CryptoOperationResult(
        inputPath: inputPath,
        outputPath: outputPath,
        isSuccess: false,
        errorMessage: 'Source file does not exist',
        mode: CryptoMode.decrypt,
      );
    }

    final totalFileSize = await inFile.length();
    if (totalFileSize < 28) {
      return CryptoOperationResult(
        inputPath: inputPath,
        outputPath: outputPath,
        isSuccess: false,
        errorMessage: 'File is too small to be a valid encrypted container',
        mode: CryptoMode.decrypt,
      );
    }

    RandomAccessFile? inRaf;
    try {
      inRaf = await inFile.open(mode: FileMode.read);
      final prefixBuffer = Uint8List(128);
      final prefixRead = await inRaf.readInto(prefixBuffer);
      await inRaf.setPosition(0);

      final header = _FcryHeader.tryParse(
        Uint8List.sublistView(prefixBuffer, 0, prefixRead),
      );

      if (header != null) {
        // --- MODERN FCRY v1 DECRYPTION ---
        return await _decryptFcryV1(
          inRaf: inRaf,
          header: header,
          totalFileSize: totalFileSize,
          inputPath: inputPath,
          outputPath: outputPath,
          password: password,
          onProgress: onProgress,
          stopwatch: sw,
        );
      } else {
        // --- BACKWARD COMPATIBLE LEGACY v0 DECRYPTION ---
        return await _decryptLegacyV0(
          inRaf: inRaf,
          totalFileSize: totalFileSize,
          inputPath: inputPath,
          outputPath: outputPath,
          password: password,
          onProgress: onProgress,
          stopwatch: sw,
        );
      }
    } catch (e) {
      await inRaf?.close();
      return CryptoOperationResult(
        inputPath: inputPath,
        outputPath: outputPath,
        isSuccess: false,
        errorMessage: 'Decryption initialization error: $e',
        mode: CryptoMode.decrypt,
      );
    }
  }

  static Future<CryptoOperationResult> _decryptFcryV1({
    required RandomAccessFile inRaf,
    required _FcryHeader header,
    required int totalFileSize,
    required String inputPath,
    required String outputPath,
    required String password,
    required void Function(double progress) onProgress,
    required Stopwatch stopwatch,
  }) async {
    final headerSize = header.rawHeaderBytes.length;
    final cipherPayloadSize = totalFileSize - headerSize;

    // Derive key
    final Uint8List key;
    if (header.kdf == KdfAlgorithm.argon2id) {
      key = _deriveArgon2idKey(
        password: password,
        salt: header.salt,
        iterations: header.kdfIterations,
        memoryKiB: header.kdfMemoryKiB,
        parallelism: header.kdfParallelism,
        keyLength: 32,
      );
    } else {
      key = _derivePbkdf2Key(
        password: password,
        salt: header.salt,
        iterations: header.kdfIterations,
        keyLength: 32,
      );
    }

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      128,
      header.nonce,
      header.rawHeaderBytes, // Authenticated AAD
    );
    cipher.init(false, params);

    await inRaf.setPosition(headerSize);

    final outFile = File(outputPath);
    RandomAccessFile? outRaf;
    int bytesReadTotal = 0;
    final inBuffer = Uint8List(_chunkSize);

    try {
      outRaf = await outFile.open(mode: FileMode.write);

      while (bytesReadTotal < cipherPayloadSize) {
        final remaining = cipherPayloadSize - bytesReadTotal;
        final toRead = min(remaining, _chunkSize);
        final readBytes = await inRaf.readInto(inBuffer, 0, toRead);
        if (readBytes == 0) break;

        final inChunk = Uint8List.sublistView(inBuffer, 0, readBytes);
        final outChunk = Uint8List(readBytes + 16);
        final outLen = cipher.processBytes(inChunk, 0, readBytes, outChunk, 0);

        if (outLen > 0) {
          await outRaf.writeFrom(outChunk, 0, outLen);
        }

        bytesReadTotal += readBytes;
        onProgress(bytesReadTotal / cipherPayloadSize);
      }

      final finalBlock = Uint8List(32);
      final finalLen = cipher.doFinal(finalBlock, 0);
      if (finalLen > 0) {
        await outRaf.writeFrom(finalBlock, 0, finalLen);
      }
    } on InvalidCipherTextException {
      if (await outFile.exists()) await outFile.delete();
      return CryptoOperationResult(
        inputPath: inputPath,
        outputPath: outputPath,
        isSuccess: false,
        errorMessage:
            'Decryption failed: Incorrect password or corrupted authentication tag.',
        mode: CryptoMode.decrypt,
      );
    } catch (e) {
      if (await outFile.exists()) await outFile.delete();
      final isAuthError =
          e.toString().contains('InvalidCipherTextException') ||
          e.toString().contains('mac check in GCM failed');
      return CryptoOperationResult(
        inputPath: inputPath,
        outputPath: outputPath,
        isSuccess: false,
        errorMessage: isAuthError
            ? 'Decryption failed: Incorrect password or corrupted data.'
            : 'Decryption error: $e',
        mode: CryptoMode.decrypt,
      );
    } finally {
      await inRaf.close();
      await outRaf?.close();
    }

    stopwatch.stop();

    return CryptoOperationResult(
      inputPath: inputPath,
      outputPath: outputPath,
      isSuccess: true,
      mode: CryptoMode.decrypt,
      bytesProcessed: totalFileSize,
      elapsed: stopwatch.elapsed,
      kdfAlgorithm: header.kdf,
      cipherAlgorithm: header.cipher,
    );
  }

  static Future<CryptoOperationResult> _decryptLegacyV0({
    required RandomAccessFile inRaf,
    required int totalFileSize,
    required String inputPath,
    required String outputPath,
    required String password,
    required void Function(double progress) onProgress,
    required Stopwatch stopwatch,
  }) async {
    const saltLength = 16;
    const nonceLength = 12;
    const tagLength = 16;
    const headerSize = saltLength + nonceLength;

    if (totalFileSize < headerSize + tagLength) {
      await inRaf.close();
      return CryptoOperationResult(
        inputPath: inputPath,
        outputPath: outputPath,
        isSuccess: false,
        errorMessage: 'Corrupt or truncated legacy encrypted file',
        mode: CryptoMode.decrypt,
      );
    }

    final headerBytes = Uint8List(headerSize);
    await inRaf.readInto(headerBytes);

    final salt = headerBytes.sublist(0, saltLength);
    final nonce = headerBytes.sublist(saltLength, headerSize);

    // Legacy 600k PBKDF2
    final key = _derivePbkdf2Key(
      password: password,
      salt: salt,
      iterations: 600000,
      keyLength: 32,
    );

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0));
    cipher.init(false, params);

    final payloadSize = totalFileSize - headerSize;
    final outFile = File(outputPath);
    RandomAccessFile? outRaf;
    int bytesReadTotal = 0;
    final inBuffer = Uint8List(_chunkSize);

    try {
      outRaf = await outFile.open(mode: FileMode.write);

      while (bytesReadTotal < payloadSize) {
        final remaining = payloadSize - bytesReadTotal;
        final toRead = min(remaining, _chunkSize);
        final readBytes = await inRaf.readInto(inBuffer, 0, toRead);
        if (readBytes == 0) break;

        final inChunk = Uint8List.sublistView(inBuffer, 0, readBytes);
        final outChunk = Uint8List(readBytes + 16);
        final outLen = cipher.processBytes(inChunk, 0, readBytes, outChunk, 0);

        if (outLen > 0) {
          await outRaf.writeFrom(outChunk, 0, outLen);
        }

        bytesReadTotal += readBytes;
        onProgress(bytesReadTotal / payloadSize);
      }

      final finalBlock = Uint8List(32);
      final finalLen = cipher.doFinal(finalBlock, 0);
      if (finalLen > 0) {
        await outRaf.writeFrom(finalBlock, 0, finalLen);
      }
    } on InvalidCipherTextException {
      if (await outFile.exists()) await outFile.delete();
      return CryptoOperationResult(
        inputPath: inputPath,
        outputPath: outputPath,
        isSuccess: false,
        errorMessage:
            'Decryption failed: Incorrect password or corrupted legacy data.',
        mode: CryptoMode.decrypt,
      );
    } catch (e) {
      if (await outFile.exists()) await outFile.delete();
      final isAuthError =
          e.toString().contains('InvalidCipherTextException') ||
          e.toString().contains('mac check in GCM failed');
      return CryptoOperationResult(
        inputPath: inputPath,
        outputPath: outputPath,
        isSuccess: false,
        errorMessage: isAuthError
            ? 'Decryption failed: Incorrect password or corrupted data.'
            : 'Decryption error: $e',
        mode: CryptoMode.decrypt,
      );
    } finally {
      await inRaf.close();
      await outRaf?.close();
    }

    stopwatch.stop();

    return CryptoOperationResult(
      inputPath: inputPath,
      outputPath: outputPath,
      isSuccess: true,
      mode: CryptoMode.decrypt,
      bytesProcessed: totalFileSize,
      elapsed: stopwatch.elapsed,
      kdfAlgorithm: KdfAlgorithm.pbkdf2Sha256,
      cipherAlgorithm: CipherAlgorithm.aes256Gcm,
    );
  }

  // --- KEY DERIVATION IMPLEMENTATIONS ---

  static Uint8List _deriveArgon2idKey({
    required String password,
    required Uint8List salt,
    required int iterations,
    required int memoryKiB,
    required int parallelism,
    required int keyLength,
  }) {
    final generator = Argon2BytesGenerator();
    final params = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      iterations: iterations,
      memory: memoryKiB,
      lanes: parallelism,
      desiredKeyLength: keyLength,
    );
    generator.init(params);

    final passBytes = Uint8List.fromList(utf8.encode(password));
    return generator.process(passBytes);
  }

  static Uint8List _derivePbkdf2Key({
    required String password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(salt, iterations, keyLength));
    final passBytes = Uint8List.fromList(utf8.encode(password));
    return derivator.process(passBytes);
  }
}

// ============================================================================
// 5. PUBLIC HIGH-LEVEL SERVICE INTERFACE
// ============================================================================

class FileCryptoService {
  final _WorkerIsolateManager _worker = _WorkerIsolateManager.instance;

  /// Hash a single file with both SHA-256 and SHA-512 in a single streaming pass.
  Future<FileHashResult> hashFile(
    String filePath, {
    void Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final response = await _worker.sendRequest(
      _IsolateCommandType.hashFile,
      inputPath: filePath,
      onProgress: onProgress,
    );

    if (response.isSuccess && response.result is FileHashResult) {
      return response.result as FileHashResult;
    } else {
      throw Exception(response.errorMessage ?? 'Hashing failed');
    }
  }

  /// Encrypt a single file using AES-256-GCM authenticated container with Argon2id KDF.
  Future<CryptoOperationResult> encryptFile({
    required String filePath,
    required String password,
    String? customOutputPath,
    void Function(double progress)? onProgress,
  }) async {
    final outputPath = customOutputPath ?? '$filePath.enc';

    final response = await _worker.sendRequest(
      _IsolateCommandType.encryptFile,
      inputPath: filePath,
      outputPath: outputPath,
      password: password,
      onProgress: onProgress,
    );

    if (response.result is CryptoOperationResult) {
      return response.result as CryptoOperationResult;
    }
    return CryptoOperationResult(
      inputPath: filePath,
      outputPath: outputPath,
      isSuccess: false,
      errorMessage: response.errorMessage ?? 'Encryption failed',
      mode: CryptoMode.encrypt,
    );
  }

  /// Decrypt a single file (.enc container) with automatic version detection.
  Future<CryptoOperationResult> decryptFile({
    required String filePath,
    required String password,
    String? customOutputPath,
    void Function(double progress)? onProgress,
  }) async {
    final outputPath = customOutputPath ?? getDecryptedPath(filePath);

    final response = await _worker.sendRequest(
      _IsolateCommandType.decryptFile,
      inputPath: filePath,
      outputPath: outputPath,
      password: password,
      onProgress: onProgress,
    );

    if (response.result is CryptoOperationResult) {
      return response.result as CryptoOperationResult;
    }
    return CryptoOperationResult(
      inputPath: filePath,
      outputPath: outputPath,
      isSuccess: false,
      errorMessage: response.errorMessage ?? 'Decryption failed',
      mode: CryptoMode.decrypt,
    );
  }

  /// Batch hashing with concurrent queue management and progress dispatch.
  Future<List<FileHashResult>> hashFilesBatch(
    List<String> filePaths, {
    void Function(String path, double progress)? onProgress,
    void Function(FileHashResult result)? onResult,
    void Function(String path, Object error)? onError,
  }) async {
    final results = <FileHashResult>[];
    for (final path in filePaths) {
      try {
        final res = await hashFile(
          path,
          onProgress: (p) => onProgress?.call(path, p),
        );
        results.add(res);
        onResult?.call(res);
      } catch (e) {
        onError?.call(path, e);
      }
    }
    return results;
  }

  /// Batch encryption with progress tracking.
  Future<List<CryptoOperationResult>> encryptFilesBatch(
    List<String> filePaths, {
    required String password,
    void Function(String path, double progress)? onProgress,
    void Function(CryptoOperationResult result)? onResult,
  }) async {
    final results = <CryptoOperationResult>[];
    for (final path in filePaths) {
      final res = await encryptFile(
        filePath: path,
        password: password,
        onProgress: (p) => onProgress?.call(path, p),
      );
      results.add(res);
      onResult?.call(res);
    }
    return results;
  }

  /// Batch decryption with progress tracking.
  Future<List<CryptoOperationResult>> decryptFilesBatch(
    List<String> filePaths, {
    required String password,
    void Function(String path, double progress)? onProgress,
    void Function(CryptoOperationResult result)? onResult,
  }) async {
    final results = <CryptoOperationResult>[];
    for (final path in filePaths) {
      final res = await decryptFile(
        filePath: path,
        password: password,
        onProgress: (p) => onProgress?.call(path, p),
      );
      results.add(res);
      onResult?.call(res);
    }
    return results;
  }

  /// Clean path resolver for decrypted output preserving base names and extensions.
  static String getDecryptedPath(String encPath) {
    var raw = encPath;
    if (raw.toLowerCase().endsWith('.enc')) {
      raw = raw.substring(0, raw.length - 4);
    }

    final sep = Platform.pathSeparator;
    final lastSep = raw.lastIndexOf(RegExp(r'[/\\]'));
    final dir = lastSep != -1 ? raw.substring(0, lastSep) : '';
    final filename = lastSep != -1 ? raw.substring(lastSep + 1) : raw;

    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex > 0) {
      final name = filename.substring(0, dotIndex);
      final ext = filename.substring(dotIndex);
      final outName = '${name}_decrypted$ext';
      return dir.isNotEmpty ? '$dir$sep$outName' : outName;
    }

    final outName = '${filename}_decrypted';
    return dir.isNotEmpty ? '$dir$sep$outName' : outName;
  }

  /// Export list of hash results to RFC 4180 compliant CSV formatted string
  String exportToCsv(
    List<FileHashResult> results, {
    bool includeFilePath = true,
  }) {
    final buffer = StringBuffer();
    if (includeFilePath) {
      buffer.writeln(
        'File Name,File Path,Size (Bytes),SHA-256,SHA-512,Processed At',
      );
      for (final r in results) {
        final cleanName = r.fileName.replaceAll('"', '""');
        final cleanPath = r.filePath.replaceAll('"', '""');
        buffer.writeln(
          '"$cleanName","$cleanPath",${r.fileSizeBytes},"${r.sha256}","${r.sha512}","${r.processedAt.toIso8601String()}"',
        );
      }
    } else {
      buffer.writeln('File Name,Size (Bytes),SHA-256,SHA-512,Processed At');
      for (final r in results) {
        final cleanName = r.fileName.replaceAll('"', '""');
        buffer.writeln(
          '"$cleanName",${r.fileSizeBytes},"${r.sha256}","${r.sha512}","${r.processedAt.toIso8601String()}"',
        );
      }
    }
    return buffer.toString();
  }

  /// Export list of hash results to JSON formatted string
  String exportToJson(
    List<FileHashResult> results, {
    bool includeFilePath = true,
  }) {
    const encoder = JsonEncoder.withIndent('  ');
    final mapped = results.map((r) {
      final json = r.toJson();
      if (!includeFilePath) {
        json.remove('filePath');
      }
      return json;
    }).toList();
    return encoder.convert(mapped);
  }

  /// Free worker isolate resources
  void dispose() {
    _worker.dispose();
  }
}

// ============================================================================
// 6. UTILITY CLASSES
// ============================================================================

/// A simple sink to capture the final computed Digest from chunked converters.
class _DigestSink implements Sink<crypto.Digest> {
  crypto.Digest? digest;

  @override
  void add(crypto.Digest d) => digest = d;

  @override
  void close() {}
}
