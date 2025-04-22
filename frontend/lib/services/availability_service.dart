// lib/services/availability_service.dart
import 'package:flutter/material.dart';

/// Simple model for a time interval.
class TimePeriod {
  final DateTime start;
  final DateTime end;
  TimePeriod(this.start, this.end);

  Duration get duration => end.difference(start);
}

/// Invert a list of busy periods into free periods between [windowStart]–[windowEnd].
/// Only returns slots that are at least [meetingLength] long, and only within each day’s
/// [dailyWorkRange] (two TimeOfDay: [0] = start, [1] = end).
List<TimePeriod> invertBusySlots(
  List<TimePeriod> busy, {
  required DateTime windowStart,
  required DateTime windowEnd,
  required Duration meetingLength,
  required List<TimeOfDay> dailyWorkRange,
}) {
  assert(dailyWorkRange.length == 2);
  final workStartTOD = dailyWorkRange[0];
  final workEndTOD   = dailyWorkRange[1];

  // Sort the busy list by start time once for all
  busy.sort((a, b) => a.start.compareTo(b.start));

  final freeSlots = <TimePeriod>[];
  var day = DateTime(windowStart.year, windowStart.month, windowStart.day);
  final lastDay = DateTime(windowEnd.year, windowEnd.month, windowEnd.day);

  while (!day.isAfter(lastDay)) {
    // Build the day's work window
    final dayWorkStart = DateTime(
      day.year, day.month, day.day,
      workStartTOD.hour, workStartTOD.minute,
    );
    final dayWorkEnd   = DateTime(
      day.year, day.month, day.day,
      workEndTOD.hour, workEndTOD.minute,
    );

    // Clamp to overall window
    final windowDayStart = dayWorkStart.isBefore(windowStart)
        ? windowStart
        : dayWorkStart;
    final windowDayEnd   = dayWorkEnd.isAfter(windowEnd)
        ? windowEnd
        : dayWorkEnd;

    if (windowDayEnd.isAfter(windowDayStart)) {
      // Collect busy slots that overlap this day window
      final todaysBusy = busy.where((slot) {
        return slot.end.isAfter(windowDayStart) &&
               slot.start.isBefore(windowDayEnd);
      }).toList();

      // Walk through busy slots to find gaps
      var currentStart = windowDayStart;
      for (var slot in todaysBusy) {
        // If there’s a gap before this busy slot
        if (slot.start.isAfter(currentStart)) {
          final free = TimePeriod(currentStart, slot.start);
          if (free.duration >= meetingLength) {
            freeSlots.add(free);
          }
        }
        // Move the cursor forward
        if (slot.end.isAfter(currentStart)) {
          currentStart = slot.end;
        }
      }
      // After all busy slots, check for final gap
      if (windowDayEnd.isAfter(currentStart)) {
        final free = TimePeriod(currentStart, windowDayEnd);
        if (free.duration >= meetingLength) {
          freeSlots.add(free);
        }
      }
    }

    // Next calendar day
    day = day.add(const Duration(days: 1));
  }

  return freeSlots;
}

/// Find the intersection of two lists of free periods.
/// If you want to enforce a minimum meeting length, you can filter the result further.
List<TimePeriod> intersectFree(
  List<TimePeriod> a,
  List<TimePeriod> b,
) {
  // Sort both lists
  a.sort((x, y) => x.start.compareTo(y.start));
  b.sort((x, y) => x.start.compareTo(y.start));

  final intersections = <TimePeriod>[];
  var i = 0, j = 0;

  while (i < a.length && j < b.length) {
    final slotA = a[i];
    final slotB = b[j];

    // Compute overlap
    final startMax = slotA.start.isAfter(slotB.start) ? slotA.start : slotB.start;
    final endMin   = slotA.end.isBefore(slotB.end)   ? slotA.end   : slotB.end;

    if (endMin.isAfter(startMax)) {
      intersections.add(TimePeriod(startMax, endMin));
    }

    // Advance the pointer that finishes earlier
    if (slotA.end.isBefore(slotB.end)) {
      i++;
    } else {
      j++;
    }
  }

  return intersections;
}
