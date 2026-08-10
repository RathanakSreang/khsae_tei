import 'dart:io';

import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';

class DiscoveredService {
  DiscoveredService({required this.name, required this.ip, required this.port});

  final String name;
  final String ip;
  final int port;
}

class MdnsDiscovery {
  static const _serviceType = '_khsaetei._tcp.local';
  static const _lockChannel = MethodChannel('khsae_tei/multicast_lock');

  Future<List<DiscoveredService>> discover({Duration timeout = const Duration(seconds: 3)}) async {
    final client = MDnsClient(rawDatagramSocketFactory: _bindSocket);
    final results = <DiscoveredService>[];
    // Android silently drops incoming multicast (mDNS reply) packets over
    // WiFi unless a MulticastLock is held - without this, queries go out
    // fine but responses never arrive back. iOS has no such restriction and
    // no native handler for this channel, so skip it there.
    if (Platform.isAndroid) await _lockChannel.invokeMethod('acquire');
    await client.start();
    try {
      await for (final ptr in client
          .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(_serviceType))
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final srv in client
            .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
            .timeout(const Duration(seconds: 1), onTimeout: (sink) => sink.close())) {
          await for (final ip in client
              .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))
              .timeout(const Duration(seconds: 1), onTimeout: (sink) => sink.close())) {
            results.add(DiscoveredService(name: ptr.domainName, ip: ip.address.address, port: srv.port));
          }
        }
      }
    } finally {
      client.stop();
      if (Platform.isAndroid) await _lockChannel.invokeMethod('release');
    }
    return results;
  }

  // MDnsClient always requests reusePort: true, but iOS rejects SO_REUSEPORT
  // and throws "Address already in use" (errno 48) on bind - only one
  // discover() call runs at a time in this app, so reusePort isn't needed
  // there anyway.
  static Future<RawDatagramSocket> _bindSocket(
    dynamic host,
    int port, {
    bool reuseAddress = true,
    bool reusePort = true,
    int ttl = 1,
  }) {
    return RawDatagramSocket.bind(host, port, reuseAddress: reuseAddress, reusePort: reusePort && !Platform.isIOS, ttl: ttl);
  }
}
