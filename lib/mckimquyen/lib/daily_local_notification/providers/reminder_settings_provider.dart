import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:saigonphantomlabs/mckimquyen/lib/daily_local_notification/models/week_day.dart';
import 'package:saigonphantomlabs/mckimquyen/lib/daily_local_notification/repositories/reminder_repository.dart';
import 'package:saigonphantomlabs/mckimquyen/lib/daily_local_notification/repositories/shared_prefs_repository.dart';
import 'package:saigonphantomlabs/mckimquyen/lib/daily_local_notification/utils/daily_local_notifications_config.dart';

class ReminderSettingsProvider extends ChangeNotifier {
  final ReminderRepository reminderRepository;
  final SharedPrefsRepository sharedPrefsRepository;
  final DailyLocalNotificationsConfig config;
  final VoidCallback onNotificationsUpdated;

  List<WeekDay> reminderDays = [];
  TimeOfDay reminderTime = TimeOfDay.now();
  bool isReminderEnabled = false;
  bool isDailyReminderEnabled = true;

  ReminderSettingsProvider({
    required this.reminderRepository,
    required this.sharedPrefsRepository,
    required this.config,
    required this.onNotificationsUpdated,
  });

  /// Initially sets reminder settings saved in sharedPrefs
  Future<void> init() async {
    // debugPrint("init 1");
    await reminderRepository.init();
    // debugPrint("init 2");
    reminderTime = sharedPrefsRepository.getReminderTime();
    isReminderEnabled = sharedPrefsRepository.isReminderEnabled();
    reminderDays = sharedPrefsRepository.getReminderDays(config.weekDayTranslations);

    // debugPrint("reminderTime $reminderTime");
    // debugPrint("isReminderEnabled $isReminderEnabled");
    // debugPrint("reminderDays $reminderDays");

    checkIfDailyReminderChecked();

    notifyListeners();
  }

  void checkIfDailyReminderChecked() {
    if (reminderDays.every((day) => day.isActive)) {
      isDailyReminderEnabled = true;
    } else {
      isDailyReminderEnabled = false;
    }

    notifyListeners();
  }

  Future<void> updateReminderTime(DateTime dateTime) async {
    reminderTime = TimeOfDay.fromDateTime(dateTime);
    await scheduleNotifications();
    notifyListeners();
  }

  Future<void> updateReminderEnabled(bool isEnabled) async {
    isReminderEnabled = isEnabled;

    if (!isEnabled) {
      await clearReminder();
    } else {
      await scheduleNotifications();
    }

    notifyListeners();
  }

  /// Checks if daily reminder should be enabled or disabled
  Future<void> updateDailyReminderEnabled(bool isEnabled) async {
    isDailyReminderEnabled = isEnabled;

    if (isEnabled) {
      reminderDays = reminderDays.map((day) => day.copyWith(isActive: true)).toList();
    } else {
      reminderDays = reminderDays.map((day) => day.copyWith(isActive: false)).toList();
    }

    await scheduleNotifications();

    notifyListeners();
  }

  Future<void> toggleDay(WeekDay day) async {
    final updatedReminderDays = reminderDays.toList();
    final index = updatedReminderDays.indexWhere(
      (element) => element.name == day.name,
    );

    updatedReminderDays[index] = updatedReminderDays[index].copyWith(
      isActive: !updatedReminderDays[index].isActive,
    );

    reminderDays = updatedReminderDays;
    checkIfDailyReminderChecked();

    await scheduleNotifications();

    notifyListeners();
  }

  Future<void> scheduleNotifications() async {
    log('NOTIFICATIONS::scheduleNotifications: '
        'isReminderEnabled: $isReminderEnabled, '
        'reminderDays: $reminderDays, '
        'reminderTime: $reminderTime');

    try {
      await sharedPrefsRepository.setReminderDays(reminderDays);
      await sharedPrefsRepository.setReminderTime(reminderTime);
      await sharedPrefsRepository.setReminderEnabled(isReminderEnabled);

      // throws exact_alarms_not_permitted exception
      await reminderRepository.scheduleDailyNotificationByTimeAndDay(
        reminderTime,
        reminderDays,
      );

      onNotificationsUpdated();
    } catch (error) {
      log('NOTIFICATIONS::scheduleNotifications ERROR', error: error);
    }
  }

  Future<void> clearReminder() async {
    log('NOTIFICATIONS::clearReminder');
    reminderDays = WeekDay.initialWeekDaysFromTranslations(config.weekDayTranslations);
    isReminderEnabled = false;
    checkIfDailyReminderChecked();

    await sharedPrefsRepository.setReminderDays(reminderDays);
    await sharedPrefsRepository.setReminderEnabled(false);

    await reminderRepository.cancelAllNotifications();
  }
}
