import AstalNetwork from "gi://AstalNetwork?version=0.1"
import NM from "gi://NM?version=1.0"
import GLib from "gi://GLib"
import Gio from "gi://Gio"

import { Widget, Gtk } from "astal/gtk4"
import { bind, Variable, Binding } from "astal"

const CACHE_FILE = GLib.build_filenamev([
  GLib.get_user_cache_dir(),
  "ags",
  "network-types.json",
])

function loadCache(): Record<string, boolean> {
  try {
    const [ok, contents] = GLib.file_get_contents(CACHE_FILE)
    if (ok) return JSON.parse(new TextDecoder().decode(contents))
  } catch {}
  return {}
}

function saveCache(cache: Record<string, boolean>) {
  try {
    GLib.mkdir_with_parents(GLib.path_get_dirname(CACHE_FILE), 0o755)
    GLib.file_set_contents(CACHE_FILE, JSON.stringify(cache, null, 2))
  } catch (e) {
    console.error(`network: failed to save cache: ${e}`)
  }
}

// Metered networks (Android hotspots advertise ANDROID_METERED via DHCP)
// get a phone icon; everything else keeps the signal-strength wifi icon.
// Results are cached per SSID. UNKNOWN is not cached — it resolves
// once DHCP finishes and the device notifies about metered.
function isHotspot(net: AstalNetwork.Network, ssid: string): boolean {
  const cache = loadCache()
  if (ssid in cache) return cache[ssid]

  const metered = net.wifi?.device?.metered ?? NM.Metered.UNKNOWN
  if (metered === NM.Metered.UNKNOWN) return false

  const hotspot =
    metered === NM.Metered.YES || metered === NM.Metered.GUESS_YES
  cache[ssid] = hotspot
  saveCache(cache)
  return hotspot
}

// Passwords are never stored here: connecting via nmcli makes
// NetworkManager save a connection profile (its system connection store),
// which is also how already-known networks are found again.
function knownProfiles(net: AstalNetwork.Network): Map<string, string> {
  const map = new Map<string, string>()
  try {
    for (const conn of net.wifi?.device?.client?.get_connections() ?? []) {
      const bytes = conn.get_setting_wireless()?.get_ssid()
      if (!bytes) continue
      const ssid = new TextDecoder().decode(bytes.toArray()).replace(/\0/g, "")
      if (ssid && !map.has(ssid)) map.set(ssid, conn.get_id())
    }
  } catch (e) {
    console.error(`network: failed to list profiles: ${e}`)
  }
  return map
}

function isSecured(ap: AstalNetwork.AccessPoint): boolean {
  // rsn/wpa flags cover WPA*, flags & 1 is NM 80211ApFlags.PRIVACY (WEP)
  return (ap.rsnFlags | ap.wpaFlags) !== 0 || (ap.flags & 1) !== 0
}

function nmcli(args: string[], onDone: (ok: boolean, out: string) => void) {
  try {
    const proc = Gio.Subprocess.new(
      ["nmcli", ...args],
      Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_MERGE,
    )
    proc.communicate_utf8_async(null, null, (p, res) => {
      try {
        const [, out] = p!.communicate_utf8_finish(res)
        onDone(p!.get_successful(), (out ?? "").trim())
      } catch (e) {
        onDone(false, String(e))
      }
    })
  } catch (e) {
    onDone(false, String(e))
  }
}

function apRows(
  net: AstalNetwork.Network,
  aps: AstalNetwork.AccessPoint[],
  current: string,
  onPick: (ap: AstalNetwork.AccessPoint) => void,
): Gtk.Widget[] {
  const seen = new Map<string, AstalNetwork.AccessPoint>()
  for (const ap of aps) {
    if (!ap.ssid) continue
    const prev = seen.get(ap.ssid)
    if (!prev || ap.strength > prev.strength) seen.set(ap.ssid, ap)
  }

  return [...seen.values()]
    .sort((a, b) => b.strength - a.strength)
    .map((ap) =>
      Widget.Button({
        css_classes:
          ap.ssid === current
            ? ["network-ap-row", "active"]
            : ["network-ap-row"],
        onClicked: () => onPick(ap),
        child: Widget.Box({
          spacing: 8,
          children: [
            Widget.Image({ iconName: ap.iconName }),
            Widget.Label({
              label: ap.ssid,
              halign: Gtk.Align.START,
              hexpand: true,
              max_width_chars: 28,
            }),
            ...(isSecured(ap)
              ? [Widget.Image({ iconName: "network-wireless-encrypted-symbolic" })]
              : []),
            ...(ap.ssid === current
              ? [Widget.Image({ iconName: "object-select-symbolic" })]
              : []),
          ],
        }),
      }),
    )
}

function SelectorPopover(net: AstalNetwork.Network, pill: Gtk.Widget): Gtk.Popover {
  const wifi = net.wifi!

  const status = Variable("")
  const passwordFor = Variable<string | null>(null)

  const connectTo = (ssid: string, password?: string) => {
    status.set(`Connecting to ${ssid}…`)
    const profile = knownProfiles(net).get(ssid)
    const args =
      password !== undefined
        ? ["dev", "wifi", "connect", ssid, "password", password]
        : profile
          ? ["connection", "up", "id", profile]
          : ["dev", "wifi", "connect", ssid]
    nmcli(args, (ok, out) => {
      if (ok) {
        status.set("")
        passwordFor.set(null)
      } else {
        status.set(out.split("\n")[0] || "Connection failed")
      }
    })
  }

  const onPick = (ap: AstalNetwork.AccessPoint) => {
    const ssid = ap.ssid
    if (!ssid || ssid === wifi.ssid) return
    if (knownProfiles(net).has(ssid) || !isSecured(ap)) {
      passwordFor.set(null)
      connectTo(ssid)
    } else {
      status.set("")
      passwordFor.set(ssid)
    }
  }

  const rows = Variable.derive(
    [bind(wifi, "access-points"), bind(wifi, "ssid")],
    (aps, current) => apRows(net, aps, current, onPick),
  )

  const spinner = new Gtk.Spinner()
  spinner.visible = wifi.scanning
  if (wifi.scanning) spinner.start()
  wifi.connect("notify::scanning", () => {
    spinner.visible = wifi.scanning
    wifi.scanning ? spinner.start() : spinner.stop()
  })

  const header = Widget.Box({
    spacing: 8,
    children: [
      Widget.Label({
        label: "Wi-Fi",
        css_classes: ["network-selector-title"],
        halign: Gtk.Align.START,
        hexpand: true,
      }),
      spinner,
      Widget.Button({
        css_classes: ["network-rescan"],
        tooltip_text: "Rescan",
        sensitive: bind(wifi, "scanning").as((s) => !s),
        child: Widget.Image({ iconName: "view-refresh-symbolic" }),
        onClicked: () => wifi.scan(),
      }),
    ],
  })

  const listBox = Widget.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 2,
    children: bind(rows),
  })

  const scroll = new Gtk.ScrolledWindow()
  scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
  scroll.set_max_content_height(320)
  scroll.set_propagate_natural_height(true)
  scroll.set_child(listBox)

  const passwordEntry = new Gtk.PasswordEntry({
    placeholder_text: "Password",
    show_peek_icon: true,
  })
  passwordEntry.connect("activate", () => {
    const ssid = passwordFor.get()
    const pw = passwordEntry.get_text()
    if (!ssid || !pw) return
    passwordEntry.set_text("")
    connectTo(ssid, pw)
  })

  const passwordBox = Widget.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 6,
    visible: bind(passwordFor).as((s) => s !== null),
    children: [
      Widget.Label({
        label: bind(passwordFor).as((s) => `Password for ${s ?? ""}`),
        halign: Gtk.Align.START,
      }),
      passwordEntry,
      Widget.Button({
        css_classes: ["network-connect"],
        label: "Connect",
        onClicked: () => {
          const ssid = passwordFor.get()
          const pw = passwordEntry.get_text()
          if (!ssid || !pw) return
          passwordEntry.set_text("")
          connectTo(ssid, pw)
        },
      }),
    ],
  })

  const root = Widget.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 8,
    children: [
      header,
      scroll,
      passwordBox,
      Widget.Label({
        label: bind(status),
        visible: bind(status).as((s) => s !== ""),
        css_classes: ["network-selector-status"],
        wrap: true,
        max_width_chars: 36,
      }),
    ],
  })

  const popover = new Gtk.Popover()
  popover.set_parent(pill)
  popover.set_child(root)
  // Popover expand propagates from its content: in a full-width layer-shell
  // bar the pill box would grow to share the window's spare width while open.
  popover.set_hexpand(false)
  return popover
}

export default function Network() {
  const net = AstalNetwork.get_default()

  const deps: Binding<any>[] = [bind(net, "primary")]
  if (net.wifi) {
    deps.push(bind(net.wifi, "icon-name"), bind(net.wifi, "ssid"))
    if (net.wifi.device) deps.push(bind(net.wifi.device, "metered"))
  }
  if (net.wired) deps.push(bind(net.wired, "icon-name"))

  const icon = Variable.derive(deps, () => {
    if (net.primary === AstalNetwork.Primary.WIFI && net.wifi) {
      const ssid = net.wifi.ssid
      if (ssid && isHotspot(net, ssid)) return "phone-symbolic"
      return net.wifi.iconName
    }
    const dev = net.primary === AstalNetwork.Primary.WIRED ? net.wired : null
    return dev?.iconName ?? "network-offline-symbolic"
  })

  const pill = Widget.Box({
    css_classes: ["network-widget"],
    children: [
      Widget.Image({
        iconName: bind(icon),
      }),
    ],
  })

  const gesture = Gtk.GestureClick.new()
  gesture.set_button(1)
  gesture.connect("pressed", () => {
    if (net.wifi) {
      SelectorPopover(net, pill).popup()
      return
    }

    const label =
      net.primary === AstalNetwork.Primary.WIRED ? "Wired" : "Disconnected"

    const popover = new Gtk.Popover()
    popover.set_parent(pill)
    popover.set_child(Widget.Label({ label }))
    popover.popup()
  })
  pill.add_controller(gesture)

  return pill
}
