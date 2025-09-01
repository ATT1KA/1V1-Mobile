# Event Check-in & Matchmaking - Integration Test Plan

## Prerequisites
- Supabase is configured in `Config.plist`.
- SQL scripts executed: `supabase_event_system_setup.sql`.
- App build succeeds and you are signed in.
- Enable feature toggle in Profile → "Enable Event Check-in & Matchmaking".
- Optional: Import `mock_bay_area_events.json` rows into `events` if needed.

## Scenarios

### 1) NFC Check-in
- Open Events → select an Active event → tap "Check-in via NFC".
- Scan a tag encoded with event payload. Expect: success alert, attendee count increments.
- Cancel during scan. Expect: neutral cancel message, no error state.

### 2) QR Check-in
- On Event detail, tap "Show Event QR" and scan from another device.
- Expect: success and attendee count increment.
 - Also: support legacy URL QR payloads. Scanning `1v1mobile://event/<id>` should trigger a QR-based check-in equivalently to the JSON ScanContext payload.

### 3) Manual Check-in
- Tap "Check-in Now". Expect: success and attendee count increment.

### 4) Invalid Scans
- Scan a non-JSON or unrelated QR/NFC payload.
- Expect: "Invalid QR code format" or "Invalid profile data on NFC tag".

### 5) Duplicate Check-ins
- Attempt multiple check-ins to same event.
- Expect: "You’ve already checked into this event." (unique constraint 23505 or 409 mapping).

### 6) Capacity Full
- Set `max_attendees` small, fill via inserts, then attempt check-in.
- Expect: client-side capacity error without network insert.

### 7) Time Window
- Use event whose `start_time` is in future or `end_time` in past.
- Expect: client-side message "This event is not currently active.".

### 8) Matchmaking
- Open Matchmaking for an active event and tap Find.
- With similar players checked in: expect suggestions with profiles.
- Without similar players: expect empty list, no error.

### 9) Real-time Updates (optional)
- With two devices, check-in on one and refresh on the other to observe updated attendee count.

### 10) Feature Toggle Gating
- Disable the toggle in Profile. Expect: Events tab hidden.

### 11) Network Failures
- Disable network and attempt fetch/check-in. Expect: clear error messages without crash.


## Notes
- Event QR payload: JSON `{ "type": "eventCheckIn", "eventId": "<uuid>" }`.
- NFC payload uses the same JSON; first record is parsed.
 - RPC `find_similar_players`: returns `matched_user_id` and `similarity_score`; iOS fetches profiles for UI.

  - Server enforces profile opt-in: if a user's `profiles.preferences.events_enabled` is false, server RPC `attempt_event_check_in` will return `ok=false` with message "Event features are disabled in settings" and prevent check-in. The server-side key must remain `events_enabled` for RPCs and policies.

  - Client note: the iOS app now uses `PreferencesService.shared.eventsEnabled` as the single source-of-truth (exposed to views via `@EnvironmentObject var preferences: PreferencesService`). The app no longer relies on a local `UserDefaults`/`@AppStorage` key for this feature flag. Ensure any external integrations calling `set_user_preference` continue to use the `events_enabled` key when updating server preferences.

- **Realtime publication requirement**: Ensure the `supabase_realtime` publication includes `public.event_attendance` and `public.event_matchmaking` so realtime INSERT/UPDATE events reach the app's `MatchmakingService`. The `supabase_event_system_setup.sql` file contains idempotent statements to add these tables to the publication.


