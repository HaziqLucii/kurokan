import 'dart:async';
import 'dart:io';

class ConfigWatcher {
  final String dir;

  ConfigWatcher(this.dir);

  Stream<void> get events {
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
