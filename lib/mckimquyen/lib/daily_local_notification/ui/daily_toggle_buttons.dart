import 'package:flutter/material.dart';
import 'package:gameoffline/mckimquyen/lib/daily_local_notification/providers/reminder_settings_provider.dart';
import 'package:provider/provider.dart';

class DailyToggleButtons extends StatelessWidget {
  final Widget reminderRepeatText;
  final Widget reminderDailyText;
  final Color activeColor;
  final Color inactiveColor;

  const DailyToggleButtons({
    super.key,
    required this.reminderRepeatText,
    required this.reminderDailyText,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ReminderSettingsProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            Row(
              children: [
                reminderRepeatText,
                const Spacer(),
                reminderDailyText,
                Checkbox(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  activeColor: activeColor,
                  checkColor: Colors.white,
                  value: provider.isDailyReminderEnabled,
                  onChanged: (isDaily) => provider.updateDailyReminderEnabled(isDaily ?? false),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  provider.reminderDays.length,
                  (index) => Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // debugPrint("onTap index $index");
                        provider.toggleDay(provider.reminderDays[index]);
                      },
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        padding: const EdgeInsets.all(1),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: provider.reminderDays[index].isActive ? activeColor : inactiveColor,
                          ),
                          height: 55,
                          width: 55,
                          child: Center(
                            child: Text(
                              provider.reminderDays[index].name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
