import Gio from "gi://Gio"
import GLib from "gi://GLib"

// Codex has no per-window hook (see Agents.ts), so its tool count comes from the
// session log its daemon writes. The terminal title carries the thread name,
// ~/.codex/session_index.jsonl maps names to thread ids, and each thread's
// rollout file records one line per tool call. The count covers the current
// turn: tool calls since the last `task_started` event.

const CODEX_DIR = GLib.get_home_dir() + "/.codex"
const INDEX_PATH = `${CODEX_DIR}/session_index.jsonl`
const SESSIONS_DIR = `${CODEX_DIR}/sessions`
const TOOL_CALL_TYPES = new Set([
  "function_call",
  "custom_tool_call",
  "local_shell_call",
  "tool_search_call",
  "web_search_call",
  "image_generation_call",
])
const NEWLINE = 10
const SCAN_CHUNK_BYTES = 1 << 20
// Rollouts reach hundreds of MB; bound the first backwards scan for the turn start.
const MAX_SCAN_BYTES = 16 << 20

interface RolloutProgress {
  offset: number
  toolCount: number
}

let indexSize = -1
let threadIdsByName = new Map<string, string>()
const rolloutPaths = new Map<string, string>()
const progressByPath = new Map<string, RolloutProgress>()

function fileSize(path: string): number {
  try {
    return Gio.File.new_for_path(path).query_info("standard::size", Gio.FileQueryInfoFlags.NONE, null).get_size()
  } catch {
    return -1
  }
}

function refreshThreadIndex(): void {
  // The index is append-only, so its size changes whenever a thread is named.
  const size = fileSize(INDEX_PATH)
  if (size === indexSize) return
  indexSize = size

  const latestById = new Map<string, { name: string, updatedAt: string }>()
  try {
    const [ok, content] = GLib.file_get_contents(INDEX_PATH)
    if (ok) {
      for (const line of new TextDecoder().decode(content).split("\n")) {
        try {
          const entry = JSON.parse(line)
          if (typeof entry.id === "string" && typeof entry.thread_name === "string") {
            latestById.set(entry.id, { name: entry.thread_name.trim(), updatedAt: String(entry.updated_at || "") })
          }
        } catch {}
      }
    }
  } catch {}

  // Names can repeat across threads; the most recently updated one wins.
  const byName = new Map<string, { id: string, updatedAt: string }>()
  for (const [id, { name, updatedAt }] of latestById) {
    const current = byName.get(name)
    if (current === undefined || updatedAt > current.updatedAt) byName.set(name, { id, updatedAt })
  }
  threadIdsByName = new Map([...byName].map(([name, { id }]) => [name, id]))
}

function threadIdForTitle(title: string): string | null {
  // Title items are joined with " | " (thread name first, project name last by
  // default), so try the longest prefix that names a known thread.
  const parts = title.split(" | ")
  for (let end = parts.length; end >= 1; end--) {
    const id = threadIdsByName.get(parts.slice(0, end).join(" | "))
    if (id !== undefined) return id
  }
  return null
}

function rolloutPath(id: string): string | null {
  const cached = rolloutPaths.get(id)
  if (cached !== undefined) return cached

  // Thread ids are UUIDv7, and Codex files each rollout under its local creation date.
  const created = new Date(Number.parseInt(id.replace(/-/g, "").slice(0, 12), 16))
  if (Number.isNaN(created.getTime())) return null
  const pad = (value: number) => String(value).padStart(2, "0")
  const dir = `${SESSIONS_DIR}/${created.getFullYear()}/${pad(created.getMonth() + 1)}/${pad(created.getDate())}`

  try {
    const enumerator = Gio.File.new_for_path(dir).enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
    let info: Gio.FileInfo | null
    while ((info = enumerator.next_file(null)) !== null) {
      if (!info.get_name().endsWith(`-${id}.jsonl`)) continue
      const path = `${dir}/${info.get_name()}`
      rolloutPaths.set(id, path)
      enumerator.close(null)
      return path
    }
    enumerator.close(null)
  } catch {}
  return null
}

/** "turn" for a turn start, "tool" for a tool call, null otherwise. */
function classify(line: string): "turn" | "tool" | null {
  // Most lines are large tool outputs; only parse lines that can match.
  if (!line.includes('"task_started"') && !line.includes('_call"')) return null
  try {
    const entry = JSON.parse(line)
    if (entry.type === "event_msg" && entry.payload?.type === "task_started") return "turn"
    if (entry.type === "response_item" && TOOL_CALL_TYPES.has(entry.payload?.type)) return "tool"
  } catch {}
  return null
}

function readRange(path: string, start: number, end: number): Uint8Array {
  const stream = Gio.File.new_for_path(path).read(null)
  try {
    stream.seek(start, GLib.SeekType.SET, null)
    return stream.read_bytes(end - start, null).get_data() ?? new Uint8Array()
  } finally {
    stream.close(null)
  }
}

function concat(a: Uint8Array, b: Uint8Array): Uint8Array {
  const merged = new Uint8Array(a.length + b.length)
  merged.set(a)
  merged.set(b, a.length)
  return merged
}

/** Count tool calls after the last turn start, scanning backwards from `end`. */
function countCurrentTurn(path: string, end: number): number {
  let toolCount = 0
  let carry: Uint8Array = new Uint8Array()
  let position = end
  while (position > 0 && end - position < MAX_SCAN_BYTES) {
    const start = Math.max(0, position - SCAN_CHUNK_BYTES)
    const data = concat(readRange(path, start, position), carry)
    // The bytes before the first newline belong to a line that starts earlier.
    const firstNewline = start > 0 ? data.indexOf(NEWLINE) : -1
    if (start > 0 && firstNewline < 0) {
      carry = data
      position = start
      continue
    }
    carry = data.slice(0, Math.max(firstNewline, 0))

    const lines = new TextDecoder().decode(data.subarray(firstNewline + 1)).split("\n")
    for (let index = lines.length - 1; index >= 0; index--) {
      const kind = classify(lines[index])
      if (kind === "turn") return toolCount
      if (kind === "tool") toolCount++
    }
    position = start
  }
  return toolCount
}

function readToolCount(path: string): number {
  const size = fileSize(path)
  let progress = progressByPath.get(path)

  if (progress === undefined || size < progress.offset) {
    // First sight (or a rewritten file): count the current turn from the end,
    // up to the last complete line.
    const tail = readRange(path, Math.max(0, size - SCAN_CHUNK_BYTES), size)
    const end = size - (tail.length - 1 - tail.lastIndexOf(NEWLINE))
    progress = { offset: end, toolCount: countCurrentTurn(path, end) }
  } else if (size > progress.offset) {
    // Only consume complete lines; a partial last line is re-read next time.
    const data = readRange(path, progress.offset, size)
    const lastNewline = data.lastIndexOf(NEWLINE)
    if (lastNewline >= 0) {
      for (const line of new TextDecoder().decode(data.subarray(0, lastNewline)).split("\n")) {
        const kind = classify(line)
        if (kind === "turn") progress.toolCount = 0
        if (kind === "tool") progress.toolCount++
      }
      progress.offset += lastNewline + 1
    }
  }

  progressByPath.set(path, progress)
  return progress.toolCount
}

/** Tool calls in the current turn of the Codex thread named in `title`, or null when unknown. */
export function codexToolCount(title: string): number | null {
  try {
    refreshThreadIndex()
    const id = threadIdForTitle(title)
    const path = id === null ? null : rolloutPath(id)
    return path === null ? null : readToolCount(path)
  } catch {
    return null
  }
}
