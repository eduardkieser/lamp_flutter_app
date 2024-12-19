import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lamp_provider.dart';
import '../models/lamp_state.dart';
import 'dart:async';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _debounceTimer;
  double? _pendingValue;
  static const _updateInterval = Duration(milliseconds: 333); // ~3Hz

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleSliderChange(double value) {
    _pendingValue = value;

    // If no timer is active, update immediately and start the timer
    if (_debounceTimer == null) {
      ref.read(lampStateProvider.notifier).setBrightness(value);
      _debounceTimer = Timer.periodic(_updateInterval, (_) {
        if (_pendingValue != null) {
          ref.read(lampStateProvider.notifier).setBrightness(_pendingValue!);
          _pendingValue = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lampState = ref.watch(lampStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lamp Control'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDeviceInfo(lampState),
            const SizedBox(height: 20),
            _buildBrightnessControls(context, lampState),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfo(AsyncValue<LampState> lampState) {
    return lampState.when(
      data: (state) => Column(
        children: [
          Text(
            'Device: ${state.deviceName}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Battery: ${state.batteryVoltage.toStringAsFixed(2)}V',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      loading: () => const Column(
        children: [
          Text('Connecting...', style: TextStyle(fontSize: 16)),
          SizedBox(height: 8),
          LinearProgressIndicator(),
        ],
      ),
      error: (_, __) => const Column(
        children: [
          Text(
            'Connecting...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildBrightnessControls(
    BuildContext context,
    AsyncValue<LampState> lampState,
  ) {
    final bool isEnabled = lampState is AsyncData;
    final double currentValue = switch (lampState) {
      AsyncData(:final value) => value.brightness,
      _ => 0.0,
    };

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbColor: isEnabled ? null : Colors.grey,
            activeTrackColor: isEnabled ? null : Colors.grey.shade400,
            inactiveTrackColor: isEnabled ? null : Colors.grey.shade300,
          ),
          child: Slider(
            value: currentValue,
            min: 0,
            max: 100,
            onChanged: isEnabled ? _handleSliderChange : null,
          ),
        ),
        Text(
          'Brightness: ${currentValue.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 16,
            color: isEnabled ? null : Colors.grey,
          ),
        ),
      ],
    );
  }
}
