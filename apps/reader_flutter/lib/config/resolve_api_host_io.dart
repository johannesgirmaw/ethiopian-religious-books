import 'dart:io';

/// First usable IPv4 for reaching Docker on the host when `127.0.0.1` is broken
/// (some macOS + VPN / Docker Desktop setups).
Future<String?> resolveApiHostForDesktop() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
    );
    const preferredNames = ['en0', 'en1', 'en2', 'en3', 'eth0'];
    for (final name in preferredNames) {
      for (final iface in interfaces) {
        if (iface.name != name) continue;
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    }
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.type != InternetAddressType.IPv4) continue;
        if (addr.isLoopback) continue;
        return addr.address;
      }
    }
  } on SocketException catch (_) {
    // Permission denied listing interfaces, etc.
  } catch (_) {}
  return null;
}
