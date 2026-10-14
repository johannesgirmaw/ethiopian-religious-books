import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app_update_exception.dart';

const _updaterChannel = MethodChannel('com.felegemetsahft/updater');

/// Downloads [url] into the temp directory and reports 0–1 progress.
///
/// [onProgress] receives null when the server does not send a length.
Future<String> downloadAppUpdate(
  String url, {
  required void Function(double? progress) onProgress,
}) async {
  final name = _fileName(url);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  if (await file.exists()) await file.delete();

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 15),
      followRedirects: true,
    ),
  );
  await dio.download(
    url,
    file.path,
    onReceiveProgress: (received, total) {
      if (total <= 0) {
        onProgress(null);
      } else {
        onProgress(received / total);
      }
    },
  );
  if (!await file.exists() || await file.length() == 0) {
    throw const AppUpdateFailed();
  }
  return file.path;
}

/// Installs a file already downloaded by [downloadAppUpdate].
///
/// Android and Windows keep this process alive until the system installer
/// takes over. macOS and Linux hand the swap to a helper, then exit so the
/// running files can be replaced and the new copy opened.
Future<void> applyDownloadedUpdate(String path) async {
  if (Platform.isAndroid) {
    await _installAndroid(path);
    return;
  }
  if (Platform.isWindows) {
    await _installWindows(path);
    return;
  }
  if (Platform.isMacOS) {
    final bundle = _macAppBundle();
    if (!await _canWrite(bundle.parent)) {
      throw const AppUpdateNotWritable();
    }
    await _spawnHelper(_macScript, [path, bundle.path]);
    exit(0);
  }
  if (Platform.isLinux) {
    final exe = Platform.resolvedExecutable;
    if (!await _canWrite(File(exe).parent)) {
      throw const AppUpdateNotWritable();
    }
    await _spawnHelper(_linuxScript, [path, exe]);
    exit(0);
  }
  throw const AppUpdateFailed();
}

Future<void> _installAndroid(String path) async {
  try {
    await _updaterChannel.invokeMethod<void>('installApk', {'path': path});
  } on PlatformException catch (error) {
    if (error.code == 'need_permission') {
      throw const AppUpdateNeedPermission();
    }
    throw const AppUpdateFailed();
  }
}

Future<void> _installWindows(String path) async {
  final dir = await getTemporaryDirectory();
  final script = File(
    '${dir.path}${Platform.pathSeparator}fm-apply-update.ps1',
  );
  await script.writeAsString(_windowsScript);
  await Process.start('powershell', [
    '-NoProfile',
    '-WindowStyle',
    'Hidden',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    script.path,
    path,
  ], mode: ProcessStartMode.detached);
}

Future<void> _spawnHelper(String body, List<String> args) async {
  final dir = await getTemporaryDirectory();
  final script = File('${dir.path}/fm-apply-update.sh');
  await script.writeAsString(body);
  await Process.start('/bin/bash', [
    script.path,
    '$pid',
    ...args,
  ], mode: ProcessStartMode.detached);
}

Future<bool> _canWrite(Directory dir) async {
  final probe = File('${dir.path}${Platform.pathSeparator}.fm_update_probe');
  try {
    await probe.writeAsString('1');
    await probe.delete();
    return true;
  } catch (_) {
    return false;
  }
}

Directory _macAppBundle() {
  final bundle = File(Platform.resolvedExecutable).parent.parent.parent;
  if (!bundle.path.endsWith('.app')) {
    throw const AppUpdateFailed();
  }
  return bundle;
}

String _fileName(String url) {
  final segments = Uri.parse(url).pathSegments;
  final name = segments.isEmpty ? '' : segments.last;
  if (name.isEmpty || name.contains('..') || name.contains('/')) {
    throw const AppUpdateFailed();
  }
  return name;
}

const _macScript = r'''#!/bin/bash
set -euo pipefail
PID="$1"
DMG="$2"
DEST="$3"
case "$DEST" in
  *.app) ;;
  *) exit 1 ;;
esac
while kill -0 "$PID" 2>/dev/null; do
  sleep 0.3
done
sleep 0.6
xattr -dr com.apple.quarantine "$DMG" || true
MNT=$(mktemp -d /tmp/fm-update-mount.XXXXXX)
cleanup() { hdiutil detach "$MNT" >/dev/null 2>&1 || true; rm -rf "$MNT"; }
trap cleanup EXIT
hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$DMG"
APP=$(find "$MNT" -name '*.app' -maxdepth 2 -print -quit)
if [ -z "$APP" ]; then
  exit 1
fi
rm -rf "$DEST"
ditto "$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" || true
open "$DEST" || true
''';

const _linuxScript = r'''#!/bin/bash
set -euo pipefail
PID="$1"
ARCHIVE="$2"
DEST="$3"
case "$DEST" in
  /*/*) ;;
  *) exit 1 ;;
esac
while kill -0 "$PID" 2>/dev/null; do
  sleep 0.3
done
sleep 0.6
WORKDIR=$(mktemp -d /tmp/fm-update.XXXXXX)
tar -xzf "$ARCHIVE" -C "$WORKDIR"
SRC=$(find "$WORKDIR" -type f -name "$(basename "$DEST")" -print -quit)
if [ -z "$SRC" ]; then
  exit 1
fi
cp -a "$(dirname "$SRC")/." "$(dirname "$DEST")/"
chmod +x "$DEST" || true
cd "$(dirname "$DEST")"
nohup "./$(basename "$DEST")" >/dev/null 2>&1 &
disown || true
rm -rf "$WORKDIR"
''';

const _windowsScript = r'''
param([Parameter(Mandatory = $true)][string]$Installer)
$ErrorActionPreference = 'Continue'
Start-Process -FilePath $Installer -ArgumentList '/SILENT','/NORESTART' -Wait
$key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8F3A1C2E-5B4D-4E6F-9A7B-2C1D3E4F5A6B}_is1'
$loc = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).InstallLocation
if (-not $loc) { exit 0 }
$exe = Join-Path $loc 'ethiopian_reader.exe'
if (Test-Path $exe) { Start-Process -FilePath $exe }
''';
