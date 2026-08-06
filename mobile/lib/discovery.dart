import 'package:multicast_dns/multicast_dns.dart';

class DiscoveredService {
  DiscoveredService({required this.name, required this.ip, required this.port});

  final String name;
  final String ip;
  final int port;
}

class MdnsDiscovery {
  static const _serviceType = '_khsaetei._tcp.local';

  Future<List<DiscoveredService>> discover({Duration timeout = const Duration(seconds: 3)}) async {
    final client = MDnsClient();
    final results = <DiscoveredService>[];
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
    }
    return results;
  }
}
