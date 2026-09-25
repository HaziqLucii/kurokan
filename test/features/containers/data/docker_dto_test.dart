import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/features/containers/data/docker_dto.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/docker/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('DockerContainerSummaryDTO', () {
    test('strips the leading slash from the first name', () {
      final list =
          jsonDecode(
                File(
                  'test/fixtures/docker/containers_json.json',
                ).readAsStringSync(),
              )
              as List;
      final summaries = list
          .cast<Map<String, dynamic>>()
          .map(DockerContainerSummaryDTO.fromJson)
          .toList();

      expect(summaries, hasLength(4));
      expect(summaries.map((s) => s.name).toSet(), {
        'setup',
        'migrate',
        'api',
        'web',
      });
      final web = summaries.firstWhere((s) => s.name == 'web');
      expect(web.image, 'nginx:alpine');
      expect(web.state, 'running');
    });

    test('falls back to the id when Names is empty', () {
      final dto = DockerContainerSummaryDTO.fromJson({
        'Id': 'abc123',
        'Names': <String>[],
        'Image': 'x',
        'State': 'running',
      });
      expect(dto.name, 'abc123');
    });
  });

  group('DockerContainerInspectDTO', () {
    test('parses a running, healthy container', () {
      final dto = DockerContainerInspectDTO.fromJson(
        _fixture('inspect_running'),
      );
      expect(dto.restartCount, 2);
      expect(dto.healthStatus, 'healthy');
      expect(dto.startedAt, isNotNull);
    });

    test('healthStatus is null when the container has no healthcheck', () {
      final dto = DockerContainerInspectDTO.fromJson(
        _fixture('inspect_running_no_health'),
      );
      expect(dto.healthStatus, isNull);
      expect(dto.startedAt, isNotNull);
    });

    test('a never-started container (the Go zero-time sentinel) has a null '
        'startedAt, not a timestamp in the year 1', () {
      final dto = DockerContainerInspectDTO.fromJson(
        _fixture('inspect_created'),
      );
      expect(dto.startedAt, isNull);
    });

    test('an exited container still has a real startedAt', () {
      final dto = DockerContainerInspectDTO.fromJson(
        _fixture('inspect_exited'),
      );
      expect(dto.startedAt, isNotNull);
      expect(dto.healthStatus, isNull);
    });

    test('RestartCount defaults to 0 when absent', () {
      final dto = DockerContainerInspectDTO.fromJson({
        'State': {'StartedAt': '0001-01-01T00:00:00Z'},
      });
      expect(dto.restartCount, 0);
    });
  });

  group('DockerStatsDTO', () {
    test('computes CPU% from the used/precpu/system deltas, and mem from '
        'usage minus inactive_file', () {
      final dto = DockerStatsDTO.fromJson(_fixture('stats'));
      expect(dto.cpuPercent, closeTo(20.0, 0.01));
      expect(dto.memUsed, 962560 - 4096);
      expect(dto.memLimit, 8393605120);
    });

    test('a stopped container (empty memory_stats, no system_cpu_usage) '
        'yields null cpuPercent/memUsed/memLimit, not a crash', () {
      final dto = DockerStatsDTO.fromJson(_fixture('stats_stopped'));
      expect(dto.cpuPercent, isNull);
      expect(dto.memUsed, isNull);
      expect(dto.memLimit, isNull);
    });

    test('a Podman zero-precpu response yields a null cpuPercent (not a '
        'huge/garbage percent from dividing by the whole-lifetime usage), '
        'and mem falls back to the legacy cache key when inactive_file is '
        'absent', () {
      final dto = DockerStatsDTO.fromJson(_fixture('stats_podman_zero_precpu'));
      expect(dto.cpuPercent, isNull);
      expect(dto.memUsed, 52428800 - 1048576);
      expect(dto.memLimit, 1073741824);
    });

    test('a zero system_cpu_usage delta yields a null cpuPercent, not a '
        'divide-by-zero', () {
      final json = {
        'cpu_stats': {
          'cpu_usage': {'total_usage': 100},
          'system_cpu_usage': 1000,
          'online_cpus': 4,
        },
        'precpu_stats': {
          'cpu_usage': {'total_usage': 50},
          'system_cpu_usage': 1000,
        },
        'memory_stats': <String, dynamic>{},
      };
      expect(DockerStatsDTO.fromJson(json).cpuPercent, isNull);
    });

    test('mem falls back to usage alone (no offset) when neither '
        'inactive_file nor cache is present', () {
      final json = {
        'cpu_stats': <String, dynamic>{},
        'precpu_stats': <String, dynamic>{},
        'memory_stats': {'usage': 1000, 'limit': 2000},
      };
      expect(DockerStatsDTO.fromJson(json).memUsed, 1000);
    });
  });
}
