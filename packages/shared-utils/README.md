# Shared Utils Package Boundary

Current source of truth:

- Logging/navigation helpers: `../../lib/core/utils`
- Error mapping: `../../lib/core/errors`
- Pure parsing helpers currently embedded in services.

Only pure utilities with no Flutter widget, Supabase client, platform channel, or feature-state dependency should be extracted here.
