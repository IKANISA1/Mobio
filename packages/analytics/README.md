# Analytics Package Boundary

Current source of truth:

- Analytics: `../../lib/core/services/firebase_analytics_service.dart`
- Crash/remote config/bootstrap: `../../lib/core/services/firebase_*`
- Push registration: `../../lib/core/services/push_notification_service.dart`

Analytics event names and user properties should be treated as production contracts.
