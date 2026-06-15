import { Widget } from "astal/gtk4"
import { bind } from "astal"
import GLib from "gi://GLib"
import Gtk from "gi://Gtk?version=4.0"
import {
  formatSentryFirstResponderElapsed,
  refreshSentryFirstResponderStatus,
  sentryFirstResponderStatus,
  sentryFirstResponderTick,
  SentryFirstResponderState,
} from "../service/SentryFirstResponderStatus"

const SOURCE_PAGE_URL = "https://app.notion.com/p/xo-life/Sentry-First-Responder-1e360df5e8bc80e79aefcb5ec469318d"

function statusClasses(state: SentryFirstResponderState): string[] {
  return [
    "sentry-first-responder-widget",
    `sentry-first-responder-${state.status}`,
    state.attention_needed ? "sentry-first-responder-needs-attention" : "sentry-first-responder-clear",
  ]
}

function iconName(state: SentryFirstResponderState): string {
  if (state.status === "running") return "view-refresh-symbolic"
  if (state.status === "ok") return "emblem-ok-symbolic"
  if (state.status === "missing") return "dialog-question-symbolic"
  return "dialog-warning-symbolic"
}

function labelText(state: SentryFirstResponderState): string {
  const elapsed = formatSentryFirstResponderElapsed(state)
  if (state.status === "running") return "Sentry now"
  if (state.status === "missing") return "Sentry --"
  if (state.status === "error") return `Sentry err ${elapsed}`
  if (state.attention_needed) return `Sentry ! ${elapsed}`
  return `Sentry ${elapsed}`
}

function tooltipText(state: SentryFirstResponderState): string {
  const lines = [
    "Sentry First Responder",
    `Status: ${state.status}`,
    `Attention: ${state.attention_needed ? "needed" : "clear"}`,
  ]

  if (state.last_run_at) lines.push(`Last run: ${state.last_run_at}`)
  if (state.message) lines.push(state.message)
  if (state.details) lines.push(state.details)
  if (state.slack_channel) lines.push(`Slack: ${state.slack_channel}`)
  if (state.jira_url) lines.push(`Jira: ${state.jira_url}`)
  if (state.sentry_url) lines.push(`Sentry: ${state.sentry_url}`)

  lines.push("Click: open source or linked issue. Right-click: refresh.")
  return lines.join("\n")
}

function targetUrl(state: SentryFirstResponderState): string {
  return state.sentry_url || state.jira_url || SOURCE_PAGE_URL
}

function openUrl(url: string): void {
  GLib.spawn_command_line_async(`xdg-open ${GLib.shell_quote(url)}`)
}

export default function SentryFirstResponderStatus() {
  return Widget.Button({
    css_classes: bind(sentryFirstResponderStatus).as(statusClasses),
    tooltip_text: bind(sentryFirstResponderStatus).as(tooltipText),
    valign: Gtk.Align.CENTER,
    child: Widget.Box({
      css_classes: ["sentry-first-responder-content"],
      halign: Gtk.Align.CENTER,
      valign: Gtk.Align.CENTER,
      spacing: 6,
      children: [
        Widget.Image({
          iconName: bind(sentryFirstResponderStatus).as(iconName),
        }),
        Widget.Label({
          label: bind(sentryFirstResponderTick).as(() => labelText(sentryFirstResponderStatus.get())),
        }),
      ],
    }),
    onClicked: () => openUrl(targetUrl(sentryFirstResponderStatus.get())),
    setup: (self: Gtk.Button) => {
      const rightClick = Gtk.GestureClick.new()
      rightClick.set_button(3)
      rightClick.connect("released", () => refreshSentryFirstResponderStatus())
      self.add_controller(rightClick)
    },
  })
}
