import 'app_update_exception.dart';

Future<String> downloadAppUpdate(
  String url, {
  required void Function(double? progress) onProgress,
}) async {
  throw const AppUpdateFailed();
}

Future<void> applyDownloadedUpdate(String path) async {
  throw const AppUpdateFailed();
}
