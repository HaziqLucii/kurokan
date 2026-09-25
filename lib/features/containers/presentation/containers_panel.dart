import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_provider.dart';
import '../../../core/providers/registry_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/err_block.dart';
import '../../../shared/widgets/source_error_text.dart';
import '../../dashboard/panel_frame.dart';
import '../domain/container_status.dart';
import 'container_row.dart';
import 'containers_provider.dart';
import 'containers_skeleton.dart';

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

class ContainersPanel extends ConsumerWidget {
  final String sourceId;
  const ContainersPanel({super.key, required this.sourceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(containersProvider(sourceId));
    final config = ref.watch(appConfigProvider);
    final pollSeconds = config.pollInterval.inSeconds;
    final entry = config.containers.firstWhere((c) => c.id == sourceId);
    final tag =
        ref
            .watch(providerRegistryProvider)
            .containerSpec(entry.provider)
            ?.tag ??
        entry.provider.toUpperCase();

    final hasValue = async.hasValue;
    final hasError = async.hasError;
    final isLoading = async.isLoading;

    final String footerLeft;
    final String footerRight;
    final Widget body;
    var dimmed = false;

    if (isLoading && !hasValue) {
      footerLeft = 'Loading';
      footerRight = '—';
      body = const ContainersSkeleton();
    } else if (hasError && !hasValue) {
      footerLeft = 'Error · ${_time(clock.now())}';
      footerRight = 'Retry ${pollSeconds}s';
      body = ErrBlock(
        message: sourceErrorMessage(async.error, tag: tag),
        hint: 'Retry in ${pollSeconds}s',
      );
    } else {
      final sample = async.requireValue;
      final containers = sample.value;
      final running = containers
          .where((c) => c.state == ContainerState.running)
          .length;
      final exited = containers
          .where((c) => c.state == ContainerState.exited)
          .length;
      footerRight = '$running RUNNING · $exited EXITED';

      if (isLoading) {
        footerLeft = 'Refreshing';
      } else if (hasError) {
        dimmed = true;
        footerLeft =
            'Stale · Last ok ${_time(sample.fetchedAt)} · ${sourceErrorKind(async.error)}';
      } else {
        footerLeft = 'Fetched ${_time(sample.fetchedAt)}';
      }

      final now = clock.now();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContainersColumnHeader(
            line: context.tokens.line,
            faint: context.tokens.faint,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: containers.length,
              itemBuilder: (context, i) =>
                  ContainerRow(container: containers[i], now: now),
            ),
          ),
        ],
      );
    }

    return PanelFrame(
      title: 'Containers',
      tag: tag,
      body: body,
      footerLeft: footerLeft,
      footerRight: footerRight,
      dimmed: dimmed,
    );
  }
}
