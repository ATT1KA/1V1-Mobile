Notification Testing Guide
=========================

This guide describes manual and automated testing strategies for the notification system.

Manual Testing
--------------
- Use the in-app `Notification Tester` (Debug build) to trigger match start, match end, and verification reminders.
- Use multiple Simulator instances to validate cross-device sync; sign in with the same account across simulators.
- Use the "Request Authorization" button to exercise permission dialogs and edge cases.

Automated Tests
---------------
- Unit tests and integration tests are located in `1V1MobileTests/` and use mock services for deterministic behavior.
- Run tests via Xcode's test runner or `xcodebuild test`.

Realtime and Network
--------------------
- Simulate connection loss by toggling network in Simulator or using the debug tools.
- Verify that the realtime subscription backoff and resubscribe logic recover after reconnection.

Common Scenarios
----------------
- Match start -> ensure local notification is scheduled for the signed-in user.
- Match end -> ensure match-ended notification and 60s reminder are queued and delivered.
- Verification timeout -> ensure duel is marked forfeited when submissions are missing.


