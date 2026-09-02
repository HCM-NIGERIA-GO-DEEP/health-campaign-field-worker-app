// Importing necessary packages and files
import 'dart:io';

import "package:dio/dio.dart"; // Dio package for HTTP requests
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../security/security.dart';
import '../utils/environment_config.dart'; // Custom utility file for environment configurations
import 'repositories/api_interceptors.dart'; // Custom API interceptors for Dio

// The DioClient class for managing the Dio instance
class DioClient {
  late Dio _dio; // Private instance of Dio

  // Singleton instance of DioClient
  static final DioClient _instance = DioClient._internal();

  // Factory constructor for DioClient
  factory DioClient() {
    return _instance;
  }

  // Private constructor of DioClient
  DioClient._internal() {
    _init(); // Initialize the Dio client during construction
  }

  // Getter method to access the Dio instance
  Dio get dio => _dio;

  // Initialization method for the Dio client
  void _init() {
    _dio = Dio()
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          // SECURITY: Never disable certificate validation regardless of security level.
          // badCertificateCallback must always return false (reject bad certs).
          // SSL pinning is applied via enableSSLPinning() called during app startup.
          final client = HttpClient()
            ..badCertificateCallback =
                (X509Certificate cert, String host, int port) => false;
          return client;
        },
      )
      ..interceptors.addAll([
        AuthTokenInterceptor(),
        // Custom interceptor for handling authentication tokens
        ApiLoggerInterceptor(),
        // Custom interceptor for logging API requests and responses
      ])
      ..options = BaseOptions(
        connectTimeout: Duration(
          milliseconds: envConfig.variables.connectTimeout,
        ),
        sendTimeout: Duration(milliseconds: envConfig.variables.sendTimeout),
        receiveTimeout: Duration(
          milliseconds: envConfig.variables.receiveTimeout,
        ),
        baseUrl: envConfig.variables
            .baseUrl, // Base URL for API endpoints from the environment configuration
      );
  }

  // Enable SSL certificate pinning
  Future<void> enableSSLPinning() async {
    final pinnedClient = await SslPinning.createPinnedHttpClient(
      certificateAssetPath: 'assets/certificates/tls_cert.crt',
    );

    // Null means the sslPinning feature is not selected, so the default client
    // stays in place.
    if (pinnedClient == null) return;

    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return pinnedClient;
    };
  }

  // Disable SSL certificate pinning (use default system certificates)
  void disableSSLPinning() {
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient();
    };
    debugPrint('SSL Certificate Pinning disabled');
  }
}
