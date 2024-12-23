import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lamp_state.dart';
import '../services/lamp_service.dart';
import 'dart:async';
import '../models/lamp_log_entry.dart';
import '../services/lamp_log_service.dart';

final lampServiceProvider = Provider((ref) => LampService());

final lampStateProvider =
    StateNotifierProvider<LampStateNotifier, AsyncValue<LampState>>((ref) {
  final lampService = ref.watch(lampServiceProvider);
  final deviceId = lampService.getCurrentDevice()?.name ?? 'unknown';
  return LampStateNotifier(
    lampService,
    deviceId,
    ref.watch(lampLogServiceProvider(deviceId)),
  );
});

final lampLogServiceProvider = Provider.family<LampLogService, String>(
  (ref, deviceId) => LampLogService(deviceId),
);

class LampStateNotifier extends StateNotifier<AsyncValue<LampState>> {
  final LampService _lampService;
  Timer? _retryTimer;
  Timer? _pollTimer;
  bool _isRetrying = false;
  static const _pollInterval =
      Duration(milliseconds: 333); // 3Hz to match slider
  static const _logInterval = Duration(seconds: 10);
  Timer? _logTimer;
  final String deviceId;
  final LampLogService _logService;
  bool _isPaused = false;

  LampStateNotifier(this._lampService, this.deviceId, this._logService)
      : super(const AsyncValue.loading()) {
    refreshState();
    // Start polling
    _startPolling();
    _startLogging();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _pollTimer?.cancel();
    _logTimer?.cancel();
    super.dispose();
  }

  void pausePolling() {
    _isPaused = true;
  }

  void resumePolling() {
    _isPaused = false;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      // Only poll if we're not paused and not in an error state
      if (!_isPaused && state is! AsyncError) {
        refreshState();
      }
    });
  }

  void _startLogging() {
    _logTimer?.cancel();
    _logTimer = Timer.periodic(_logInterval, (_) {
      if (state case AsyncData(value: final currentState)) {
        _logService.addEntry(LampLogEntry(
          timestamp: DateTime.now(),
          batteryVoltage: currentState.batteryVoltage,
          brightness: currentState.brightness,
        ));
      }
    });
  }

  Future<void> refreshState() async {
    try {
      final lampState = await _lampService.getLampState();

      // Only update state if value has changed
      if (state case AsyncData(value: final currentState)) {
        if (currentState.brightness != lampState.brightness ||
            currentState.batteryVoltage != lampState.batteryVoltage) {
          state = AsyncData(lampState);
        }
      } else {
        state = AsyncData(lampState);
      }

      _isRetrying = false;
      _retryTimer?.cancel();

      // Ensure polling is active
      if (_pollTimer == null || !_pollTimer!.isActive) {
        _startPolling();
      }
    } catch (e) {
      // If we don't have any data yet, show loading
      state = state.whenData((value) => value).isLoading
          ? const AsyncValue.loading()
          : state;

      // Start retry timer if not already retrying
      if (!_isRetrying) {
        _isRetrying = true;
        _retryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          refreshState();
        });
      }
    }
  }

  Future<void> setBrightness(double brightness) async {
    final previousState = state;

    try {
      // Optimistically update the UI
      if (state case AsyncData(value: final currentState)) {
        state = AsyncData(LampState(
          brightness: brightness,
          batteryVoltage: currentState.batteryVoltage,
          deviceName: currentState.deviceName,
        ));
      }

      await _lampService.setBrightness(brightness);
      await refreshState();
    } catch (e) {
      state = previousState;
    }
  }
}
