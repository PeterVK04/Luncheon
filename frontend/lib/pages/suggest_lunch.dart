import 'package:flutter/material.dart';
import '../services/google_calendar_service.dart';
import '../services/device_calendar_service.dart';
import '../services/availability_service.dart';

class LunchSuggestion extends StatefulWidget {
  @override
  _LunchSuggestionState createState() => _LunchSuggestionState();
}

class _LunchSuggestionState extends State<LunchSuggestion> {
  String _suggestion = 'Tap to suggest a lunch slot';

  Future<void> _computeLunch() async {
    // 1) Google
    final gcalApi = await GoogleCalendarService().signInAndGetApi();
    final busyG = await GoogleCalendarService().fetchBusyWindows(gcalApi);

    // 2) Device (Apple) calendar
    final eventsD = await DeviceCalendarService().fetchBusySlots();
    final busyD = eventsD
        .map((e) => TimePeriod(e.start!, e.end!))
        .toList();

    // 3) Invert to free slots 11 AM–2 PM, next 14 days
    final now = DateTime.now();
    final twoWeeks = now.add(const Duration(days: 14));

    final freeG = invertBusySlots(
      busyG.map((p) => TimePeriod(p.start!, p.end!)).toList(),
      windowStart: now,
      windowEnd: twoWeeks,
      meetingLength: const Duration(hours: 1),
      dailyWorkRange: const [
        TimeOfDay(hour: 11, minute: 0),
        TimeOfDay(hour: 14, minute: 0),
      ],
    );

    final freeD = invertBusySlots(
      busyD,
      windowStart: now,
      windowEnd: twoWeeks,
      meetingLength: const Duration(hours: 1),
      dailyWorkRange: const [
        TimeOfDay(hour: 11, minute: 0),
        TimeOfDay(hour: 14, minute: 0),
      ],
    );

    // 4) Find common free slots
    final common = intersectFree(freeG, freeD);

    if (common.isNotEmpty) {
      final slot = common.first;
      setState(() {
        _suggestion =
            'Suggested lunch on ${slot.start.month}/${slot.start.day} at '
            '${slot.start.hour}:${slot.start.minute.toString().padLeft(2, '0')}';
      });
    } else {
      setState(() => _suggestion = 'No common lunch slot found.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lunch Suggestion Demo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_suggestion, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _computeLunch,
                child: const Text('Find Lunch Slot'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
