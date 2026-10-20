# Quickshell bar experiment

Volume, network, battery, clock, calendar, and tray built independently of AGS. `Theme.qml` borrows its Catppuccin colors,
rounded container, and right alignment from `ags/style.css`.

Run `./quickshell/run` from the dotfiles checkout, or
`quickshell --path ~/dotfiles/quickshell`. Quickshell reloads QML edits live;
restart the preview after editing imported JavaScript logic.
Stop with `quickshell --path ~/dotfiles/quickshell kill`.
This preview is started manually; it is not enabled at login.

Each monitor gets a transparent row below panels that already reserve space
(currently AGS). The compositor handles placement without polling or a fixed
AGS height. Only the volume, network, battery, clock, and tray receive pointer input. The row reserves 44 pixels;
the clock remains visible when there are no tray items. All tray items remain visible, including
passive items, so applications do not silently disappear.

- Left click activates an application, or opens its menu for menu-only items.
- Right click opens the native menu, including dynamic and nested submenus.
  Its Catppuccin skin adds rounded corners, compact rows, mauve selection,
  matching separators, and custom checkbox/radio indicators.
- Middle click sends the application's secondary action.
- Vertical and horizontal scrolling are forwarded to the application.
- After clicking an icon, use Left/Right, Home/End, or Tab to navigate.
  Enter/Space activates; Menu or Shift+F10 opens the menu; Escape clears focus.
- Pointer movement clears the keyboard highlight, so only the current icon is
  highlighted. Keyboard navigation restores its own focus indicator.
- Tooltips use one compact line with normalized whitespace and 6px horizontal /
  3px vertical padding. Long text is elided. Items requesting attention get a
  yellow border and dot.

## Volume

The volume pill sits immediately left of the network. Its rounded speaker icon
shows three volume levels; zero has no waves, mute adds a soft red × beside the speaker, and
unavailable data is gray with a question mark. Hover for the output name, mute
state, and exact percentage in one compact line.

The bar groups the speaker with compact −/+ buttons and shows no percentage.
Left click on the speaker toggles mute; −/+ adjust by 5%, matching AGS.
Right click opens Sound controls; scrolling changes volume by 2% per notch.
Tab moves between buttons and Enter/Space activates the focused button. Down,
Menu, or Shift+F10 opens the popup; middle click or M also toggles mute.
Each button has its own hover/focus highlight. The rounded popup has a mauve
slider, percentage, explicit Mute/Unmute action, and an output list with the
current device highlighted. Device nicknames keep labels such as Speaker and
HDMI 1 readable without a repeated hardware prefix. Escape, the close button, or an outside click closes
it. Only one sound popup can be open across outputs, and it is created on demand.

`VolumeState.qml` uses the stock native PipeWire service, enabled at build time.
All outputs share one connection, and only the current output's detailed audio
properties are tracked. Changes from other applications, device removal, and
PipeWire restarts update the widget through events. There is no polling timer,
audio helper process, peak meter, or added Quickshell source patch.

Percentage follows the loudest channel. Adjustments preserve channel balance,
including through zero, and leave mute unchanged. Controls cannot increase
volume above 100%; externally boosted values remain visible and wheel-down can
reduce them gradually. A drag that began on a different default output cannot
change the replacement device. Selecting an output sets PipeWire's preferred
default; WirePlumber applies that preference, and the highlight follows the
actual default. A failed switch reports an inline message after five seconds.

## Network

The network pill sits immediately left of the battery. Its vector icon shows
Wi-Fi strength in three coarse levels (dot, one arc, two arcs), Ethernet, or
another primary connection type. The tooltip retains the exact signal percentage.
Connected metered
Wi-Fi uses a phone icon, following the agreed hotspot heuristic; this does not
prove the access point is a phone. The native service remembers the classification
per SSID, uses cached recognition when metering is unknown, and updates it when
NetworkManager reports a known value. Cache keys are hashes, not plaintext SSIDs.

Hover, or focus with Tab, for one compact line containing the connection name,
Wi-Fi strength and band when available, metering, and connectivity status.
Disabled radios, hardware blocks, connecting/disconnecting, failures, and
disconnected states have distinct descriptions. Captive portals and limited/no
internet get a yellow warning only when NetworkManager connectivity checking is
available and enabled. Unknown strength stays unknown rather than showing 0%.

`NetworkState.qml` shares the local runtime's `NetworkStatus` D-Bus service across
outputs. It observes the primary connection, its device, and active access point;
signal changes update the icon and tooltip live. There are no polling commands,
periodic timers, scan requests, or extra network probes. The service clears and
reloads state when NetworkManager restarts or the system resumes.
Click or press Enter/Space/Down to open the Wi-Fi picker. It pins the connected
network first and orders other networks by live strength, with stable name ties.
List items show signal icons without percentages; the bar tooltip keeps the exact value.
It groups access points by raw SSID and security family, so an open access point
cannot replace a secured network with the same name. The connected row reports
the active access point's strength rather than a stronger unconnected neighbour.
Use Up/Down/Home/End and Enter to select a network; Escape or an outside click
closes the popup. Escape first cancels an open password prompt.

Saved compatible profiles are reused, choosing the most recently used profile.
New personal WPA/WPA2/WPA3 networks prompt for a masked password; open and
enhanced-open networks connect directly. A failed personal connection allows
password retry. Updating a saved password preserves the profile UUID and other
settings. NetworkManager owns profile and secret storage. Passwords travel over
the helper's stdin and D-Bus, never command arguments or our cache files, and the
input clears on submit, cancel, and close. New enterprise/WEP configurations need
a configured NetworkManager profile. The explicit Disconnect and Turn off
buttons control Wi-Fi; selecting the already connected row does nothing.

`network_picker.py` uses the installed Python/PyGObject/libnm stack. One helper
runs only while a picker is open; only one picker can be open across outputs.
It requests one scan when opened or Wi-Fi is enabled, and another on Refresh.
There are no periodic scans: libnm signals update the list and signal ordering,
and idle callbacks coalesce changes. A one-shot timeout ends a pending scan's
visual state. Closing the picker removes the helper and its subscriptions while
the bar's native status observer continues. This adds no Quickshell core patches.

## Battery

The battery sits immediately left of the clock. Its vertical vector indicator
fills from the bottom to the actual charge level. Charging uses green without
an overlay; external power shows a plug when not charging. The bar shows only the icon in a fixed-width
pill; the exact percentage is available on hover.
While discharging on battery power, the icon stays text gray above 20%, turns
yellow at 11–20%, peach at 6–10%, and red at 0–5%. Charging overrides the
percentage color with green; paused charging stays neutral. The low (20%) and
critical (5%) thresholds match the current UPower policy on this machine.
Missing batteries are hidden; unavailable data
shows a question mark instead of an invented `0%`.

Hover, or focus with Tab, for a compact one-line tooltip containing the percentage, state,
approximate remaining/charging time, and power in watts when available. Unknown
estimates are omitted. Direction comes from the charging state, not the sign of
the rate, and paused/complete states do not reuse stale estimates.

`BatteryState.qml` shares the native UPower display device across outputs and
reacts to D-Bus property changes. There is no battery timer, command polling,
notification sender, power-mode switch, or charging-limit control. UPower owns
hardware refreshes, including after resume. The existing AGS notification service
and system power policy continue to operate independently.

## Clock and calendar

The clock sits immediately left of the tray and displays 24-hour `HH:mm`.
Hover for the full date; click or press Enter/Space/Down to open the calendar.
The calendar starts weeks on Monday, highlights today, and supports previous /
next month, selecting a date, and returning to Today. Arrow keys move the
selection, Page Up/Down changes the month, Home returns to today, and Escape
or an outside click closes it. The calendar is created only while open.

`ClockState.qml` shares one minute-precision `SystemClock` across all outputs.
There is no per-second polling and no spawned clock/date process. On Linux,
the local runtime uses a one-shot absolute `CLOCK_REALTIME` timerfd for the
next minute boundary. It advances during suspend and becomes readable after
an overdue deadline on resume; it does not wake the laptop. Clock changes
cancel and immediately realign that deadline. A portable Qt timer remains
available if timerfd cannot be created. Opening the calendar also refreshes
the clock immediately.
Precision rounding preserves the correct occurrence of an hour during DST
fall-back, avoiding past deadlines and repeated immediate wakeups.

AGS's current relative minute timer can preserve its remaining delay over
suspend; that is a code-based explanation of the reported delay, rather than
a captured lid-close trace. The new implementation does not use that timer.
Calendar arithmetic uses local civil dates at noon to handle month ends,
leap years, and DST without skipping dates.

Applications decide what activation, secondary activation, and scrolling do.
The tray uses Quickshell's event-driven StatusNotifier service and native menu
anchors; it does not poll applications or run commands for clicks.
It can share the existing StatusNotifierWatcher with AGS.
Icons are sorted by category and application ID so their order survives reloads.
Native menus use `menu.qss` for their appearance, including nested menus.
Restart the preview after changing this stylesheet; QML edits reload live.
Missing icons remain empty in both the tray and menus. The preview uses the compose input
context and skips portal registration to avoid Qt Wayland input and duplicate
portal-registration warnings. The Wi-Fi picker uses a Qt Quick password field.
Icons use Breeze Dark first and Adwaita as a fallback. Blueman supplies GTK
symbolic icon names that Breeze lacks, so Adwaita supplies those without
replacing icons already found in Breeze or application-specific icon directories.
Symbolic icons are tinted to the menu text color so Adwaita's dark source
artwork remains readable against the dark menu background.

## Hyprland workspaces and app icons plan

Scope: add workspace groups with an app icon for every window to the left of
the preview bar, including separate icons for multiple windows of the same app.
Keep the existing status widgets on the right.
Agentic status, agent pills, session/process inspection, and workspace renaming
are out of scope. AGS supplies the visual reference; implement state and
interaction independently. This section is a plan, not an implemented feature.

1. **Probe the native service first.** Use the already enabled
   `Quickshell.Hyprland` module in an isolated read-only probe against the installed
   Hyprland 0.56.2. Check workspace/window membership, focus updates, Wayland app-ID
   mapping, and Lua mode. Then validate workspace and exact-window activation
   with disposable test windows before wiring clicks into the bar. Prefer the stock
   `workspace.activate()` method: the checked-out runtime already selects Lua
   dispatcher syntax when `Hyprland.usingLua` is true. No new core patch is planned.

2. **Build the workspace strip before icons.** Show existing normal workspaces
   across monitors, sorted numerically, with deterministic ordering for named
   workspaces. Distinguish special workspaces by their identity/name rather than
   copying AGS's negative-ID range filter. Match AGS's compact numbered buttons,
   rounded groups, and mauve focused state; distinguish the focused workspace
   from a workspace merely visible on another monitor. Support click and
   keyboard activation, independent hover, and a compact one-line tooltip.
   Use stable workspace identities so a focus change updates delegates without
   rebuilding the complete row. Bound the left strip's width and allow horizontal
   overflow without covering the status row. Extend the input mask to the union
   of the two rows so the unused center stays click-through.

3. **Add an icon for every window inside its workspace group.** Build each group
   from the native workspace's live toplevel model. Keep one icon per window,
   including duplicate application icons, with stable ordering that does not
   change when focus changes. Key each delegate by window address; insert, remove,
   or move only the affected window when membership changes. Give the focused
   window a distinct highlight. Clicking the workspace number activates the
   workspace; clicking an app icon focuses that exact window. Prefer the mapped
   Wayland toplevel's activation method and verify cross-workspace activation in
   the probe; review a Lua IPC fallback for unmapped windows if needed. Hover
   shows a compact one-line app name and window title so duplicate icons remain
   distinguishable. Prefer the mapped Wayland `appId`; use IPC class metadata
   when needed. Resolve exact desktop IDs and `StartupWMClass` through
   `DesktopEntries`, with explicit aliases only for unresolved applications.
   Cache the lookup and invalidate it when application metadata changes, including
   previously missing matches. Unknown or missing artwork uses a small neutral
   window symbol, keeping every window visible and focusable without a
   checkerboard. Empty workspaces retain their numbered button.

4. **Keep state shared and driven by events.** One `WorkspaceState.qml` owns
   selection and icon resolution for all monitor views. Use native workspace,
   toplevel, and desktop-entry notifications. Coalesce only events that need
   fresh IPC metadata, and update affected workspaces. Treat `lastIpcObject` as
   a snapshot, not a continuously updated property. Avoid repeating timers,
   `hyprctl` polling, shell processes per window, and permanent failed icon caches.

5. **Verify lifecycle and failure behavior before calling it complete.** Test
   focus changes, workspace creation/removal/rename, window open/close/move,
   duplicate app windows and exact-window activation, missing or changing app
   IDs/icons, named/special workspaces, overflow, and
   monitor changes with isolated fixtures, then inspect the live bar. Measure
   idle IPC traffic and preserve unrelated windows and workspaces during checks.
   The current native connection logs an event-socket disconnect but does not
   automatically reconnect in the inspected implementation. Test that failure
   explicitly, document the reload/restart recovery path, and review a stock-API
   or upstream remedy separately before promising automatic reconnection.

Implementation order: native probe, workspace buttons, app icons, then lifecycle
checks and polish. Review the visible result after each step.

References: [native Hyprland service](https://quickshell.org/docs/v0.3.2/types/Quickshell.Hyprland/Hyprland/),
[workspace API](https://quickshell.org/docs/v0.3.2/types/Quickshell.Hyprland/HyprlandWorkspace/),
and the local sources `src/wayland/hyprland/ipc/` and `src/core/desktopentry.hpp`
in `~/github/quickshell`. AGS visual references are `ags/widget/HyprlandStatus.ts`
and the workspace rules in `ags/style.css`.

## Local runtime

Upstream source: `~/github/quickshell`, fetched from
<https://github.com/quickshell-mirror/quickshell>.
The local runtime is built against the host Qt version and installed under
`~/.local`. Rebuild Quickshell after Qt upgrades: it uses private Qt APIs.

The current build enables PipeWire, networking, UPower, the tray, Wayland panels, Hyprland integration, and
Unix sockets. Other desktop services and the crash reporter are disabled for
this experiment. The build configuration is recorded in
`~/github/quickshell/build/CMakeCache.txt`.

```sh
cmake -S ~/github/quickshell -B ~/github/quickshell/build -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
  -DCMAKE_PREFIX_PATH="$HOME/.local" -DINSTALL_QML_PREFIX=lib/qt6/qml \
  -DDISTRIBUTOR='Local tray prototype' -DCRASH_HANDLER=OFF -DSCREENCOPY=OFF \
  -DSERVICE_PIPEWIRE=ON -DSERVICE_MPRIS=OFF -DSERVICE_PAM=OFF \
  -DSERVICE_POLKIT=OFF -DSERVICE_GREETD=OFF -DSERVICE_UPOWER=ON \
  -DSERVICE_NOTIFICATIONS=OFF -DBLUETOOTH=OFF -DNETWORK=ON -DX11=OFF \
  -DI3=OFF -DWAYLAND_SESSION_LOCK=OFF -DWAYLAND_TOPLEVEL_MANAGEMENT=ON
./quickshell/build-runtime
```

CLI11 headers and their CMake package were installed to `~/.local` from
`~/.cache/quickshell-deps/CLI11`; no system packages were replaced.

`build-runtime` applies `runtime.patch` to the upstream checkout before building.
The local patch supports a per-shell widget stylesheet, transparent menu
corners, a fallback icon theme, symbolic icon tinting, and empty missing icons;
it also caches missing menu images so moving
the pointer does not repeatedly load them. The shell opts in through the
`QS_WIDGET_STYLE_SHEET`, `QS_FALLBACK_ICON_THEME`, `QS_SYMBOLIC_ICON_COLOR`,
and `QS_HIDE_MISSING_ICONS`
pragmas. It does not change
the appearance of other Quickshell configurations unless they opt in. The
clock part of the patch updates Linux `SystemClock` scheduling in this local
runtime and adds an immediate `refresh()` method. The network part adds the
read-only `NetworkStatus` singleton and a metered/phone classification cache.
Reapply the patch when building a fresh upstream checkout; the helper detects
conflicts and stops. Normal package updates do not update this custom binary.
The vault task `Review local Quickshell source patches` records the audit and
stock-runtime alternatives, due 2026-11-20.

## Validation

Checked the live Hyprland layer: AGS occupies y=0..68 and this preview starts at
y=68 with a 44-pixel row. A temporary D-Bus tray application exercised primary
and secondary activation, both scroll axes, menu-only activation, passive and
attention states, literal tooltip text, keyboard activation, nested menu actions,
and menu layout updates while a submenu was open.
The styled menus were also checked with live checkbox and radio indicators,
a disabled action, nested submenu selection, and a layout update while open.
Deliberately missing menu icons and both missing-name and empty-pixmap tray
icons rendered without a checkerboard. The runtime patch was checked against
the pristine upstream revision.

Calendar navigation, Today, keyboard input, and outside-click dismissal were
checked in the running preview. A real midnight rollover updated the clock
and today's date. The live process has one realtime timerfd armed to the next
minute, with no repeating interval. Native clock checks cover delayed event
delivery, disable/re-enable, minute alignment, and simulated clock-change
cancellation. Native checks also cover both DST transitions, including the
repeated Berlin hour. An actual laptop suspend/resume has not been performed.

The battery and its one-line tooltip were inspected in the running panel against
the laptop's live UPower data. Battery state checks cover unknown/absent data,
the low/critical boundaries, charging pauses, estimates, and rate-sign handling.
An isolated mock UPower service checks native D-Bus changes and the rendered
widget's colors, markers, visibility, and fixed width without changing hardware
state. Physical charger transitions and battery behavior after actual suspend
have not been exercised.

The network icon and compact tooltip were inspected in the running bar against
live NetworkManager data. Presentation checks cover signal levels, unknown data,
disabled radios, failures, transitions, and checked versus unchecked connectivity.
An isolated private D-Bus checks live signal changes, metering/cache updates,
captive-portal warnings, NetworkManager disappearance/restart, and resume refresh
without changing the real connection. It also checks that idle state causes no
additional property reads. Actual network reconnects and laptop resume remain
unverified. The private-bus check requires Python with PyGObject and dbus-daemon.
The picker was opened and closed in the live panel, and its helper exited on
close. Mock checks cover access-point grouping and live ordering, compatible
saved profiles, profile validation, password retries, and asynchronous radio
commands without changing the current connection. A QML/stdio fixture checks
masked entry, password clearing, retry, and activation without a password for
saved profiles. Actual connection changes and radio toggles remain unverified.

The volume icon, compact tooltip, readable output names, slider, and popup close
button were inspected in the running bar. The real default output and every
output's volume/mute settings were unchanged after the checks. A separate private
PipeWire server with null sinks exercises actual native updates and slider
writes, channel balance through zero, mute preservation, amplification limits,
preferred/default output changes, stale interaction rejection, disappearing
outputs, and server restart/reconnection. It loads no hardware devices and does
not alter the host's audio. Hardware output switching, existing stream migration,
and laptop resume remain unverified. Actual mouse checks against private null
sinks cover speaker mute/unmute, −/+ steps, separate button hover, and right-click
opening the popup without changing audio. The native check sends mouse and wheel
events to an offscreen window, so it does not move the desktop pointer. It requires
PipeWire tools, the QtTest QML module, and the locally built Quickshell with PipeWire enabled.

Run the focused checks with:

```sh
node --test quickshell/tests/volume-logic.test.cjs
python3 quickshell/tests/check-volume
node --test quickshell/tests/battery-logic.test.cjs
node --test quickshell/tests/network-logic.test.cjs
./quickshell/tests/check-network
python3 quickshell/tests/network-picker.test.py
python3 quickshell/tests/check-network-picker-ui
TZ=Europe/Berlin node --test quickshell/tests/calendar-math.test.cjs
TZ=America/New_York node --test quickshell/tests/calendar-math.test.cjs
TZ=UTC node --test quickshell/tests/calendar-math.test.cjs
./quickshell/tests/check-clock
```

The local runtime suppresses Quickshell's checkerboard fallback when an
application supplies no usable icon. Tray entries retain their hit target and
tooltip; menu rows retain their text and action, with an empty icon area.

Qt 6's `qmllint` exits successfully. It reports upstream type-metadata warnings
for the dynamically registered `PanelWindow`, menu handle inheritance, and edge
flag combinations; these paths were checked in the running preview.

API reference: <https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.SystemTray/SystemTrayItem/>.
Timer behavior: <https://man7.org/linux/man-pages/man2/timerfd_create.2.html>.
