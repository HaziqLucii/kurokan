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

    controller = StreamController<void>(
      onListen: () {
        sub = Directory(dir).watch().listen((_) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 300), () {
            if (!controller.isClosed) controller.add(null);
          });
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
