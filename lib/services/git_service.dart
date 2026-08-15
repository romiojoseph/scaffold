import 'dart:convert';
import 'dart:io';
import '../models/git_commit.dart';

class GitService {
  const GitService();

  Future<bool> isGitRepository(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return false;

    final dotGit = Directory('${dir.path}${Platform.pathSeparator}.git');
    if (await dotGit.exists()) return true;

    try {
      final result = await Process.run(
        'git',
        ['rev-parse', '--is-inside-work-tree'],
        workingDirectory: directoryPath,
      );
      return result.exitCode == 0 &&
          result.stdout.toString().trim() == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<String?> getRemoteOriginUrl(String directoryPath) async {
    try {
      final result = await Process.run(
        'git',
        ['config', '--get', 'remote.origin.url'],
        workingDirectory: directoryPath,
      );
      if (result.exitCode == 0) {
        final url = result.stdout.toString().trim();
        if (url.isNotEmpty) return url;
      }
    } catch (_) {}
    return null;
  }

  String? buildCommitUrl(String? remoteUrl, String commitHash) {
    if (remoteUrl == null || remoteUrl.trim().isEmpty) return null;
    var url = remoteUrl.trim();

    // SSH to HTTPS conversion: git@host:owner/repo.git -> https://host/owner/repo
    if (url.startsWith('git@')) {
      final match = RegExp(r'^git@([^:]+):(.+)$').firstMatch(url);
      if (match != null) {
        final host = match.group(1);
        final path = match.group(2);
        url = 'https://$host/$path';
      }
    }

    // Strip trailing .git
    if (url.endsWith('.git')) {
      url = url.substring(0, url.length - 4);
    }

    if (url.contains('gitlab.com')) {
      return '$url/-/commit/$commitHash';
    } else if (url.contains('bitbucket.org')) {
      return '$url/commits/$commitHash';
    } else if (url.contains('azure.com') || url.contains('visualstudio.com')) {
      return '$url/commit/$commitHash';
    } else {
      // GitHub / default
      return '$url/commit/$commitHash';
    }
  }

  Future<List<GitCommit>> getCommitHistory(
    String directoryPath, {
    int? maxCount,
  }) async {
    final isRepo = await isGitRepository(directoryPath);
    if (!isRepo) return [];

    final remoteUrl = await getRemoteOriginUrl(directoryPath);

    try {
      final args = <String>[
        'log',
        if (maxCount != null) ...['-n', '$maxCount'],
        '--raw',
        '--numstat',
        '--pretty=format:COMMIT_RECORD_START\x1f%H\x1f%h\x1f%an\x1f%aI\x1f%ar\x1f%s\x1f%P\x1f%b\x1e',
      ];

      final result = await Process.run(
        'git',
        args,
        workingDirectory: directoryPath,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      if (result.exitCode != 0) {
        return [];
      }

      final output = result.stdout.toString();
      return _parseGitLogOutput(output, remoteUrl);
    } catch (_) {
      return [];
    }
  }

  List<GitCommit> _parseGitLogOutput(String output, String? remoteUrl) {
    final rawChunks = output.split('COMMIT_RECORD_START\x1f');
    final commits = <GitCommit>[];

    for (final rawChunk in rawChunks) {
      final chunk = rawChunk.trim();
      if (chunk.isEmpty) continue;

      final recordParts = chunk.split('\x1e');
      final metaPart = recordParts[0];
      final diffPart = recordParts.length > 1 ? recordParts[1] : '';

      final fields = metaPart.split('\x1f');
      if (fields.length < 6) continue;

      final hash = fields[0].trim();
      final shortHash = fields[1].trim();
      final author = fields[2].trim();
      final date = DateTime.tryParse(fields[3].trim()) ?? DateTime.now();
      final relativeDate = fields[4].trim();
      final message = fields[5].trim();
      final rawParents = fields.length > 6 ? fields[6].trim() : '';
      final parentHashes = rawParents.isNotEmpty
          ? rawParents.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList()
          : <String>[];
      final rawDesc = fields.length > 7 ? fields.sublist(7).join('\x1f').trim() : '';
      final description = rawDesc.isNotEmpty ? rawDesc : null;

      final statusMap = <String, String>{};
      final files = <GitCommitFile>[];
      final lines = LineSplitter.split(diffPart);

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        // Parse --raw status line: :100644 100644 sha sha (STATUS)\tpath
        if (trimmedLine.startsWith(':')) {
          final tabParts = line.split('\t');
          if (tabParts.length >= 2) {
            final metaTokens = tabParts[0].trim().split(RegExp(r'\s+'));
            final statusToken = metaTokens.isNotEmpty ? metaTokens.last : 'M';
            final statusLetter = statusToken.isNotEmpty ? statusToken[0].toUpperCase() : 'M';
            final rawPath = tabParts.last.trim();
            statusMap[rawPath] = statusLetter;
            if (tabParts.length > 2) {
              statusMap[tabParts[1].trim()] = statusLetter;
            }
          }
          continue;
        }

        // Parse --numstat line: adds\tdels\tpath
        final parts = line.split('\t');
        if (parts.length >= 3) {
          final addsStr = parts[0].trim();
          final delsStr = parts[1].trim();
          final filePath = parts.sublist(2).join('\t').trim();

          final isBinary = addsStr == '-' || delsStr == '-';
          final additions = int.tryParse(addsStr) ?? 0;
          final deletions = int.tryParse(delsStr) ?? 0;

          // Lookup status from raw map, or infer from adds/dels or rename syntax
          String fileStatus = statusMap[filePath] ?? 'M';
          if (statusMap.containsKey(filePath)) {
            fileStatus = statusMap[filePath]!;
          } else if (filePath.contains(' => ')) {
            fileStatus = 'R';
          } else if (additions > 0 && deletions == 0) {
            fileStatus = 'A';
          } else if (deletions > 0 && additions == 0) {
            fileStatus = 'D';
          }

          files.add(
            GitCommitFile(
              path: filePath,
              additions: additions,
              deletions: deletions,
              isBinary: isBinary,
              status: fileStatus,
            ),
          );
        }
      }

      final commitUrl = buildCommitUrl(remoteUrl, hash);
      commits.add(
        GitCommit(
          hash: hash,
          shortHash: shortHash,
          author: author,
          date: date,
          relativeDate: relativeDate,
          message: message,
          description: description,
          files: List.unmodifiable(files),
          commitUrl: commitUrl,
          parentHashes: parentHashes,
        ),
      );
    }

    return commits;
  }
}
