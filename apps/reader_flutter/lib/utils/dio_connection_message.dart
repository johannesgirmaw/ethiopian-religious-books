import 'package:dio/dio.dart';

/// Short hint when the failure looks like reachability, not an API error body.
String? connectionTroubleshootHint(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return 'Request timed out. Check that the API is running and the URL is correct.';
    case DioExceptionType.connectionError:
      return 'Could not reach the server. Is the backend up and is API_BASE_URL correct for this device?';
    case DioExceptionType.badCertificate:
      return 'Secure connection failed (certificate).';
    case DioExceptionType.cancel:
      return null;
    case DioExceptionType.badResponse:
      return null;
    case DioExceptionType.unknown:
      final err = e.error;
      if (err != null) {
        final s = err.toString();
        if (s.contains('SocketException') ||
            s.contains('Failed host lookup') ||
            s.contains('Connection refused')) {
          return 'Could not reach the server. Is the backend up and is API_BASE_URL correct for this device?';
        }
      }
      return null;
  }
}
