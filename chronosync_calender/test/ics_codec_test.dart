import 'package:flutter_test/flutter_test.dart';

import 'package:chronosync_calender/data/services/ics_codec.dart';

void main() {
  test('escape and unescape reverse each other', () {
    const original = 'Lunch; with Sara, at 1pm\nBring: notes \\ slash';
    expect(IcsCodec.unescape(IcsCodec.escape(original)), original);
  });

  test('folded lines are at most 75 bytes', () {
    final folded = IcsCodec.fold('SUMMARY:${'a' * 200}');
    for (final line in folded.split('\r\n')) {
      expect(line.length <= 75, isTrue);
    }
  });

  test('unfold restores a folded line exactly', () {
    final long = 'DESCRIPTION:${'word ' * 40}';
    expect(IcsCodec.unfold(IcsCodec.fold(long)).single, long);
  });

  test('parseLine reads the name, parameters and value', () {
    final p = IcsCodec.parseLine('DTSTART;TZID=Asia/Karachi:20261112T074000')!;
    expect(p.name, 'DTSTART');
    expect(p.params['TZID'], 'Asia/Karachi');
    expect(p.value, '20261112T074000');
  });
}
