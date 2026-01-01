import 'package:flutter/foundation.dart';

class Logger {
  static void i(String s) {
    if (kDebugMode) {
      debugPrint("roy93~ $s");
    }
  }
}
