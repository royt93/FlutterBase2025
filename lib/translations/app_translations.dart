import 'package:get/get.dart';
import 'en_us.dart';
import 'vi_vn.dart';

/// GetX Translations class for multi-language support
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': enUS,
        'vi_VN': viVN,
      };
}
