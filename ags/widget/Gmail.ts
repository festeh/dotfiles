import { Widget } from "astal/gtk4"
import { Variable, bind } from "astal"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import Gtk from "gi://Gtk?version=4.0"

const GOOGLE_POLL_SECONDS = 180
const GMAIL_URL = "https://mail.google.com/mail/u/0/#inbox"
const CALENDAR_URL = "https://calendar.google.com/calendar/u/0/r"
const GOOGLE_HELPER = `${SRC}/scripts/gmail-unread.py`
const HOME = GLib.get_home_dir()
const UV_CANDIDATES = [
  "uv",
  `${HOME}/.local/bin/uv`,
  `${HOME}/.local/share/mise/shims/uv`,
  `${HOME}/.cargo/bin/uv`,
  "/usr/bin/uv",
]

type GmailStatus = "loading" | "ok" | "setup" | "error"
type CalendarStatus = "loading" | "free" | "busy" | "next" | "setup" | "error"

type GmailLabelBucket = {
  name: string
  unread: number
}

type CalendarState = {
  status: CalendarStatus
  label: string
  title: string
  message: string
  startsAt?: string
  endsAt?: string
  url?: string
}

type GmailState = {
  status: GmailStatus
  unread: number
  labels: GmailLabelBucket[]
  message: string
  calendar: CalendarState
}

const loadingCalendar: CalendarState = {
  status: "loading",
  label: "...",
  title: "",
  message: "Loading Calendar",
}

const gmail = Variable<GmailState>({
  status: "loading",
  unread: 0,
  labels: [],
  message: "Loading Gmail",
  calendar: loadingCalendar,
})

let refreshRunning = false

function executablePath(candidate: string): string | null {
  if (!candidate.includes("/")) return GLib.find_program_in_path(candidate)
  return GLib.file_test(candidate, GLib.FileTest.IS_EXECUTABLE) ? candidate : null
}

function findUv(): string | null {
  for (const candidate of UV_CANDIDATES) {
    const path = executablePath(candidate)
    if (path !== null) return path
  }

  return null
}

function gmailIconName(state: GmailState): string {
  if (state.status === "ok" && state.unread === 0) return "mail-read-symbolic"
  if (state.status === "setup" || state.status === "error") return "dialog-warning-symbolic"
  return "mail-unread-symbolic"
}

function calendarIconName(state: CalendarState): string {
  if (state.status === "setup" || state.status === "error") return "dialog-warning-symbolic"
  return "x-office-calendar-symbolic"
}

function sanitizeLabel(value: string, maxLength = 18): string {
  const compact = value.replace(/\s+/g, " ").trim()
  if (compact.length <= maxLength) return compact
  return `${compact.slice(0, Math.max(0, maxLength - 3))}...`
}

function gmailBucketsText(labels: GmailLabelBucket[]): string {
  return labels
    .filter((label) => label.unread > 0)
    .map((label) => `${sanitizeLabel(label.name)} ${label.unread}`)
    .join(" ")
}

function gmailBucketsTooltipText(labels: GmailLabelBucket[]): string {
  return labels
    .filter((label) => label.unread > 0)
    .map((label) => `${label.name} ${label.unread}`)
    .join(", ")
}

function gmailLabelText(state: GmailState): string {
  if (state.status === "loading") return "..."
  if (state.status === "setup" || state.status === "error") return "!"
  if (state.unread === 0) return "Empty"
  return gmailBucketsText(state.labels) || `Other ${state.unread}`
}

function calendarLabelText(state: CalendarState): string {
  if (state.status === "loading") return "..."
  if (state.status === "setup" || state.status === "error") return "!"
  return state.label
}

function gmailTooltipText(state: GmailState): string {
  if (state.status === "ok") {
    const buckets = gmailBucketsTooltipText(state.labels)
    if (buckets) return `Unread Gmail: ${buckets}`
    return state.unread === 1 ? "1 unread Gmail message" : `${state.unread} unread Gmail messages`
  }
  return state.message
}

function calendarTooltipText(state: CalendarState): string {
  return state.message
}

function gmailCssClasses(state: GmailState): string[] {
  const classes = ["gmail-widget", `gmail-${state.status}`]
  classes.push(state.unread > 0 ? "gmail-unread" : "gmail-empty")
  return classes
}

function calendarCssClasses(state: CalendarState): string[] {
  return ["calendar-status-widget", `calendar-status-${state.status}`]
}

function parseCalendar(value: unknown, fallbackMessage: string): CalendarState {
  if (value === null || typeof value !== "object") {
    return {
      status: "error",
      label: "!",
      title: "",
      message: fallbackMessage || "Calendar status missing",
    }
  }

  const candidate = value as Partial<CalendarState>
  const status = candidate.status === "free"
    || candidate.status === "busy"
    || candidate.status === "next"
    || candidate.status === "setup"
    || candidate.status === "error"
    ? candidate.status
    : "error"

  return {
    status,
    label: typeof candidate.label === "string" ? candidate.label : "!",
    title: typeof candidate.title === "string" ? candidate.title : "",
    message: typeof candidate.message === "string" ? candidate.message : fallbackMessage,
    startsAt: typeof candidate.startsAt === "string" ? candidate.startsAt : undefined,
    endsAt: typeof candidate.endsAt === "string" ? candidate.endsAt : undefined,
    url: typeof candidate.url === "string" ? candidate.url : undefined,
  }
}

function parseGmailLabels(value: unknown): GmailLabelBucket[] {
  if (!Array.isArray(value)) return []

  return value.flatMap((item): GmailLabelBucket[] => {
    if (item === null || typeof item !== "object") return []

    const candidate = item as Partial<GmailLabelBucket>
    const name = typeof candidate.name === "string" ? candidate.name.trim() : ""
    const unread = typeof candidate.unread === "number" ? Math.trunc(candidate.unread) : 0
    if (!name || unread <= 0) return []

    return [{ name, unread }]
  })
}

function parseState(stdout: string, stderr: string): GmailState {
  try {
    const value = JSON.parse(stdout) as Partial<GmailState>
    const status = value.status === "ok" || value.status === "setup" || value.status === "error"
      ? value.status
      : "error"
    const message = typeof value.message === "string" ? value.message : stderr.trim()

    return {
      status,
      unread: typeof value.unread === "number" ? value.unread : 0,
      labels: parseGmailLabels(value.labels),
      message,
      calendar: parseCalendar(value.calendar, message),
    }
  } catch {
    const message = stderr.trim() || stdout.trim() || "Google helper returned invalid JSON"
    return {
      status: "error",
      unread: 0,
      labels: [],
      message,
      calendar: {
        status: "error",
        label: "!",
        title: "",
        message,
      },
    }
  }
}

function refreshGmail(): void {
  if (refreshRunning) return

  const uv = findUv()
  if (uv === null) {
    gmail.set({
      status: "setup",
      unread: 0,
      labels: [],
      message: "uv is not available to the AGS service",
      calendar: {
        status: "setup",
        label: "!",
        title: "",
        message: "uv is not available to the AGS service",
      },
    })
    return
  }

  refreshRunning = true

  let process: Gio.Subprocess
  try {
    process = Gio.Subprocess.new(
      [uv, "run", "--script", GOOGLE_HELPER],
      Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
    )
  } catch (error) {
    const message = String(error)
    gmail.set({
      status: "error",
      unread: 0,
      labels: [],
      message,
      calendar: {
        status: "error",
        label: "!",
        title: "",
        message,
      },
    })
    refreshRunning = false
    return
  }

  process.communicate_utf8_async(null, null, (_proc, result) => {
    try {
      const [, stdout, stderr] = process.communicate_utf8_finish(result)
      gmail.set(parseState(stdout, stderr))
    } catch (error) {
      const message = String(error)
      gmail.set({
        status: "error",
        unread: 0,
        labels: [],
        message,
        calendar: {
          status: "error",
          label: "!",
          title: "",
          message,
        },
      })
    } finally {
      refreshRunning = false
    }
  })
}

function openUrl(url: string): void {
  GLib.spawn_command_line_async(`xdg-open ${GLib.shell_quote(url)}`)
}

refreshGmail()
GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, GOOGLE_POLL_SECONDS, () => {
  refreshGmail()
  return GLib.SOURCE_CONTINUE
})

export default function Gmail() {
  return Widget.Box({
    css_classes: ["google-status"],
    valign: Gtk.Align.CENTER,
    spacing: 4,
    children: [
      Widget.Button({
        css_classes: bind(gmail).as(gmailCssClasses),
        tooltip_text: bind(gmail).as(gmailTooltipText),
        valign: Gtk.Align.CENTER,
        child: Widget.Box({
          css_classes: ["gmail-content"],
          halign: Gtk.Align.CENTER,
          valign: Gtk.Align.CENTER,
          spacing: 6,
          children: [
            Widget.Image({
              iconName: bind(gmail).as(gmailIconName),
            }),
            Widget.Label({
              label: bind(gmail).as(gmailLabelText),
            }),
          ],
        }),
        onClicked: () => {
          openUrl(GMAIL_URL)
        },
      }),
      Widget.Button({
        css_classes: bind(gmail).as((state) => calendarCssClasses(state.calendar)),
        tooltip_text: bind(gmail).as((state) => calendarTooltipText(state.calendar)),
        valign: Gtk.Align.CENTER,
        child: Widget.Box({
          css_classes: ["calendar-status-content"],
          halign: Gtk.Align.CENTER,
          valign: Gtk.Align.CENTER,
          spacing: 6,
          children: [
            Widget.Image({
              iconName: bind(gmail).as((state) => calendarIconName(state.calendar)),
            }),
            Widget.Label({
              label: bind(gmail).as((state) => calendarLabelText(state.calendar)),
            }),
          ],
        }),
        onClicked: () => {
          const calendar = gmail.get().calendar
          openUrl(calendar.url ?? CALENDAR_URL)
        },
      }),
    ],
  })
}
