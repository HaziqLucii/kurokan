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
    final monitors = parser.parse(body);

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
  });

  group('synthetic edge cases', () {
    test(
      'unescapes \\" and \\\\ in label values and joins by monitor_name',
      () {
        const body = '''
monitor_status{monitor_name="Weird \\"Name\\" \\\\ Test",monitor_type="port"} 0
monitor_response_time{monitor_name="Weird \\"Name\\" \\\\ Test",monitor_type="port"} -1
''';
        final monitors = parser.parse(body);
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
      expect(parser.parse(body).single.responseTime, isNull);
    });

    test('treats empty string and literal "null" labels as absent', () {
      const body = '''
monitor_status{monitor_name="X",monitor_type="http",monitor_hostname="null",monitor_port=""} 1
''';
      // absent labels simply aren't surfaced on the model; this should not throw
      // and should still resolve the monitor by name.
      expect(parser.parse(body).single.name, 'X');
    });

    test('maps status codes to the right MonitorState', () {
      const body = '''
monitor_status{monitor_name="Up",monitor_type="http"} 1
monitor_status{monitor_name="Down",monitor_type="http"} 0
monitor_status{monitor_name="Pending",monitor_type="http"} 2
monitor_status{monitor_name="Maint",monitor_type="http"} 3
''';
      final byName = {for (final m in parser.parse(body)) m.name: m.state};
      expect(byName['Up'], MonitorState.up);
      expect(byName['Down'], MonitorState.down);
      expect(byName['Pending'], MonitorState.pending);
      expect(byName['Maint'], MonitorState.maintenance);
    });

    test('takes only the window="1d" uptime ratio, ignoring 30d/365d', () {
      const body = '''
monitor_status{monitor_name="X",monitor_type="http"} 1
monitor_uptime_ratio{monitor_name="X",monitor_type="http",window="1d"} 0.9998
monitor_uptime_ratio{monitor_name="X",monitor_type="http",window="30d"} 0.5
''';
      expect(parser.parse(body).single.uptime24h, 0.9998);
    });

    test('flags an invalid or soon-expiring cert', () {
      const body = '''
monitor_status{monitor_name="X",monitor_type="http"} 1
monitor_cert_days_remaining{monitor_name="X",monitor_type="http"} 6
monitor_cert_is_valid{monitor_name="X",monitor_type="http"} 0
''';
      final m = parser.parse(body).single;
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
      expect(parser.parse(body), hasLength(1));
    });

    test(
      'a Kuma instance with zero monitors but real process_*/nodejs_* lines returns an empty list',
      () {
        const body = '''
# HELP process_cpu_seconds_total Total CPU time
# TYPE process_cpu_seconds_total counter
process_cpu_seconds_total 123.45
''';
        expect(parser.parse(body), isEmpty);
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
        final monitors = parser.parse(body);
        expect(monitors, hasLength(2));
        expect(monitors.map((m) => m.state).toSet(), {
          MonitorState.up,
          MonitorState.down,
        });
        expect(monitors.map((m) => m.id).toSet(), hasLength(2));
      },
    );
  });
}
