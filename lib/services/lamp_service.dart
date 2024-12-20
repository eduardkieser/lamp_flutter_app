import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lamp_state.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LampDevice {
  final String name;
  final String address;
  final int port;

  LampDevice({
    required this.name,
    required this.address,
    required this.port,
  });

  String get url => 'http://$address:$port';
}

class LampService {
  LampDevice? _currentDevice;

  // Discover all smartlamps on the network
  static Future<List<LampDevice>> discoverLamps() async {
    if (kIsWeb) {
      // For web, return a hardcoded device for testing
      // or implement alternative discovery mechanism
      return [
        LampDevice(
          name: 'smartlamp',
          address: '192.168.1.xxx', // Replace with your lamp's IP
          port: 80,
        ),
      ];
    }

    final devices = <LampDevice>[];

    try {
      // Start mDNS discovery
      print('Starting mDNS discovery...');
      final MDnsClient client = MDnsClient();
      await client.start();

      // Search for HTTP services
      await for (final PtrResourceRecord ptr
          in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_http._tcp.local'),
      )) {
        if (ptr.domainName.contains('smartlamp')) {
          print('Found potential smartlamp: ${ptr.domainName}');

          // Get service details
          await for (final SrvResourceRecord srv
              in client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          )) {
            // Get IP address
            await for (final IPAddressResourceRecord ip
                in client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
            )) {
              devices.add(LampDevice(
                name: ptr.domainName.split('.').first,
                address: ip.address.address,
                port: srv.port,
              ));
              break; // Take first IP address
            }
            break; // Take first service record
          }
        }
      }

      client.stop();
      print('Found ${devices.length} smartlamps');
      return devices;
    } catch (e) {
      print('Error during mDNS discovery: $e');
      return [];
    }
  }

  // Set current device
  void setDevice(LampDevice device) {
    _currentDevice = device;
  }

  Future<LampState> getLampState() async {
    if (_currentDevice == null) {
      throw Exception('No lamp selected');
    }

    try {
      final response = await http.get(
        Uri.parse('${_currentDevice!.url}/api/status'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return LampState.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to load lamp state: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect to lamp: $e');
    }
  }

  Future<void> setBrightness(double brightness) async {
    if (_currentDevice == null) {
      throw Exception('No lamp selected');
    }

    try {
      final response = await http.post(
        Uri.parse('${_currentDevice!.url}/api/control'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {'brightness': brightness.toString()},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to set brightness: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to lamp: $e');
    }
  }
}
