import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Import utility files that actually exist
import 'package:saigonphantomlabs/mckimquyen/util/duration_util.dart';
import 'package:saigonphantomlabs/mckimquyen/util/validate_utils.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/dimen_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/color_constants.dart';

void main() {
  /// Test Suite cho DurationUtils
  group('DurationUtils Tests', () {
    test('should format seconds correctly', () {
      // Test formatSeconds method with various inputs
      expect(DurationUtils.formatSeconds(30), equals('00:00:00:30'));
      expect(DurationUtils.formatSeconds(90), equals('00:00:01:30')); // 1 minute 30 seconds
      expect(DurationUtils.formatSeconds(3661), equals('00:01:01:01')); // 1 hour 1 minute 1 second
      expect(DurationUtils.formatSeconds(0), equals('00:00:00:00'));
      expect(DurationUtils.formatSeconds(3600), equals('00:01:00:00')); // 1 hour
    });

    test('should format time correctly', () {
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;

      // Test formatTime method
      final result = DurationUtils.formatTime(timestamp, DurationUtils.FORMAT_1);
      expect(result, isA<String>());
      expect(result.isNotEmpty, true);

      // Test with different formats
      final result2 = DurationUtils.formatTime(timestamp, DurationUtils.FORMAT_2);
      expect(result2, isA<String>());
      expect(result2.isNotEmpty, true);

      // Test with null
      expect(DurationUtils.formatTime(null, DurationUtils.FORMAT_1), equals('Unknown'));
    });

    test('should get current time in HH:mm format', () {
      final currentTime = DurationUtils.nowHHmm();
      expect(currentTime, isA<String>());
      expect(currentTime.isNotEmpty, true);
      expect(currentTime.contains('/'), true); // Should contain date separators
    });

    test('should convert dates correctly', () {
      const testDate = '2023-04-07T23:21:13.048';
      final result = DurationUtils.convertDate(
        testDate,
        DurationUtils.FORMAT_T,
        DurationUtils.FORMAT_3,
      );

      expect(result, isA<String>());
      expect(result?.isNotEmpty, true);

      // Test with empty string
      expect(DurationUtils.convertDate('', DurationUtils.FORMAT_T, DurationUtils.FORMAT_3), equals(''));

      // Test with invalid date
      final invalidResult = DurationUtils.convertDate(
        'invalid-date',
        DurationUtils.FORMAT_T,
        DurationUtils.FORMAT_3,
      );
      expect(invalidResult, equals(''));
    });

    test('should handle time comparisons correctly', () {
      // Test with empty inputs
      expect(DurationUtils.isFutureTime('', ''), false);
      expect(DurationUtils.getTimeBetweenTargetAndNow('invalid', DurationUtils.FORMAT_T_Z), 0);

      // Test time difference calculation
      final timeDiff = DurationUtils.getTimeBetweenTargetAndNow(
        '2025-12-31T23:59:59.999Z',
        DurationUtils.FORMAT_T_Z,
      );
      expect(timeDiff, isA<int>());
    });

    test('should format ISO time correctly', () {
      final now = DateTime.now();
      final isoTime = DurationUtils.formatISOTime(now);

      expect(isoTime, isA<String>());
      expect(isoTime.contains('T'), true);
      expect(isoTime.contains('+') || isoTime.contains('-'), true); // Should contain timezone offset
    });

    test('should handle formatted dates', () {
      final now = DateTime.now();
      final formatted = DurationUtils.getFormattedDate(now);

      expect(formatted, isA<String>());
      expect(formatted.contains('/'), true);
      expect(formatted.split('/').length, 3); // Should be dd/MM/yyyy format
    });

    test('should parse string to DateTime', () {
      const dateString = '07/04/2023';
      const format = 'dd/MM/yyyy';

      final result = DurationUtils.stringToDateTime(dateString, format);
      expect(result, isA<DateTime>());
      expect(result?.year, 2023);
      expect(result?.month, 4);
      expect(result?.day, 7);

      // Test with invalid input
      final invalidResult = DurationUtils.stringToDateTime('invalid', format);
      expect(invalidResult, isNull);
    });

    test('should handle edge cases gracefully', () {
      // Test with extreme values
      expect(() => DurationUtils.formatSeconds(-30), returnsNormally);
      expect(() => DurationUtils.formatSeconds(999999), returnsNormally);

      // Test delay function
      expect(() => DurationUtils.delay(100, () {}), returnsNormally);

      // Test with very large timestamps
      expect(() => DurationUtils.formatTime(9999999999999, DurationUtils.FORMAT_1), returnsNormally);
    });
  });

  /// Test Suite cho ValidateUtils
  group('ValidateUtils Tests', () {
    test('should validate password correctly', () {
      // Valid passwords (must meet format requirements)
      expect(ValidateUtils.isValidPassword('Password123!'), true);
      expect(ValidateUtils.isValidPassword('MySecure1@'), true);
      expect(ValidateUtils.isValidPassword('ComplexPass1#'), true);

      // Invalid passwords - too short (assuming min length from DimenConstants)
      expect(ValidateUtils.isValidPassword('Pass1!'), false);
      expect(ValidateUtils.isValidPassword(''), false);

      // Invalid passwords - wrong format
      expect(ValidateUtils.isValidPassword('password123'), false); // No uppercase, no special char
      expect(ValidateUtils.isValidPassword('PASSWORD123'), false); // No lowercase, no special char
      expect(ValidateUtils.isValidPassword('Password'), false); // No number, no special char
      expect(ValidateUtils.isValidPassword('12345678'), false); // No letters, no special char
    });

    test('should validate password format correctly', () {
      // Valid format (uppercase, lowercase, number, special char, min 8 chars)
      expect(ValidateUtils.isValidPasswordFormat('Password123!'), true);
      expect(ValidateUtils.isValidPasswordFormat('MyTest1@'), true);
      expect(ValidateUtils.isValidPasswordFormat('Strong9#'), true);

      // Invalid format - missing requirements
      expect(ValidateUtils.isValidPasswordFormat('password123'), false); // No uppercase, no special char
      expect(ValidateUtils.isValidPasswordFormat('PASSWORD123'), false); // No lowercase, no special char
      expect(ValidateUtils.isValidPasswordFormat('Password'), false); // No number, no special char
      expect(ValidateUtils.isValidPasswordFormat('12345678'), false); // No letters, no special char
      expect(ValidateUtils.isValidPasswordFormat('Pass1!'), false); // Too short (less than 8 chars)
      expect(ValidateUtils.isValidPasswordFormat(''), false); // Empty
    });

    test('should validate password retype correctly', () {
      // Matching passwords
      expect(ValidateUtils.isValidPasswordRetype('Password123!', 'Password123!'), true);
      expect(ValidateUtils.isValidPasswordRetype('test', 'test'), true);
      expect(ValidateUtils.isValidPasswordRetype('', ''), true);

      // Non-matching passwords
      expect(ValidateUtils.isValidPasswordRetype('Password123!', 'Different123!'), false);
      expect(ValidateUtils.isValidPasswordRetype('test', 'Test'), false);
      expect(ValidateUtils.isValidPasswordRetype('password', ''), false);
      expect(ValidateUtils.isValidPasswordRetype('Password123!', 'Password123'), false);
    });

    test('should handle password edge cases', () {
      // Test with special Unicode characters
      expect(() => ValidateUtils.isValidPassword('Tëst123!'), returnsNormally);

      // Test with very long passwords
      final longPassword = 'A${'a' * 50}1${'!' * 10}';
      expect(() => ValidateUtils.isValidPassword(longPassword), returnsNormally);

      // Test retype with identical complex strings
      const complexPassword = 'Sup3r-C0mpl3x-P@ssw0rd!';
      expect(ValidateUtils.isValidPasswordRetype(complexPassword, complexPassword), true);

      // Test with whitespace (the regex pattern might allow spaces)
      expect(() => ValidateUtils.isValidPasswordFormat('Pass Word1!'), returnsNormally); // Contains space
      expect(ValidateUtils.isValidPasswordRetype('test ', 'test'), false); // Trailing space
    });

    test('should handle null-like and extreme inputs', () {
      // Test with string 'null'
      expect(ValidateUtils.isValidPasswordRetype('null', 'null'), true);

      // Test with very long mismatched passwords
      final longPassword1 = '${'A' * 1000}1!';
      final longPassword2 = '${'B' * 1000}1!';
      expect(ValidateUtils.isValidPasswordRetype(longPassword1, longPassword2), false);

      // Test password validation with extreme inputs
      expect(() => ValidateUtils.isValidPassword('A' * 10000), returnsNormally);
    });
  });

  /// Test Suite cho Constants
  group('Constants Tests', () {
    test('should have valid color constants', () {
      // Test that color constants are accessible and valid
      expect(ColorConstants.appColor, isA<Color>());
      expect(ColorConstants.backgroundColor, isA<Color>());
      expect(ColorConstants.gray, isA<Color>());
      expect(ColorConstants.red, isA<Color>());
      expect(ColorConstants.green, isA<Color>());

      // Colors should not be null
      expect(ColorConstants.appColor, isNotNull);
      expect(ColorConstants.backgroundColor, isNotNull);
      expect(ColorConstants.enableColor, isNotNull);
      expect(ColorConstants.disabledColor, isNotNull);
    });

    test('should have valid dimension constants', () {
      // Test that dimension constants exist and are reasonable
      expect(DimenConstants.minLengthPassword, isA<int>());
      expect(DimenConstants.minLengthPassword, greaterThan(0));
      expect(DimenConstants.minLengthPassword, lessThanOrEqualTo(50)); // Reasonable upper bound
    });

    test('should handle constants edge cases', () {
      // Test constants are consistent
      expect(() => DimenConstants.minLengthPassword.toString(), returnsNormally);
      expect(() => ColorConstants.appColor.toString(), returnsNormally);
      expect(() => ColorConstants.backgroundColor.toString(), returnsNormally);
    });
  });

  /// Test Suite cho Performance
  group('Utility Performance Tests', () {
    test('should handle rapid password validations efficiently', () {
      final stopwatch = Stopwatch()..start();

      // Perform many validations
      for (int i = 0; i < 1000; i++) {
        ValidateUtils.isValidPassword('TestPassword123!');
        ValidateUtils.isValidPasswordFormat('TestPassword123!');
        ValidateUtils.isValidPasswordRetype('test', 'test');
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should complete within 1 second
    });

    test('should handle rapid date formatting efficiently', () {
      final stopwatch = Stopwatch()..start();
      final now = DateTime.now();

      // Perform many date operations
      for (int i = 0; i < 100; i++) {
        DurationUtils.formatSeconds(i);
        DurationUtils.getFormattedDate(now);
        DurationUtils.formatTime(now.millisecondsSinceEpoch, DurationUtils.FORMAT_1);
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(500)); // Should complete within 500ms
    });
  });
}