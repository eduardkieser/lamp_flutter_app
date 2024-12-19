import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/lamp_service.dart';
import '../providers/lamp_provider.dart';
import 'home_screen.dart';

class DeviceSelectionScreen extends ConsumerStatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  ConsumerState<DeviceSelectionScreen> createState() =>
      _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends ConsumerState<DeviceSelectionScreen> {
  List<LampDevice>? _devices;
  bool _isSearching = false;

  Future<void> _searchDevices() async {
    setState(() {
      _isSearching = true;
      _devices = null;
    });

    try {
      final devices = await LampService.discoverLamps();
      setState(() {
        _devices = devices;
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _searchDevices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Lamp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isSearching ? null : _searchDevices,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching for lamps...'),
          ],
        ),
      );
    }

    if (_devices == null) {
      return const Center(child: Text('No devices found'));
    }

    if (_devices!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No lamps found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchDevices,
              child: const Text('Search Again'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _devices!.length,
      itemBuilder: (context, index) {
        final device = _devices![index];
        return ListTile(
          title: Text(device.name),
          subtitle: Text(device.address),
          onTap: () {
            ref.read(lampServiceProvider).setDevice(device);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          },
        );
      },
    );
  }
}
