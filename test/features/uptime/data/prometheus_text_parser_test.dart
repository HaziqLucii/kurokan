import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/features/uptime/data/prometheus_text_parser.dart';
import 'package:kurokan/features/uptime/domain/monitor_status.dart';

void main() {
  final parser = PrometheusMetricsParser();

  group('against the real captured fixture', () {
    final body = File(
      'test/fixtures/uptime_kuma_metrics.txt',
    ).readAsStringSync();
    final result = parser.parse(body);
    final monitors = result.monitors;

    test(
      'extracts exactly the monitor_* rows, ignoring process_*/nodejs_*/app_version',
      () {
        expect(monitors, hasLength(4));
        expect(monitors.map((m) => m.name).toSet(), {
          'Service A',
          'Service B',
          'Service C',
          'Service D',
        });
      },
    );

    test(
      'joins families by the full label set (this Kuma instance has no monitor_id label)',
      () {
        final serviceB = monitors.firstWhere((m) => m.name == 'Service B');
        expect(serviceB.id, isNotEmpty);
        expect(serviceB.type, 'http');
        expect(serviceB.state, MonitorState.up);
        expect(serviceB.responseTime, const Duration(milliseconds: 112));
        expect(serviceB.certDaysRemaining, 39);
        expect(serviceB.certValid, isTrue);
      },
    );

    test(
      'uptime24h is null when monitor_uptime_ratio is absent from the body',
      () {
        for (final m in monitors) {
          expect(m.uptime24h, isNull);
        }
      },
    );

    test('hasIds/hasUptime are both false: this real 1.23.17 capture has '
        'neither monitor_id nor monitor_uptime_ratio', () {
      expect(result.hasIds, isFalse);
      expect(result.hasUptime, isFalse);
    });
  });

  group('synthetic edge cases', () {
    test(
      'unescapes \\" and \\\\ in label values and joins by monitor_name',
      () {
        const body = '''
monitor_status{monitor_name="Weird \\"Name\\" \\\\ Test",monitor_type="port"} 0
monitor_response_time{monitor_name="Weird \\"Name\\" \\\\ Test",monitor_type="port"} -1
''';
        final monitors = parser.parse(body).monitors;
        expect(monitors, hasLength(1));
        expect(monitors.single.name, 'Weird "Name" \\ Test');
        expect(monitors.single.state, MonitorState.down);
      },
    );

    test('treats -1 response time as null', () {
      const body = '''
monitor_status{monitor_name="X",monitor_type="http"} 1
monitor_response_time{monitor_name="X",monitor_type="http"} -1
''';
      expect(parser.parse(body).monitors.single.responseTime, isNull);
    });

    test('treats empty string and literal "null" labels as absent', () {
      const body = '''
monitor_status{monitor_name="X",monitor_type="http",monitor_hostname="null",monitor_port=""} 1
''';
      // absent labels simply aren't surfaced on the model; this should not throw
      // and should still resolve the monitor by name.
      expect(parser.parse(body).monitors.single.name, 'X');
    });

    test('maps status codes to the right MonitorState', () {
      const body = '''
monitor_status{monitor_name="Up",monitor_type="http"} 1
monitor_status{monitor_name="Down",monitor_type="http"} 0
monitor_status{monitor_name="Pending",monitor_type="http"} 2
monitor_status{monitor_name="Maint",monitor_type="http"} 3
''';
      final byName = {
        for (final m in parser.parse(body).monitors) m.name: m.state,
      };
      expect(byName['Up'], MonitorState.up);
      expect(byName['Down'], MonitorState.down);
      expect(byName['Pending'], MonitorState.pending);
      expect(byName['Maint'], MonitorState.maintenance);
    });

    test('takes the window="1d" uptime ratio and puts 30d/365d in extra', () {
      const body = '''
monitor_status{monitor_name="X",monitor_type="http"} 1
monitor_uptime_ratio{monitor_name="X",monitor_type="http",window="1d"} 0.9998
monitor_uptime_ratio{monitor_name="X",monitor_type="http",window="30d"} 0.5
monitor_uptime_ratio{monitor_name="X",monitor_type="http",window="365d"} 0.25
''';
      final m = parser.parse(body).monitors.single;
      expect(m.uptime24h, 0.9998);
      expect(m.extra, {'uptime_30d': '0.5', 'uptime_365d': '0.25'});
    });

    test('flags an invalid or soon-expiring cert', () {
      const body = '''
monitor_status{monitor_name="X",monitor_type="http"} 1
monitor_cert_days_remaining{monitor_name="X",monitor_type="http"} 6
monitor_cert_is_valid{monitor_name="X",monitor_type="http"} 0
''';
      final m = parser.parse(body).monitors.single;
      expect(m.certDaysRemaining, 6);
      expect(m.certValid, isFalse);
    });

    test('ignores comment lines and non-monitor metrics', () {
      const body = '''
# HELP process_cpu_seconds_total Total CPU time
# TYPE process_cpu_seconds_total counter
process_cpu_seconds_total 123.45
monitor_status{monitor_name="X",monitor_type="http"} 1
''';
      expect(parser.parse(body).monitors, hasLength(1));
    });

    test(
      'a Kuma instance with zero monitors but real process_*/nodejs_* lines returns an empty list',
      () {
        const body = '''
# HELP process_cpu_seconds_total Total CPU time
# TYPE process_cpu_seconds_total counter
process_cpu_seconds_total 123.45
''';
        expect(parser.parse(body).monitors, isEmpty);
      },
    );

    test(
      'throws FormatException on a body with no recognizable Prometheus lines at all',
      () {
        // e.g. kuma.url pointing at the wrong host, a captive portal, or an
        // HTML error page answering with 200 instead of the real /metrics body.
        const body = '<html><body>Not Found</body></html>';
        expect(() => parser.parse(body), throwsFormatException);
      },
    );

    test(
      'keeps duplicate monitor names as separate rows when their label sets differ',
      () {
        const body = '''
monitor_status{monitor_name="API",monitor_type="http",monitor_url="https://a.example.tld/"} 1
monitor_status{monitor_name="API",monitor_type="http",monitor_url="https://b.example.tld/"} 0
''';
        final monitors = parser.parse(body).monitors;
        expect(monitors, hasLength(2));
        expect(monitors.map((m) => m.state).toSet(), {
          MonitorState.up,
          MonitorState.down,
        });
        expect(monitors.map((m) => m.id).toSet(), hasLength(2));
      },
    );

    test('groups by monitor_id when present, not the full label set', () {
      const body = '''
monitor_status{monitor_id="7",monitor_name="X",monitor_type="http",monitor_url="https://a.example.tld/"} 1
monitor_response_time{monitor_id="7",monitor_name="X",monitor_type="http",monitor_url="https://b.example.tld/"} 42
''';
      final result = parser.parse(body);
      expect(result.monitors, hasLength(1));
      expect(result.monitors.single.id, '7');
      expect(
        result.monitors.single.responseTime,
        const Duration(milliseconds: 42),
      );
      expect(result.hasIds, isTrue);
    });

    test('prefers the monitor_status series\' name/type when a renamed '
        'monitor leaves a stale orphan series sharing the same id', () {
      const body = '''
monitor_response_time{monitor_id="7",monitor_name="Old Name (stale)",monitor_type="http"} 200
monitor_status{monitor_id="7",monitor_name="New Name",monitor_type="port"} 1
''';
      final m = parser.parse(body).monitors.single;
      expect(m.name, 'New Name');
      expect(m.type, 'port');
      // Data from the orphan series still merges into the same monitor.
      expect(m.responseTime, const Duration(milliseconds: 200));
    });

    test('a NaN value (double.tryParse("NaN") succeeds in Dart) is ignored, '
        'not stored as a NaN percent/duration', () {
      const body = '''
monitor_status{monitor_name="X",monitor_type="http"} 1
monitor_response_time{monitor_name="X",monitor_type="http"} NaN
monitor_uptime_ratio{monitor_name="X",monitor_type="http",window="1d"} NaN
''';
      final m = parser.parse(body).monitors.single;
      expect(m.responseTime, isNull);
      expect(m.uptime24h, isNull);
    });

    test('a tag label on a monitor line does not affect grouping', () {
      const body = '''
monitor_status{monitor_name="X",monitor_type="http",tag_slug="production"} 1
monitor_response_time{monitor_name="X",monitor_type="http",tag_slug="production"} 10
''';
      expect(parser.parse(body).monitors, hasLength(1));
    });

    test(
      'monitor_response_time_seconds is ignored; monitor_response_time (ms) wins',
      () {
        const body = '''
monitor_status{monitor_name="X",monitor_type="http"} 1
monitor_response_time{monitor_name="X",monitor_type="http"} 112
monitor_response_time_seconds{monitor_name="X",monitor_type="http"} 0.112
''';
        final m = parser.parse(body).monitors.single;
        expect(m.responseTime, const Duration(milliseconds: 112));
      },
    );

    test('hasUptime is false when no monitor_uptime_ratio line is present', () {
      const body = '''
monitor_status{monitor_name="X",monitor_type="http"} 1
''';
      expect(parser.parse(body).hasUptime, isFalse);
    });

    test('hasIds/hasUptime against the v2 fixture (monitor_id, three windows, '
        'a tag label, a NaN)', () {
      final body = File(
        'test/fixtures/uptime_kuma_metrics_v2.txt',
      ).readAsStringSync();
      final result = parser.parse(body);

      expect(result.hasIds, isTrue);
      expect(result.hasUptime, isTrue);
      expect(result.monitors, isNotEmpty);
      for (final m in result.monitors) {
        expect(m.id, isNotEmpty);
      }
    });
  });
}
