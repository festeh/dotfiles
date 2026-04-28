# Claude → AGS integration refactor plan

## Invariant

Every Claude session belongs to exactly one Hyprland workspace. There are no
orphans. If a session can't be resolved to a workspace, that's a bug or a
dead session — never a normal display state.

(The default `ClaudeStatus()` export in `ags/widget/ClaudeStatus.ts` was a
right-side orphan renderer; it's already not imported anywhere and can be
deleted as dead code.)

## Problem

Two Claude sessions running in the same cwd (e.g. two `dotfiles` workspaces,
one Claude in each) collapse into a single workspace group in the AGS bar.

Root cause:
- `claude/hooks/ags-status.py:_upsert_session` rebuilds the session dict every
  event but does not preserve `claude_pid`. It is only set on `SessionStart`
  (line 111), then wiped by the next event. Confirmed: every entry in
  `~/.cache/ags-claude/sessions.json` has `claude_pid: null`.
- `ags/widget/ClaudeStatus.ts:getClaudePidByCwd` falls back to
  `Map<string, number>` keyed by cwd. Two `claude` processes sharing a cwd
  collapse into one entry; both sessions resolve to the same pid → same
  workspace.

Architectural issues the bug exposes:
- Polling at 1s (`GLib.timeout_add`) wastes idle CPU and adds latency.
- Single `sessions.json` has a lost-update race — writes are atomic
  (tmp+rename) but unlocked, so concurrent hooks can clobber each other.
- Workspace resolution walks `/proc` parents on every render.

## Plan

Phases are independently landable.

### Phase 1 — Stop the bleeding (~5 min) — DONE

- `claude/hooks/ags-status.py`: in `_upsert_session`, include
  `"claude_pid": os.getppid()` in the session dict on every event. Drop the
  SessionStart-only line at 111.

That's it. Running sessions repopulate `claude_pid` on their next event
(within seconds). Idle sessions stay wrongly grouped until touched once;
acceptable transient state until Phase 2.

No AGS changes in this phase — the existing pid-walk path resolves correctly
once `claude_pid` is non-null.

### Phase 2 — Capture window identity, not pid (~1 h) — DONE

- Hook: at `SessionStart`, run `hyprctl activewindow -j` and store the
  `address` field as `window_address` in the session record. Persist it
  across events (same pattern as Phase 1's `claude_pid` fix).
- AGS: replace `findWorkspaceIdForSession` with
  `clients.find(c => c.address === session.window_address)?.workspace?.id`.
  Delete `getPpid`, `buildClaudeCwdToPidMap`, `getClaudePidByCwd`,
  `cwdToPidCache`, and the parent-walk loop. ~50 lines removed.
- Delete the dead `ClaudeStatus()` default export (orphan renderer).
- Delete `.claude-status-widget` and `.claude-status-empty` from `style.css`.

If a session has no `window_address` (couldn't be resolved at SessionStart,
or window has since died), don't render its pill at all. Workspace is
non-optional by invariant.

Effect: same-cwd-different-workspace stops mattering. Window moves are
handled natively because workspace is a live property of the Hyprland client.
Bug class eliminated.

### Phase 3 — Per-session files + inotify push (~1 h) — DONE

- Hook: writes `~/.cache/ags-claude/sessions/<session_id>.json`; `os.unlink`
  on `SessionEnd`. Old `_read_db`/`_write_db` blob handling removed.
- `ags/service/ClaudeStatus.ts`: reads the directory; `Gio.FileMonitor` for
  push, plus a 30 s tick to re-apply the stale filter when nothing fires.
  `sameSessions` retained as a no-op guard against same-value `Variable.set`.
- `scripts/focus-claude.py` and `scripts/clean-stale-claude-sessions.py`
  updated for the new layout. Cleanup script deletion deferred to Phase 4
  (will be redundant once prune-on-write lands).

Effect: no lost-update race. Push semantics. Idle CPU ≈ 0.

### Phase 4 — Hardening (~20 min)

- Hook: cap `prompt` at 4 KB before storing.
- Hook: on every write, prune session files whose `/proc/<claude_pid>` no
  longer exists. Crashed sessions self-heal.
- Delete `scripts/clean-stale-claude-sessions.py`,
  `systemd/clean-stale-claude-sessions.service`, and
  `systemd/clean-stale-claude-sessions.timer` once prune-on-write is in
  place.

## Verification

- After Phase 1: two `dotfiles` workspaces, one Claude each — fire any tool
  call in each, observe one pill per workspace.
- After Phase 2: also move a Claude window between workspaces — pill follows.
- After Phase 3: `inotifywait -m ~/.cache/ags-claude/sessions/` shows
  per-session events; no idle traffic.
- After Phase 4: `kill -9` a Claude session; entry disappears on the next
  unrelated event.

## Out of scope

- Switching IPC to a Unix socket — the file model is correct here. Restart
  resilience and `jq`-debuggability outweigh the marginal gain.
- Compression / SQLite — unwarranted at this volume.
