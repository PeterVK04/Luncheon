// lib/services/device_calendar_service.dart
import 'package:device_calendar/device_calendar.dart';

class DeviceCalendarService {
  final _plugin = DeviceCalendarPlugin();

  /// Ensure permissions granted
  Future<bool> _ensurePermissions() async {
    var perms = await _plugin.hasPermissions();
    if (perms.isSuccess && !perms.data!) {
      perms = await _plugin.requestPermissions();
    }
    return perms.isSuccess && perms.data!;
  }

  /// Fetch busy windows from all calendars over next two weeks
  Future<List<Event>> fetchBusySlots() async {
    final ok = await _ensurePermissions();
    if (!ok) return [];

    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult?.data ?? [];
    final now = DateTime.now();
    final twoWeeks = now.add(const Duration(days: 14));

    final busy = <Event>[];
    for (final cal in calendars) {
      final eventsResult = await _plugin.retrieveEvents(
        cal.id!,
        RetrieveEventsParams(
          startDate: now,
          endDate: twoWeeks,
        ),
      );
      busy.addAll(eventsResult?.data ?? []);
    }
    return busy;
  }
}
