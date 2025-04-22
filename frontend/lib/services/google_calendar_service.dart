// lib/services/google_calendar_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class GoogleCalendarService {
  final _scopes = [gcal.CalendarApi.calendarReadonlyScope];
  final _googleSignIn =
      GoogleSignIn(scopes: [gcal.CalendarApi.calendarReadonlyScope]);

  Future<gcal.CalendarApi> signInAndGetApi() async {
    final account = await _googleSignIn.signIn();
    final auth = await account!.authentication;
    final authHeaders = {
      'Authorization': 'Bearer ${auth.accessToken}',
      'X-Goog-AuthUser': '0',
    };
    final client = IOClient();
    final authedClient = AuthenticatedClient(client, authHeaders);
    return gcal.CalendarApi(authedClient);
  }

  /// Returns a map of busy windows for primary calendar
  Future<List<gcal.TimePeriod>> fetchBusyWindows(
      gcal.CalendarApi api) async {
    final now = DateTime.now().toUtc();
    final twoWeeks = now.add(const Duration(days: 14));
    final fb = await api.freebusy.query(gcal.FreeBusyRequest(
      timeMin: now,
      timeMax: twoWeeks,
      items: [gcal.FreeBusyRequestItem(id: 'primary')],
    ));
    return fb.calendars!['primary']!.busy!;
  }
}

/// A small helper to wrap an http client with auth headers
class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _headers;
  AuthenticatedClient(this._inner, this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest req) {
    req.headers.addAll(_headers);
    return _inner.send(req);
  }
}
