import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

enum AnimationSpeed {
  calm('Calm', 1.4),
  standard('Standard', 1.0),
  brisk('Brisk', 0.65),
  off('Off', 0.0);

  const AnimationSpeed(this.label, this.multiplier);
  final String label;

  /// Durations are multiplied by this. `off` collapses every animation to zero
  /// duration, which also covers the system "reduce motion" preference.
  final double multiplier;
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.animationSpeed = AnimationSpeed.standard,
    this.onboardingComplete = false,
  });

  final ThemeMode themeMode;
  final AnimationSpeed animationSpeed;
  final bool onboardingComplete;

  AppSettings copyWith({
    ThemeMode? themeMode,
    AnimationSpeed? animationSpeed,
    bool? onboardingComplete,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        animationSpeed: animationSpeed ?? this.animationSpeed,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      );
}

class SettingsRepository {
  SettingsRepository(this._prefs);
  final SharedPreferences _prefs;

  AppSettings read() => AppSettings(
        themeMode: ThemeMode.values[
            _prefs.getInt(StorageKeys.themeMode) ?? ThemeMode.system.index],
        animationSpeed: AnimationSpeed.values[
            _prefs.getInt(StorageKeys.animationSpeed) ??
                AnimationSpeed.standard.index],
        onboardingComplete:
            _prefs.getBool(StorageKeys.onboardingComplete) ?? false,
      );

  Future<void> write(AppSettings settings) async {
    await _prefs.setInt(StorageKeys.themeMode, settings.themeMode.index);
    await _prefs.setInt(
      StorageKeys.animationSpeed,
      settings.animationSpeed.index,
    );
    await _prefs.setBool(
      StorageKeys.onboardingComplete,
      settings.onboardingComplete,
    );
  }

  Future<void> clear() => _prefs.clear();
}
