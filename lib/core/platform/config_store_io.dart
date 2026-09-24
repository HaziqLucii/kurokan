import 'dart:async';
import 'dart:io';

abstract interface class ConfigStore {
  String get path;
  String get dir;
  void ensureDir();
  bool exists();
  String read();
  void writePrivate(String text);
  Stream<void> changes();
}

ConfigStore createConfigStore({
  required Map<String, String> env,
  required String home,
}) => createConfigStoreForPath(_resolvePath(env: env, home: home));

ConfigStore createConfigStoreForPath(String path) => _IoConfigStore(path);

ConfigStore createConfigStoreForDir(String dir) =>
    createConfigStoreForPath('$dir/config.json');

String _resolvePath({required Map<String, String> env, required String home}) {
  final override = env['KUROKAN_CONFIG'];
  if (override != null && override.isNotEmpty) return override;
  return '$home/.config/kurokan/config.json';
}

String _dirOf(String path) {
  final slash = path.lastIndexOf('/');
  return slash == -1 ? '.' : path.substring(0, slash);
}

class _IoConfigStore implements ConfigStore {
  @override
  final String path;

  _IoConfigStore(this.path);

  @override
  String get dir => _dirOf(path);

  @override
  void ensureDir() => Directory(dir).createSync(recursive: true);

  @override
  bool exists() => File(path).existsSync();

  @override
  String read() => File(path).readAsStringSync();

  @override
  void writePrivate(String text) {
    ensureDir();
    final tempFile = File('$path.tmp');
    tempFile.writeAsStringSync(text);
    final chmodResult = Process.runSync('chmod', ['600', tempFile.path]);
    // Not covered by a test: triggering a real chmod failure here needs
    // mocking Process.runSync (a static dart:io call, not injected) or a
    // filesystem race between the write above and this call.
    if (chmodResult.exitCode != 0) {
      tempFile.deleteSync();
      throw StateError('chmod failed: ${chmodResult.stderr}');
    }
    tempFile.renameSync(path);
  }

  @override
  Stream<void> changes() {
    late final StreamController<void> controller;
    Timer? debounce;
    StreamSubscription<FileSystemEvent>? sub;
    final targetName = _basenameOf(path);
    final targetTmpName = '$targetName.tmp';

    controller = StreamController<void>(
      onListen: () {
        sub = Directory(dir).watch().listen((event) {
          // A state dir or a stray file (editor swap file, .DS_Store, a
          // future Phase 3 history JSONL if it ever lands in this same
          // directory) must never trigger a reload: only the config file
          // itself and its atomic-write temp file do.
          final name = _basenameOf(event.path);
          if (name != targetName && name != targetTmpName) return;
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 300), () {
            if (!controller.isClosed) controller.add(null);
          });
          // onError below is not covered by a test: triggering a real
          // watch error (e.g. the directory disappearing mid-watch) is
          // OS-watcher-dependent (inotify vs FSEvents) and flaky to force.
        }, onError: (_) {});
      },
      onCancel: () {
        debounce?.cancel();
        return sub?.cancel();
      },
    );
    return controller.stream;
  }
}

String _basenameOf(String path) {
  final slash = path.lastIndexOf('/');
  return slash == -1 ? path : path.substring(slash + 1);
}
