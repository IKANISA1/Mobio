# Agents

No OpenClaw workspace, MCP server definition, agent memory store, or channel-specific agent runtime was found in this repo.

Current agent-like assets:

- `../AGENTS.md`: repo operating guidance.
- `../prompts.md`: prompt notes.
- `../supabase/functions/chat-assist`: chat assistant Edge Function.
- `../supabase/functions/generate-promo-content`: AI promo generation Edge Function.

Target boundaries:

- `shared/`: common agent policy, structured output schemas, permission rules.
- `workspaces/`: product-specific agent workspaces.
- `tools/`: tool contracts and allowlists.
- `channels/`: WhatsApp, Telegram, Google Chat, Teams, email, and voice adapters.
- `memory/`: memory isolation and retention policy.
- `evals/`: regression/evaluation suites.
- `prompts/`: prompt source files.

Do not add production agent runtime paths without explicit authentication, authorization, audit logging, and tool allowlist design.
