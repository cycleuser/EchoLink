import 'package:flutter_test/flutter_test.dart';
import 'package:echolink/core/result.dart';

void main() {
  group('Result', () {
    test('should create success result', () {
      final result = Success<int>(42);

      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.data, 42);
    });

    test('should create failure result', () {
      final result = Failure<int>('Something went wrong');

      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(result.error, 'Something went wrong');
    });

    test('should map success result', () {
      final result = Success<int>(10);
      final mapped = result.map((data) => data * 2);

      expect(mapped.isSuccess, true);
      expect(mapped.data, 20);
    });

    test('should not map failure result', () {
      final result = Failure<int>('Error');
      final mapped = result.map((data) => data * 2);

      expect(mapped.isFailure, true);
      expect(mapped.error, 'Error');
    });

    test('should flatMap success result', () {
      final result = Success<int>(10);
      final flatMapped = result.flatMap((data) => Success<String>('Value: $data'));

      expect(flatMapped.isSuccess, true);
      expect(flatMapped.data, 'Value: 10');
    });

    test('should use when for pattern matching', () {
      final success = Success<int>(42);
      final failure = Failure<int>('Error');

      final successResult = success.when(
        success: (data) => 'Success: $data',
        failure: (msg, {exception}) => 'Failure: $msg',
      );

      final failureResult = failure.when(
        success: (data) => 'Success: $data',
        failure: (msg, {exception}) => 'Failure: $msg',
      );

      expect(successResult, 'Success: 42');
      expect(failureResult, 'Failure: Error');
    });

    test('should getOrElse for default value', () {
      final success = Success<int>(42);
      final failure = Failure<int>('Error');

      expect(success.getOrElse(0), 42);
      expect(failure.getOrElse(0), 0);
    });
  });
}