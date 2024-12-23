import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lamp_provider.dart';
import '../models/lamp_state.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import '../models/lamp_log_entry.dart';
import 'package:collection/collection.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _debounceTimer;
  double? _pendingValue;
  bool _isSliding = false;
  static const _updateInterval = Duration(milliseconds: 333); // ~3Hz

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleSliderChange(double value) {
    _isSliding = true;
    _pendingValue = value;
    ref.read(lampStateProvider.notifier).pausePolling();
    setState(() {});

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_updateInterval, () {
      if (_pendingValue != null) {
        ref.read(lampStateProvider.notifier).setBrightness(_pendingValue!);
        _pendingValue = null;
        _isSliding = false;
        ref.read(lampStateProvider.notifier).resumePolling();
        setState(() {});
      }
    });
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
      AsyncData(:final value) =>
        _isSliding ? (_pendingValue ?? value.brightness) : value.brightness,
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

  Widget _buildGraphs(AsyncValue<LampState> lampState) {
    if (lampState case AsyncData(value: final state)) {
      return FutureBuilder<List<LampLogEntry>>(
        future: ref.read(lampLogServiceProvider(state.deviceName)).getLogs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final logs = snapshot.data!;
          if (logs.isEmpty) return const Text('No data logged yet');

          return Column(
            children: [
              const SizedBox(height: 20),
              _buildChart(
                'Battery Voltage',
                logs,
                (entry) => entry.batteryVoltage,
                Colors.blue,
              ),
              const SizedBox(height: 20),
              _buildChart(
                'Brightness',
                logs,
                (entry) => entry.brightness,
                Colors.orange,
              ),
            ],
          );
        },
      );
    }
    return const SizedBox();
  }

  Widget _buildChart(
    String title,
    List<LampLogEntry> logs,
    double Function(LampLogEntry) getValue,
    Color color,
  ) {
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          Text(title),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: logs.mapIndexed((index, entry) {
                      return FlSpot(index.toDouble(), getValue(entry));
                    }).toList(),
                    isCurved: true,
                    color: color,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lampState = ref.watch(lampStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lamp Control'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDeviceInfo(lampState),
              const SizedBox(height: 20),
              _buildBrightnessControls(context, lampState),
              _buildGraphs(lampState),
            ],
          ),
        ),
      ),
    );
  }
}
