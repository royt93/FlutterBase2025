import 'package:intl/intl.dart';

class DurationUtils {
  static const formatTZ = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
  static const formatT = "yyyy-MM-dd'T'HH:mm:ss.SSS";
  static const format1 = "dd/MM/yyyy - HH:mm";
  static const format2 = "dd/MM/yyyy HH:mm:ss";
  static const format3 = "dd/MM/yyyy";

  static String formatSeconds(int sec) {
    Duration duration = Duration(seconds: sec);
    var seconds = duration.inSeconds;
    final days = seconds ~/ Duration.secondsPerDay;
    seconds -= days * Duration.secondsPerDay;
    final hours = seconds ~/ Duration.secondsPerHour;
    seconds -= hours * Duration.secondsPerHour;
    final minutes = seconds ~/ Duration.secondsPerMinute;
    seconds -= minutes * Duration.secondsPerMinute;

    final List<String> tokens = [];
    if (days == 0) {
      tokens.add("00");
    } else if (days <= 9) {
      tokens.add("0$days");
    } else {
      tokens.add("$days");
    }

    if (hours == 0) {
      tokens.add("00");
    } else if (hours <= 9) {
      tokens.add("0$hours");
    } else {
      tokens.add("$hours");
    }

    if (minutes == 0) {
      tokens.add("00");
    } else if (minutes <= 9) {
      tokens.add("0$minutes");
    } else {
      tokens.add("$minutes");
    }

    if (seconds <= 9) {
      tokens.add("0$seconds");
    } else {
      tokens.add("$seconds");
    }

    return tokens.join(":");
  }

  //1617727620030 -> value 2021-04-06T23:47:00.030Z
  static String formatTime(int? millisecondsSinceEpoch, String dateFormat) {
    if (millisecondsSinceEpoch == null) {
      return "Unknown";
    }
    final df = DateFormat(dateFormat);
    String value = df.format(DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch, isUtc: false));
    return value;
  }

  static String nowHHmm() {
    return formatTime(DateTime.now().millisecondsSinceEpoch, format2);
  }

  //date 2021-04-07T23:21:13.0481878,
  //fromFormat yyyy-MM-dd'T'HH:mm:ss.SSS
  //toFormat dd/MM/yyyy - HH:mm
  //formatted 07/04/2021 - 23:29
  static String? convertDate(
    String date,
    String fromFormat,
    String toFormat,
  ) {
    if (date.isEmpty) {
      return "";
    }
    try {
      final format = DateFormat(fromFormat);
      DateTime gettingDate = format.parse(date);
      final DateFormat formatter = DateFormat(toFormat);
      final String formatted = formatter.format(gettingDate);
      // Dog.d("date $date, fromFormat $fromFormat, toFormat $toFormat, formatted $formatted");
      return formatted;
    } catch (e) {
      return "";
    }
  }

  static int getTimeBetweenTargetAndNow(
    String timeTarget,
    String timeTargetFormat,
  ) {
    try {
      int millisecondsSinceEpochNow = DateTime.now().millisecondsSinceEpoch;
      // Dog.v(
      //     "getTimeBetweenNowAndTarget millisecondsSinceEpochNow $millisecondsSinceEpochNow");
      final format = DateFormat(timeTargetFormat);
      DateTime dateTimeTarget = format.parse(timeTarget);
      int millisecondsSinceEpochTarget = dateTimeTarget.millisecondsSinceEpoch;
      // Dog.v(
      //     "getTimeBetweenNowAndTarget millisecondsSinceEpochTarget $millisecondsSinceEpochTarget");
      return millisecondsSinceEpochTarget - millisecondsSinceEpochNow;
    } catch (e) {
      return 0;
    }
  }

  static bool isFutureTime(
    String timeTarget,
    String timeTargetFormat,
  ) {
    if (timeTarget.isEmpty || timeTargetFormat.isEmpty) {
      return false;
    }
    int timeBetweenTargetAndNow = getTimeBetweenTargetAndNow(timeTarget, timeTargetFormat);
    return timeBetweenTargetAndNow > 0;
  }

  static String formatISOTime(DateTime date) {
    var duration = date.timeZoneOffset;
    if (duration.isNegative) {
      return ("${date.toIso8601String()}-${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes - (duration.inHours * 60)).toString().padLeft(2, '0')}");
    } else {
      return ("${date.toIso8601String()}+${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes - (duration.inHours * 60)).toString().padLeft(2, '0')}");
    }
  }

  static void delay(int milliseconds, Function f) {
    Future.delayed(Duration(milliseconds: milliseconds), () {
      f.call();
    });
  }

  static String getFormattedDate(DateTime inputDate) {
    var outputFormat = DateFormat('dd/MM/yyyy');
    var outputDate = outputFormat.format(inputDate);
    return outputDate.toString();
  }

  static DateTime? stringToDateTime(String date, String fromFormat) {
    try {
      final format = DateFormat(fromFormat);
      DateTime dateTime = format.parse(date);
      return dateTime;
    } catch (e) {
      return null;
    }
  }
}
