import 'package:flutter_test/flutter_test.dart';
import 'package:aicalcapp/ai_count_history.dart';
import 'package:aicalcapp/ai_service.dart';

void main() {
  test(
    'AiCountResult totals multiple targets and builds an addition expression',
    () {
      const result = AiCountResult(
        items: [
          AiCountItem(target: 'りんご', count: 3, points: []),
          AiCountItem(target: 'みかん', count: 2, points: []),
        ],
      );

      expect(result.count, 5);
      expect(result.additionExpression, '3 + 2');
    },
  );

  test('AiCountHistoryEntry reads legacy single-target JSON', () {
    final entry = AiCountHistoryEntry.fromJson({
      'id': 'legacy',
      'instruction': 'ボルト',
      'count': 4,
      'points': [
        [0.25, 0.5],
      ],
      'dateTime': '2026-08-01T00:00:00.000Z',
      'imagePath': 'ai_count_history/legacy.jpg',
    });

    expect(entry.items, hasLength(1));
    expect(entry.items.single.target, 'ボルト');
    expect(entry.count, 4);
    expect(entry.points.single, [0.25, 0.5]);
  });

  test(
    'AiCountItem normalizes marker coordinates from both supported formats',
    () {
      final thousandScaleItem = AiCountItem.fromJson({
        'target': 'ボルト',
        'count': 2,
        'points': [
          [250, 750],
        ],
      });
      final normalizedItem = AiCountItem.fromJson({
        'target': 'ボルト',
        'count': 1,
        'points': [
          [0.25, 0.5],
        ],
      });

      expect(thousandScaleItem.points, [
        [0.25, 0.75],
      ]);
      expect(normalizedItem.points, [
        [0.25, 0.5],
      ]);
    },
  );
}
