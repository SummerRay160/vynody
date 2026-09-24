import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vynody/player/audio/audio_riverpod.dart';
import 'package:vynody/player/pro/app_channel.dart';
import 'package:vynody/player/pro/pro_license_service.dart';
import 'package:vynody/player/pro/pro_models.dart';
import 'package:vynody/player/settings/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProLicenseService Tests', () {
    test('Default GitHub channel defaults to unlimitedCommunity', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ProLicenseService(prefs: prefs);

      // Default env is github
      if (AppChannel.isGitHubRelease) {
        expect(service.state.type, LicenseType.unlimitedCommunity);
        expect(service.state.isProUnlocked, isTrue);
      }
    });

    test('LicenseState models and trial calculations', () {
      final now = DateTime.now();
      final expire = now.add(const Duration(days: 10));

      final trialState = LicenseState(
        type: LicenseType.activeTrial,
        trialTotalDays: 15,
        trialDaysRemaining: 10,
        firstLaunchTime: now,
        trialExpireTime: expire,
      );

      expect(trialState.isInTrial, isTrue);
      expect(trialState.isProUnlocked, isTrue);
      expect(trialState.trialDaysRemaining, 10);

      final expiredState = LicenseState(
        type: LicenseType.expiredTrial,
        trialTotalDays: 15,
        trialDaysRemaining: 0,
        firstLaunchTime: now.subtract(const Duration(days: 16)),
        trialExpireTime: now.subtract(const Duration(days: 1)),
      );

      expect(expiredState.isTrialExpired, isTrue);
      expect(expiredState.isProUnlocked, isFalse);
    });

    test('ProFeature enum contains dynamicMeshBackground and customImageBackground', () {
      expect(ProFeature.values, contains(ProFeature.dynamicMeshBackground));
      expect(ProFeature.values, contains(ProFeature.customImageBackground));
      expect(ProFeature.dynamicMeshBackground.icon, isNotNull);
      expect(ProFeature.customImageBackground.icon, isNotNull);
    });

    test('Effective settings providers correctly gate features without altering persistent storage', () async {
      SharedPreferences.setMockInitialValues({
        'visualizer_enabled': true,
        'equalizer_enabled': true,
        'playback_background_type': 1, // dynamic mesh
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);

      // 1. Pro Unlocked container
      final unlockedContainer = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) => SettingsService(prefs)),
          isProUnlockedProvider.overrideWithValue(true),
        ],
      );

      expect(unlockedContainer.read(effectiveVisualizerEnabledProvider), isTrue);
      expect(unlockedContainer.read(effectiveEqualizerEnabledProvider), isTrue);
      expect(unlockedContainer.read(effectivePlaybackBackgroundTypeProvider), 1);

      // 2. Pro Locked container
      final lockedContainer = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) => SettingsService(prefs)),
          isProUnlockedProvider.overrideWithValue(false),
        ],
      );

      expect(lockedContainer.read(effectiveVisualizerEnabledProvider), isFalse);
      expect(lockedContainer.read(effectiveEqualizerEnabledProvider), isFalse);
      expect(lockedContainer.read(effectivePlaybackBackgroundTypeProvider), 0);

      // Verify underlying persistent storage remains unmodified
      expect(settings.isVisualizerEnabled, isTrue);
      expect(settings.equalizerEnabled, isTrue);
      expect(settings.playbackBackgroundType, 1);
      expect(prefs.getBool('visualizer_enabled'), isTrue);
      expect(prefs.getBool('equalizer_enabled'), isTrue);
      expect(prefs.getInt('playback_background_type'), 1);

      unlockedContainer.dispose();
      lockedContainer.dispose();
    });
  });
}

