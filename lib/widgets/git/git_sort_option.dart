enum GitSortOption {
  dateDesc('Date (Newest first)'),
  dateAsc('Date (Oldest first)'),
  additionsDesc('Additions (High to Low)'),
  additionsAsc('Additions (Low to High)'),
  deletionsDesc('Deletions (High to Low)'),
  deletionsAsc('Deletions (Low to High)');

  final String label;
  const GitSortOption(this.label);
}