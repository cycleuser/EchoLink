sealed class Result<T> {
  const Result();
  
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  
  T get data => (this as Success<T>).data;
  String get error => (this as Failure<T>).message;
  
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, {Exception? exception}) failure,
  }) {
    switch (this) {
      case Success<T> s:
        return success(s.data);
      case Failure<T> f:
        return failure(f.message, exception: f.exception);
    }
  }
  
  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success<T> s => Success(transform(s.data)),
      Failure<T> f => Failure(f.message, exception: f.exception),
    };
  }
  
  Result<R> flatMap<R>(Result<R> Function(T data) transform) {
    return switch (this) {
      Success<T> s => transform(s.data),
      Failure<T> f => Failure(f.message, exception: f.exception),
    };
  }
  
  T getOrElse(T defaultValue) {
    return switch (this) {
      Success<T> s => s.data,
      Failure<T> _ => defaultValue,
    };
  }
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
  
  @override
  String toString() => 'Success($data)';
}

final class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;
  
  const Failure(this.message, {this.exception});
  
  @override
  String toString() => 'Failure($message)';
}