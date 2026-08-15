class GitCommitFile {
  final String path;
  final int additions;
  final int deletions;
  final bool isBinary;
  final String status;

  const GitCommitFile({
    required this.path,
    required this.additions,
    required this.deletions,
    this.isBinary = false,
    this.status = 'M',
  });

  String get fileName {
    final segments = path.split(RegExp(r'[/\\]'));
    return segments.isNotEmpty ? segments.last : path;
  }

  String get extension {
    final name = fileName;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex != -1 ? name.substring(dotIndex) : '';
  }
}

class GitCommit {
  final String hash;
  final String shortHash;
  final String author;
  final DateTime date;
  final String relativeDate;
  final String message;
  final String? description;
  final List<GitCommitFile> files;
  final String? commitUrl;
  final List<String> parentHashes;

  const GitCommit({
    required this.hash,
    required this.shortHash,
    required this.author,
    required this.date,
    required this.relativeDate,
    required this.message,
    this.description,
    required this.files,
    this.commitUrl,
    this.parentHashes = const [],
  });

  bool get isMerge => parentHashes.length > 1;

  int get totalAdditions =>
      files.fold<int>(0, (sum, file) => sum + file.additions);

  int get totalDeletions =>
      files.fold<int>(0, (sum, file) => sum + file.deletions);

  GitCommit copyWith({
    String? hash,
    String? shortHash,
    String? author,
    DateTime? date,
    String? relativeDate,
    String? message,
    String? description,
    List<GitCommitFile>? files,
    String? commitUrl,
    List<String>? parentHashes,
  }) {
    return GitCommit(
      hash: hash ?? this.hash,
      shortHash: shortHash ?? this.shortHash,
      author: author ?? this.author,
      date: date ?? this.date,
      relativeDate: relativeDate ?? this.relativeDate,
      message: message ?? this.message,
      description: description ?? this.description,
      files: files ?? this.files,
      commitUrl: commitUrl ?? this.commitUrl,
      parentHashes: parentHashes ?? this.parentHashes,
    );
  }
}
