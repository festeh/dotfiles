# Codex AGS Hooks Support Spec

## Goal

Add Codex session pills to the existing AGS workspace widget, matching the Claude integration's behavior:

- show every active local Codex CLI session beside the Hyprland workspace it belongs to
- color sessions by state: running, waiting, idle, unknown
- left-click a pill to focus its workspace
- right-click a pill for prompt/tool/model/cwd/session details
- remove pills when the owning Codex process or Hyprland window is gone

This is for local Codex CLI sessions. Codex Cloud and IDE-only sessions are out of scope unless they write the same local hook payloads.

## Current Claude Baseline

The existing Claude path is:

- `claude/hooks/ags-status.py` receives Claude hook JSON on stdin.
- It writes one JSON file per session under `~/.cache/ags-claude/sessions/<session_id>.json`.
- `ags/service/ClaudeStatus.ts` monitors that directory with `Gio.FileMonitor`, normalizes session JSON, prunes dead PIDs, and exposes a reactive `Variable<ClaudeSession[]>`.
- `ags/widget/ClaudeStatus.ts` renders a pill and detail popover.
- `ags/widget/HyprlandStatus.ts` groups pills by `window_address` and inserts them after each workspace button.

Codex support should reuse this architecture instead of introducing a separate status transport.

## DRY Design Requirement

The AGS side must not grow into parallel Claude and Codex implementations. The shared behavior should live in generic agent status modules, with Claude and Codex reduced to provider adapters.

Shared code:

| File | Purpose |
| --- | --- |
| `ags/service/AgentStatus.ts` | Generic session type, cache reader, file monitor, liveness pruning, elapsed formatting, tool input formatting, and `createAgentStatusService(...)`. |
| `ags/widget/AgentStatus.ts` | Generic session pill, detail popover, workspace lookup, click handling, and provider-aware labels/icons/styles. |

Thin provider adapters:

| File | Purpose |
| --- | --- |
| `ags/service/ClaudeStatus.ts` | Claude config wrapper around `createAgentStatusService(...)`. |
| `ags/service/CodexStatus.ts` | Codex config wrapper around `createAgentStatusService(...)`. |
| `ags/widget/ClaudeStatus.ts` | Claude wrapper around shared `SessionPill(...)` if keeping existing imports stable. |
| `ags/widget/CodexStatus.ts` | Codex wrapper around shared `SessionPill(...)`. |

The generic service config should include:

```ts
interface AgentStatusConfig {
  provider: "claude" | "codex"
  sessionsDir: string
  pidField: "claude_pid" | "codex_pid"
  staleThresholdMs: number
}
```

The generic widget config should include:

```ts
interface AgentWidgetConfig {
  provider: "claude" | "codex"
  iconPath: string
  classPrefix: string
  title: string
}
```

Provider-specific code should be limited to:

- hook event mapping
- cache directory and PID field name
- icon path and provider label
- any payload fields that only one provider emits

Hook scripts may remain separate at first because Claude and Codex event payloads differ. If helper duplication becomes meaningful, extract a Python helper for atomic JSON writes, logging, PID/window resolution, pruning, and tool-input sanitization.

## Codex Hook Surface

Codex hooks are currently gated by:

```toml
[features]
codex_hooks = true
```

Codex discovers hooks from `hooks.json` or inline `[hooks]` tables next to active config layers, including `~/.codex/hooks.json`, `~/.codex/config.toml`, `<repo>/.codex/hooks.json`, and `<repo>/.codex/config.toml`.

Useful events for a status widget:

| Codex event | Widget state | Notes |
| --- | --- | --- |
| `SessionStart` | `idle` | Fires on `startup`, `resume`, and `clear`. |
| `UserPromptSubmit` | `running` | Start of a turn. Store prompt and reset tool count. |
| `PreToolUse` | `running` | Store tool name/input and increment tool count. |
| `PermissionRequest` | `waiting` | Approval prompt or managed network approval. |
| `PostToolUse` | `running` | Preserve current action unless output contains a useful summary. |
| `Stop` | `idle` | Turn finished. Store `last_assistant_message`. |

Important constraints:

- Every command hook receives one JSON object on stdin with shared fields including `session_id`, `transcript_path`, `cwd`, `hook_event_name`, and `model`.
- Turn-scoped events include `turn_id`.
- `PreToolUse`, `PostToolUse`, and `PermissionRequest` support tool matchers such as `Bash`, `apply_patch`, and MCP tool names.
- `UserPromptSubmit` and `Stop` ignore matchers.
- Multiple matching command hooks for the same event can run concurrently.
- For this status hook, stdout must stay empty and exit code must be `0`; it must never block, approve, deny, or add developer context.
- `PreToolUse` and `PostToolUse` do not intercept every possible shell path yet, so the UI is best-effort for tool activity rather than an enforcement boundary.

References:

- OpenAI Codex hooks: https://developers.openai.com/codex/hooks
- OpenAI Codex config reference: https://developers.openai.com/codex/config-reference

## Files To Add

| File | Purpose |
| --- | --- |
| `codex/hooks/ags-status.py` | Codex hook script. Reads hook JSON from stdin and maintains `~/.cache/ags-codex/sessions/<session_id>.json`. |
| `codex/hooks.json` | Tracked example/global hook config that can be symlinked to `~/.codex/hooks.json`. |
| `codex/README.md` | Install notes, event mapping, and troubleshooting. |
| `ags/service/AgentStatus.ts` | Shared AGS session-cache service used by Claude and Codex. |
| `ags/service/CodexStatus.ts` | Thin Codex service adapter around `AgentStatus.ts`. |
| `ags/widget/AgentStatus.ts` | Shared AGS pill/detail renderer used by Claude and Codex. |
| `ags/widget/CodexStatus.ts` | Thin Codex widget adapter around `AgentStatus.ts`. |
| `ags/assets/codex.svg` | Small Codex icon for pills. |

## Files To Change

| File | Change |
| --- | --- |
| `ags/service/ClaudeStatus.ts` | Refactor to use `AgentStatus.ts` without changing exported Claude symbols. |
| `ags/widget/ClaudeStatus.ts` | Refactor to use `AgentStatus.ts` without changing exported Claude symbols. |
| `ags/widget/HyprlandStatus.ts` | Import `codexSessions`, group them by workspace, and render Codex pills next to Claude pills. |
| `ags/style.css` | Generalize shared pill/detail styles to `.agent-session-*`; keep provider-specific accent classes only where needed. |
| `bootstrap.sh` / host setup docs | Optional: symlink `codex/hooks.json` into `~/.codex/hooks.json` and ensure `[features].codex_hooks = true`. |

Do the AGS refactor as part of the Codex implementation, not as a later cleanup. Keep the existing Claude exports stable so the first refactor is behavior-preserving.

## Session Cache Contract

Directory:

```text
~/.cache/ags-codex/sessions/
```

File name:

```text
<session_id>.json
```

Session JSON:

```json
{
  "session_id": "string",
  "turn_id": "string",
  "state": "idle|running|waiting|unknown",
  "action": "string",
  "cwd": "string",
  "transcript": "string",
  "updated_at": "2026-05-07T12:00:00+00:00",
  "prompt": "string",
  "tool_name": "string",
  "tool_input": {},
  "tool_count": 0,
  "model": "gpt-5.5",
  "source": "startup|resume|clear",
  "approval_reason": "string",
  "last_assistant_message": "string",
  "codex_pid": 12345,
  "window_address": "0xabc"
}
```

Required fields for AGS:

- `session_id`
- `state`
- `action`
- `cwd`
- `updated_at`
- `codex_pid`
- `window_address`

Optional fields should be omitted when empty.

## Hook Script Behavior

`codex/hooks/ags-status.py` should follow the Claude hook script closely:

- parse JSON from stdin; invalid JSON exits quietly
- require `hook_event_name` and `session_id`
- write a compact log to `~/.cache/ags-codex/hook.log`
- read the existing session file before updating so prompt/tool state can be preserved across events
- write session files atomically with temp file plus `os.replace`
- keep stdout empty for every event
- never return a hook decision

State/action mapping:

| Event | State | Action |
| --- | --- | --- |
| `SessionStart` | `idle` | `started` or `resumed` from `source` |
| `UserPromptSubmit` | `running` | prompt snippet, fallback `thinking...` |
| `PreToolUse` | `running` | `<tool_name>: <short detail>` |
| `PermissionRequest` | `waiting` | `Allow <tool_name>?` or approval description |
| `PostToolUse` | `running` | preserve previous action |
| `Stop` | `idle` | `finished` |
| unknown event | `unknown` | `event: <hook_event_name>` |

Tool input sanitization should mirror Claude:

- `Bash` and `apply_patch`: keep `command`, trimmed
- file/edit-like MCP tools: keep path-ish fields when present
- generic MCP tools: keep short scalar values only
- never write secrets or full large payloads to the cache

Process/window resolution:

- `codex_pid` should be the nearest ancestor process named `codex`, starting from `os.getppid()`.
- If no ancestor is named `codex`, use `os.getppid()` as a fallback and mark this in the log.
- `window_address` should be resolved by walking ancestors from `codex_pid` and matching a Hyprland client PID from `hyprctl clients -j`.
- Preserve an existing `window_address` if resolution fails on later events.

Pruning:

- Delete a session when `codex_pid` no longer exists under `/proc`.
- Delete a session if `window_address` points to no current Hyprland client and the process is gone.
- Do not prune idle sessions only because they are old while the Codex process is alive.
- If `codex_pid` is missing, prune non-idle sessions after 5 minutes and idle sessions after 24 hours.

## Hook Configuration

`codex/hooks.json` should capture all status-relevant events and match all supported tool calls:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/dotfiles/codex/hooks/ags-status.py",
            "timeout": 5,
            "statusMessage": "Updating Codex status"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/dotfiles/codex/hooks/ags-status.py",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/dotfiles/codex/hooks/ags-status.py",
            "timeout": 5
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/dotfiles/codex/hooks/ags-status.py",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/dotfiles/codex/hooks/ags-status.py",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/dotfiles/codex/hooks/ags-status.py",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Install shape:

```sh
mkdir -p ~/.codex
ln -sf ~/dotfiles/codex/hooks.json ~/.codex/hooks.json
```

`~/.codex/config.toml` also needs:

```toml
[features]
codex_hooks = true
```

This repo should not overwrite the user's whole Codex config.

## AGS Service

`ags/service/AgentStatus.ts` should own the shared cache-monitoring path. `ags/service/CodexStatus.ts` should only configure it with Codex-specific values:

- `SESSIONS_DIR = ~/.cache/ags-codex/sessions`
- `CodexSession` interface with fields from the session cache contract
- `codexSessions = Variable<CodexSession[]>([])`
- `sessionDisplayName`, `formatElapsed`, `formatToolInput`, `getSessionById`
- shared `idleTick`

Refresh behavior:

- create the session directory on startup
- monitor session JSON files with `Gio.FileMonitor`
- refresh on file changes, liveness tick, and Hyprland `client-removed`
- compare normalized sessions before updating the `Variable`
- sort by newest `updated_at`

## AGS Widget

`ags/widget/AgentStatus.ts` should render both Claude and Codex pills from the same implementation. Codex pills should visually match Claude but be distinguishable:

- same pill size, spacing, badge, idle timer, and popover structure
- Codex icon instead of Claude icon
- optional Codex-specific accent for running state only if it does not make mixed Claude/Codex workspaces noisy
- tooltip: `<action> - <cwd>\nClick: focus workspace - Right-click: details`

Detail popover fields:

- state and project name
- prompt
- tool name/count and formatted tool input
- approval reason when waiting
- model
- last assistant message when idle
- cwd
- updated elapsed

Hyprland grouping should work like this:

1. Define an array of agent providers with `sessions` and `renderPill`.
2. Build one workspace map containing rendered pills from every provider.
3. Render workspace button, then all agent pills for that workspace.

Sort pills by `updated_at` within each workspace so mixed Claude/Codex sessions have predictable recency ordering.

## Verification Plan

Hook fixtures:

- `SessionStart` creates an idle session file.
- `UserPromptSubmit` changes it to running and stores prompt.
- `PreToolUse` increments `tool_count` and stores sanitized input.
- `PermissionRequest` changes it to waiting.
- `Stop` changes it to idle and stores `last_assistant_message`.
- malformed JSON exits successfully and writes nothing.

Manual AGS checks:

- Start a Codex session in a kitty workspace; a Codex pill appears beside that workspace.
- Submit a prompt; pill changes to running.
- Trigger a command approval; pill changes to waiting.
- Approve/continue until Codex stops; pill changes to idle with elapsed timer.
- Left-click the pill from another workspace; focus returns to the Codex workspace.
- Kill the Codex process or close kitty; pill disappears within the liveness tick.

Commands:

```sh
python3 codex/hooks/ags-status.py < codex/testdata/session-start.json
inotifywait -m ~/.cache/ags-codex/sessions
systemctl --user restart ags
```

## Rollout Plan

1. Implement hook/cache only.
2. Feed local JSON fixtures and inspect `~/.cache/ags-codex/sessions`.
3. Extract shared AGS service/widget modules from the current Claude implementation.
4. Move Claude onto the shared modules with stable exports and verify no visual behavior changed.
5. Add Codex service/widget adapters.
6. Add the Codex session grouping to `HyprlandStatus.ts` through the shared provider list.
7. Add install docs and optional bootstrap symlink support.
8. Run a real Codex session and verify state transitions end to end.

## Non-Goals

- auto-approving or denying Codex permission requests
- enforcing security policy through hooks
- showing token counts or streaming partial assistant output
- supporting Codex Cloud sessions
- modifying existing `~/.codex/config.toml` destructively

## Open Risks

- Codex hook coverage for shell execution is not complete yet, so tool activity may miss some command paths.
- The parent process shape may differ between TUI, app-server, and future clients. PID resolution must be logged and tolerant.
- `Stop` has no equivalent `SessionEnd`; process liveness must drive cleanup.
- Hook commands for the same event can run concurrently, so writes must stay per-session and atomic.
