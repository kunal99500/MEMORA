class ApiConfig {
  /// Point this at your running backend.
  /// Flutter web / desktop on the same machine → http://127.0.0.1:8000
  /// Android emulator → http://10.0.2.2:8000
  static const String baseUrl =
      String.fromEnvironment('MEMORA_API', defaultValue: 'http://127.0.0.1:8000');
}
