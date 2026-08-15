import '../../models/fs_node.dart';

class LanguageStats {
  final String language;
  final List<FsNode> files;
  int lines = 0;
  int code = 0;
  int comments = 0;
  int blanks = 0;
  int bytes = 0;

  LanguageStats({required this.language, List<FsNode>? files})
    : files = files ?? [];
}

String mapLanguage(String ext) {
  switch (ext.toLowerCase()) {
    case '.dart':
      return 'Dart';
    case '.cpp':
    case '.cc':
    case '.cxx':
      return 'C++';
    case '.h':
    case '.hpp':
      return 'C Header';
    case '.c':
      return 'C';
    case '.js':
    case '.mjs':
    case '.cjs':
      return 'JavaScript';
    case '.ts':
      return 'TypeScript';
    case '.jsx':
      return 'JSX';
    case '.tsx':
      return 'TSX';
    case '.json':
      return 'JSON';
    case '.html':
    case '.htm':
      return 'HTML';
    case '.css':
    case '.scss':
    case '.less':
      return 'CSS';
    case '.yaml':
    case '.yml':
      return 'YAML';
    case '.md':
    case '.markdown':
      return 'Markdown';
    case '.py':
      return 'Python';
    case '.rs':
      return 'Rust';
    case '.go':
      return 'Go';
    case '.java':
      return 'Java';
    case '.cs':
      return 'C#';
    case '.kt':
      return 'Kotlin';
    case '.swift':
      return 'Swift';
    case '.sh':
    case '.ps1':
    case '.bat':
      return 'Shell Script';
    case '.xml':
      return 'XML';
    case 'cmakelists.txt':
    default:
      return ext.isEmpty
          ? 'Plain Text'
          : ext.toUpperCase().replaceAll('.', '');
  }
}