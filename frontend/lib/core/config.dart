class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'MEMORA_API',
    defaultValue: 'https://memora-5byo.onrender.com',
  );
}