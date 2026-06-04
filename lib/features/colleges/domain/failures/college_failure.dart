class CollegeFailure implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const CollegeFailure(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => message;
}
