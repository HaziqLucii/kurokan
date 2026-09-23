import 'dart:io';

Future<void> openFolder(String dir) async {
  final command = Platform.isMacOS ? 'open' : 'xdg-open';
  await Process.run(command, [dir]);
}
