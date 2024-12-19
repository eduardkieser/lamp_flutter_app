import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lamp_state.dart';
import '../services/lamp_service.dart';
import 'dart:async';

final lampServiceProvider = Provider((ref) => LampService());

final lampStateProvider =
    StateNotifierProvider<LampStateNotifier, AsyncValue<LampState>>((ref) {
  return LampStateNotifier(ref.watch(lampServiceProvider));
});

class LampStateNotifier extends StateNotifier<AsyncValue<LampState>> {
  final LampService _lampService;
  Timer? _retryTimer;
  Timer? _pollTimer;
  bool _isRetrying = false;
  static const _pollInterval =
      Duration(milliseconds: 333); // 3Hz to match slider

  LampStateNotifier(this._lampService) : super(const AsyncValue.loading()) {
    refreshState();
    // Start polling
    _startPolling();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      // Only poll if we're not in an error state
      if (state is! AsyncError) {
        refreshState();
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
    // Store the previous state in case of error
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
      // Revert to previous state on error
      state = previousState;
      // Don't throw, let the retry mechanism handle reconnection
    }
  }
}
