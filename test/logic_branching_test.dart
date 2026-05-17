import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Logical Formula Branching Evaluation Tests', () {
    // Core comparison logic helper mimicking the evaluation algorithm
    bool evaluateCondition(double val1, String operator, double val2) {
      switch (operator) {
        case '<':
          return val1 < val2;
        case '<=':
          return val1 <= val2;
        case '==':
          return (val1 - val2).abs() < 1e-9;
        case '!=':
          return (val1 - val2).abs() >= 1e-9;
        case '>':
          return val1 > val2;
        case '>=':
          return val1 >= val2;
        default:
          return false;
      }
    }

    double evaluateLogicLink({
      required bool isExpressionTrue,
      required double trueVal,
      required double falseVal,
    }) {
      return isExpressionTrue ? trueVal : falseVal;
    }

    test('evaluateCondition returns true/false correctly for operators', () {
      expect(evaluateCondition(5.0, '<', 10.0), isTrue);
      expect(evaluateCondition(10.0, '<', 5.0), isFalse);

      expect(evaluateCondition(5.0, '<=', 5.0), isTrue);
      expect(evaluateCondition(6.0, '<=', 5.0), isFalse);

      expect(evaluateCondition(5.0, '==', 5.0000000001), isTrue); // Close enough
      expect(evaluateCondition(5.0, '==', 6.0), isFalse);

      expect(evaluateCondition(5.0, '!=', 6.0), isTrue);
      expect(evaluateCondition(5.0, '!=', 5.0), isFalse);

      expect(evaluateCondition(10.0, '>', 5.0), isTrue);
      expect(evaluateCondition(5.0, '>', 10.0), isFalse);

      expect(evaluateCondition(5.0, '>=', 5.0), isTrue);
      expect(evaluateCondition(4.0, '>=', 5.0), isFalse);
    });

    test('evaluateLogicLink chooses trueVal or falseVal based on conditional outcome', () {
      final trueVal = 42.0;
      final falseVal = -7.0;

      // When condition evaluates to true, output should be trueVal
      final resTrue = evaluateLogicLink(
        isExpressionTrue: evaluateCondition(5.0, '<', 10.0),
        trueVal: trueVal,
        falseVal: falseVal,
      );
      expect(resTrue, equals(42.0));

      // When condition evaluates to false, output should be falseVal
      final resFalse = evaluateLogicLink(
        isExpressionTrue: evaluateCondition(10.0, '<', 5.0),
        trueVal: trueVal,
        falseVal: falseVal,
      );
      expect(resFalse, equals(-7.0));
    });
  });
}
