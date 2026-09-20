import 'package:flutter_test/flutter_test.dart';
import 'package:vynody/utils/app_proxy_manager.dart';

void main() {
  group('AppProxyManager', () {
    late AppProxyManager manager;

    setUp(() {
      manager = AppProxyManager.instance;
      manager.updateSettings(
        mode: AppProxyMode.system,
        customHost: '127.0.0.1',
        customPort: 7890,
        customBypass: 'localhost, 127.0.0.1, <local>',
      );
    });

    test('AppProxyMode.fromString parses correctly', () {
      expect(AppProxyMode.fromString('direct'), equals(AppProxyMode.direct));
      expect(AppProxyMode.fromString('custom'), equals(AppProxyMode.custom));
      expect(AppProxyMode.fromString('system'), equals(AppProxyMode.system));
      expect(AppProxyMode.fromString('unknown'), equals(AppProxyMode.system));
      expect(AppProxyMode.fromString(null), equals(AppProxyMode.system));
    });

    test('Direct mode always returns DIRECT', () {
      manager.updateSettings(mode: AppProxyMode.direct);

      expect(
        manager.resolveProxyRuleSync(Uri.parse('https://api.musicbrainz.org')),
        equals('DIRECT'),
      );
      expect(
        manager.resolveProxyRuleSync(Uri.parse('http://example.com/test.mp3')),
        equals('DIRECT'),
      );
    });

    test('Custom mode returns formatted proxy rule', () {
      manager.updateSettings(
        mode: AppProxyMode.custom,
        customHost: '127.0.0.1',
        customPort: 7890,
        customBypass: '',
      );

      final rule = manager.resolveProxyRuleSync(
        Uri.parse('https://api.musicbrainz.org'),
      );
      expect(rule, equals('PROXY 127.0.0.1:7890; DIRECT'));
    });

    test('Custom mode normalizes proxy address input', () {
      manager.updateSettings(
        mode: AppProxyMode.custom,
        customHost: 'http://192.168.1.100/',
        customPort: 8888,
        customBypass: '',
      );

      final rule = manager.resolveProxyRuleSync(
        Uri.parse('https://api.musicbrainz.org'),
      );
      expect(rule, equals('PROXY 192.168.1.100:8888; DIRECT'));
    });

    test('Custom mode fallback to DIRECT when host is empty or port invalid', () {
      manager.updateSettings(
        mode: AppProxyMode.custom,
        customHost: '',
        customPort: 7890,
      );
      expect(
        manager.resolveProxyRuleSync(Uri.parse('https://example.com')),
        equals('DIRECT'),
      );

      manager.updateSettings(
        mode: AppProxyMode.custom,
        customHost: '127.0.0.1',
        customPort: 0,
      );
      expect(
        manager.resolveProxyRuleSync(Uri.parse('https://example.com')),
        equals('DIRECT'),
      );
    });

    test('Custom mode respects bypass rules', () {
      manager.updateSettings(
        mode: AppProxyMode.custom,
        customHost: '127.0.0.1',
        customPort: 7890,
        customBypass: 'localhost; 127.0.0.1; *.internal.net; <local>',
      );

      // Localhost bypass
      expect(
        manager.resolveProxyRuleSync(Uri.parse('http://localhost:8080/api')),
        equals('DIRECT'),
      );
      expect(
        manager.resolveProxyRuleSync(Uri.parse('http://127.0.0.1:9000/stream')),
        equals('DIRECT'),
      );

      // <local> bypass (host without dot)
      expect(
        manager.resolveProxyRuleSync(Uri.parse('http://myserver:5000/stream')),
        equals('DIRECT'),
      );

      // Subdomain wildcard bypass
      expect(
        manager.resolveProxyRuleSync(Uri.parse('https://music.internal.net/audio')),
        equals('DIRECT'),
      );

      // Non-bypassed external host
      expect(
        manager.resolveProxyRuleSync(Uri.parse('https://subsonic.remote.com/rest')),
        equals('PROXY 127.0.0.1:7890; DIRECT'),
      );
    });

    test('updateSettings triggers onProxyChanged and updates properties', () {
      bool called = false;
      manager.onProxyChanged = () {
        called = true;
      };

      manager.updateSettings(
        mode: AppProxyMode.custom,
        customHost: '10.0.0.1',
        customPort: 1080,
      );

      expect(called, isTrue);
      expect(manager.mode, equals(AppProxyMode.custom));
      expect(manager.customHost, equals('10.0.0.1'));
      expect(manager.customPort, equals(1080));
    });

    test('resolveProxyRule asynchronous method caches lookups', () async {
      manager.updateSettings(
        mode: AppProxyMode.custom,
        customHost: '127.0.0.1',
        customPort: 7890,
        customBypass: '',
      );

      final uri = Uri.parse('https://musicbrainz.org/ws/2/recording');
      final rule1 = await manager.resolveProxyRule(uri);
      final rule2 = await manager.resolveProxyRule(uri);

      expect(rule1, equals('PROXY 127.0.0.1:7890; DIRECT'));
      expect(rule2, equals('PROXY 127.0.0.1:7890; DIRECT'));
    });

    test('resolveProxyRuleSync does not cause recursion or stack overflow in system mode', () {
      manager.updateSettings(mode: AppProxyMode.system);
      final rule = manager.resolveProxyRuleSync(Uri.parse('https://demo.navidrome.org/rest/ping.view'));
      expect(rule, isNotEmpty);
    });
  });
}
