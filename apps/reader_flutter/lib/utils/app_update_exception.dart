/// The download finished, but this device cannot apply it.
sealed class AppUpdateException implements Exception {
  const AppUpdateException();
}

/// Android blocked the install until the user allows this app as a source.
class AppUpdateNeedPermission extends AppUpdateException {
  const AppUpdateNeedPermission();
}

/// macOS or Linux install folder is not writable by the current user.
class AppUpdateNotWritable extends AppUpdateException {
  const AppUpdateNotWritable();
}

class AppUpdateFailed extends AppUpdateException {
  const AppUpdateFailed();
}
