import 'dart:async';

abstract interface class ConfigStore {
  String get path;
  String get dir;
  void ensureDir();
  bool exists();
  String read();
  void writePrivate(String text);
  Stream<void> changes();
}

final Map<String, String> _files = {};
final Map<String, StreamController<void>> _watchers = {};

ConfigStore createConfigStore({
  required Map<String, String> env,
  required String home,
}) => createConfigStoreForPath(_resolvePath(env: env, home: home));

ConfigStore createConfigStoreForPath(String path) => _MemoryConfigStore(path);

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

class _MemoryConfigStore implements ConfigStore {
  @override
  final String path;

  _MemoryConfigStore(this.path);

  @override
  String get dir => _dirOf(path);

  @override
  void ensureDir() {}

  @override
  bool exists() => _files.containsKey(path);

  @override
  String read() {
    final content = _files[path];
    if (content == null) throw StateError('not found: $path');
    return content;
  }

  @override
  void writePrivate(String text) {
    _files[path] = text;
    _watchers[path]?.add(null);
  }

  @override
  Stream<void> changes() => _watchers
      .putIfAbsent(path, () => StreamController<void>.broadcast())
      .stream;
}
