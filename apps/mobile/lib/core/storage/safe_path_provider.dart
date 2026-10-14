import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> getSafeApplicationSupportDirectory() async {
  try {
    return await getApplicationSupportDirectory();
  } on Object {
    if (Platform.isAndroid) {
      final dir = Directory('/data/user/0/com.mediexplain.mediexplain/files');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }
    return Directory.systemTemp;
  }
}

Future<Directory> getSafeTemporaryDirectory() async {
  try {
    return await getTemporaryDirectory();
  } on Object {
    if (Platform.isAndroid) {
      final dir = Directory('/data/user/0/com.mediexplain.mediexplain/cache');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }
    return Directory.systemTemp;
  }
}
