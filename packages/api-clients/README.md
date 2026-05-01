# API Clients Package Boundary

Current source of truth:

- Supabase service clients: `../../lib/core/services`
- Feature API clients: `../../lib/features/*/services`
- Edge Function contracts: `../../supabase/functions`

Client methods should call RPCs or Edge Functions; they should not hide business authorization rules that belong in Supabase RLS/RPCs.
