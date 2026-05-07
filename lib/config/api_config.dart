class ApiConfig {
  // Android emulator loopback.
  static const String emulatorBaseUrl = 'http://10.0.2.2:5001';

  // Laptop Wi-Fi IPv4 from ipconfig for real phone testing on the same network.
  static const String phoneBaseUrl = 'http://192.168.8.5:5001';

  // Switch this to emulatorBaseUrl when testing on the Android emulator.
  static const String baseUrl = phoneBaseUrl;
}
