String changeInNotes(int change) {
  if (change == 0) return 'No change';

  final notes = [5000, 2000, 1000, 500, 100];
  final parts = <String>[];
  int left = change;

  for (var note in notes) {
    int count = left ~/ note;
    left = left % note;
    if (count > 0) parts.add('$note × $count');
  }
  return parts.join(' · ');
}
