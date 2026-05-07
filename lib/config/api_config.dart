class ApiConfig {
  // For physical Android phone testing, use the laptop IPv4 address from ipconfig.
  // Do not use localhost, 127.0.0.1, or 10.0.2.2 on a physical phone.
  // Replace only the IPv4 part below if your laptop Wi-Fi address changes.
  static const String baseUrl = "http://10.0.2.2:5001";
}
