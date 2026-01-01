import 'package:flutter/foundation.dart';

class Log {
  static void i(String s) {
    if (kDebugMode) {
      debugPrint("roy93~ $s");
    }
  }
}
