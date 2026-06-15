import { Variable } from "astal"
import Gio from "gi://Gio"
import GLib from "gi://GLib"

export type SentryFirstResponderStatusName = "missing" | "running" | "ok" | "attention" | "error"

export interface SentryFirstResponderState {
  status: SentryFirstResponderStatusName
  attention_needed: boolean
  last_run_at: string
  updated_at: string
  message: string
  details?: string
  sentry_url?: string
  jira_url?: string
  slack_channel?: string
  started_at?: string
  finished_at?: string
}

const CACHE_HOME = GLib.getenv("XDG_CACHE_HOME") || `${GLib.get_home_dir()}/.cache`
const STATUS_DIR = `${CACHE_HOME}/ags-sentry-first-responder`
const STATUS_FILE = `${STATUS_DIR}/status.json`
const retainedDirectoryMonitors: Gio.FileMonitor[] = []

function missingState(): SentryFirstResponderState {
  return {
    status: "missing",
    attention_needed: false,
    last_run_at: "",
    updated_at: "",
    message: "No Sentry first responder run recorded",
  }
}

function stringField(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() !== "" ? value : undefined
}

function parseStatusName(value: unknown): SentryFirstResponderStatusName {
  if (value === "running" || value === "ok" || value === "attention" || value === "error") {
    return value
  }
  return "error"
}

function readStatus(): SentryFirstResponderState {
  try {
    const [ok, content] = GLib.file_get_contents(STATUS_FILE)
    if (!ok) return missingState()

    const raw = JSON.parse(new TextDecoder().decode(content)) as Record<string, unknown>
    const status = parseStatusName(raw.status)
    const message = stringField(raw.message)

    return {
      status,
      attention_needed: raw.attention_needed === true || status === "attention" || status === "error",
      last_run_at: stringField(raw.last_run_at) || stringField(raw.updated_at) || "",
      updated_at: stringField(raw.updated_at) || stringField(raw.last_run_at) || "",
      message: message || "Sentry first responder status updated",
      details: stringField(raw.details),
      sentry_url: stringField(raw.sentry_url),
      jira_url: stringField(raw.jira_url),
      slack_channel: stringField(raw.slack_channel),
      started_at: stringField(raw.started_at),
      finished_at: stringField(raw.finished_at),
    }
  } catch (error) {
    return {
      status: "error",
      attention_needed: true,
      last_run_at: "",
      updated_at: "",
      message: `Invalid Sentry first responder status: ${String(error)}`,
    }
  }
}

function sameState(a: SentryFirstResponderState, b: SentryFirstResponderState): boolean {
  return JSON.stringify(a) === JSON.stringify(b)
}

export const sentryFirstResponderStatus = Variable<SentryFirstResponderState>(readStatus())
export const sentryFirstResponderTick = Variable<number>(0)

GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 30, () => {
  sentryFirstResponderTick.set(sentryFirstResponderTick.get() + 1)
  return GLib.SOURCE_CONTINUE
})

export function refreshSentryFirstResponderStatus(): void {
  const next = readStatus()
  if (!sameState(sentryFirstResponderStatus.get(), next)) {
    sentryFirstResponderStatus.set(next)
    sentryFirstResponderTick.set(sentryFirstResponderTick.get() + 1)
  }
}

function isStatusWritePath(path: string | null): boolean {
  if (path === null) return false
  return path.endsWith("/status.json") || /\/\.status\.json\.\d+\.tmp$/.test(path)
}

GLib.mkdir_with_parents(STATUS_DIR, 0o755)

const dirFile = Gio.File.new_for_path(STATUS_DIR)
const monitor = dirFile.monitor_directory(Gio.FileMonitorFlags.NONE, null)
retainedDirectoryMonitors.push(monitor)
monitor.set_rate_limit(50)
monitor.connect("changed", (_m, file, other) => {
  if (isStatusWritePath(file.get_path()) || isStatusWritePath(other?.get_path() ?? null)) {
    refreshSentryFirstResponderStatus()
  }
})

export function formatSentryFirstResponderElapsed(state: SentryFirstResponderState): string {
  const timestamp = state.last_run_at || state.updated_at
  if (!timestamp) return "--"

  try {
    const updated = new Date(timestamp).getTime()
    const elapsed = Math.max(0, Math.floor((Date.now() - updated) / 1000))
    if (elapsed < 60) return `${elapsed}s`
    if (elapsed < 3600) return `${Math.floor(elapsed / 60)}m`
    if (elapsed < 86400) return `${Math.floor(elapsed / 3600)}h`
    return `${Math.floor(elapsed / 86400)}d`
  } catch {
    return "--"
  }
}
