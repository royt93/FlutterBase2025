import 'dart:convert';

final Map<String, Duration> kVipKeyMap = {
  utf8.decode(base64Decode('OUZBMFE3RU4hMjdDTFgwNEAyMTk5M1kyVTBJNyNRMA==')):
      const Duration(days: 30),
};

Future<bool> vipKeyValidator(String normalisedKey) async =>
    kVipKeyMap.containsKey(normalisedKey);

Duration? lookupVipKeyDuration(String normalisedKey) =>
    kVipKeyMap[normalisedKey];
