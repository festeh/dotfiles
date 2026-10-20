# Quickshell bar experiment

Launcher, workspaces, keyboard layout, volume, network, battery, clock, calendar, and tray built independently of AGS. `Theme.qml` borrows its Catppuccin colors,
rounded container, and right alignment from `ags/style.css`.

Run `./quickshell/run` from the dotfiles checkout, or
`quickshell --path ~/dotfiles/quickshell`. Quickshell reloads QML edits live;
restart the preview after editing imported JavaScript logic.
Install the `papirus-icon-theme` package, or install Papirus and Papirus-Dark
under `~/.local/share/icons` for the current user. Theme changes require a
preview restart so Qt rebuilds its icon lookup.
Stop with `quickshell --path ~/dotfiles/quickshell kill`.
Hyprland starts the shared shell through UWSM at graphical login using
`shell-launcher --start`. This keeps the preview bar and app catalog warm without
opening the launcher or taking focus. Category hotkeys can also recover the shell
if it is not running.

Each monitor gets a transparent row below panels that already reserve space
(currently AGS). The compositor handles placement without polling or a fixed
AGS height. Only the workspace strip and the layout, volume, network, battery,
clock, and tray widgets receive pointer input. The row reserves 44 pixels;
the clock remains visible when there are no tray items. All tray items remain visible, including
passive items, so applications do not silently disappear.

## Launcher

The launcher replaces the Rofi bindings in the Hyprland template and its generated
host config. `~/.local/bin/shell-launcher` links to `quickshell/launcher`; it starts
the shared shell when necessary, then sends a typed IPC request. The centered
overlay follows the focused monitor, takes keyboard focus, and dismisses on an
outside click. Opening the same category toggles it; another category hotkey
switches it. The sidebar is alphabetical.
The `quickshell-launcher` layer has its animations disabled, so the popup appears
immediately instead of inheriting the desktop's long layer/fade transitions.

| Category | Hotkey |
| --- | --- |
| Apps | Super+D |
| Books | Super+B |
| Clipboard | Super+V |
| Power | Super+Shift+M |
| Shortcuts | Super+/ |
| Widgets | Super+Shift+D |

Super+S opens the existing screenshot capture tool; its saved notification expires after five seconds.

Ctrl+J/K and Up/Down select results or widget controls. Ctrl+H/L switches
categories without losing search text. Reopening starts a fresh search in the
requested category, defaulting to Apps. Enter activates; Escape always closes,
including from cards and buttons. Escape/Enter tips are deliberately omitted.
There are no Normal/Insert modes, global All view, or Commands category; the old
Super+R command binding is retired. Clipboard uses Enter to copy and close, or
Shift+Enter to copy and paste into the original window. The launcher hides before
dispatching actions. Paste uses Hyprland's addressed `send_shortcut` and checks
that the original window regained focus; it never types into an unrelated window.

Apps use GIO's desktop catalog, visibility rules, change monitor and launch API,
preserving desktop field codes, working directories, terminal apps and D-Bus
activation. Search runs in QML over normalized cached metadata, with match
quality ahead of local usage when ranking. There is no subprocess per keystroke.
The backend has no arbitrary shell-command execution interface.

Books show compact cover rows, title, author, shelf and format. A background
initial scan indexes the library; subsequent file events rescan the changed
directory, recursing only into new subtrees. Opening again reuses the index.
F5/Refresh forces a rescan. Missing mounts produce an explanatory state.
Visible covers render one at a time in low-priority, time-limited processes and
update without moving keyboard selection. FB2 covers come from their embedded
cover image; blank thumbnails use the reader icon instead. PDF/DjVu use Zathura,
other supported formats Foliate, with `xdg-open` when the preferred reader is
absent. Existing book recency is imported locally; Reading Desktop remains a
separate app/hotkey.
`QS_BOOK_LIBRARY` optionally overrides the default library root before startup.

Clipboard retains `cliphist` storage and the existing text/image capture watchers.
Text entries use a T icon and images a picture icon, without redundant type labels.
It reads on opening, then follows database changes only while visible. Search
covers cliphist's previews (currently truncated to 100 characters), not full
stored text. Selected contents remain binary bytes through decode/copy, so images
are preserved. Shortcuts are discovered from described live Hyprland bindings,
and their actions run after focus returns. Power actions execute immediately;
unavailable system capabilities are disabled. Lock is unavailable until a screen
locker is configured, rather than issuing a lock request that does nothing.

Widgets is a card dashboard without a search field: four firmware power-profile
choices and a separate Sleep behavior card. Calendar and Audio stay in the bar.
Sleep behavior offers explicit **Sleep after 25 min** and **Stay awake** choices,
with a mauve border and label marking the selected choice. Supporting copy explains
the current mode; a separate amber message reports other apps preventing sleep
without changing that selection. There is no explanatory footer.
Leaf, moon, scales and lightning icons identify Low power, Quiet, Balanced and
Performance; the active profile keeps its mauve border and label.
Profile state follows sysfs priority notifications and is refreshed on opening
and resume. Changes use the existing installed Polkit helper and are read back
before success; Quiet is preserved without installing power-profiles-daemon.
No profile polling timer or new native Quickshell patch is used.

The Stay awake choice owns an idle-only logind inhibitor through the optional
`quickshell-keep-awake.service` user unit. The host configuration installs its
symlink; run `systemctl --user daemon-reload` after installation. It is not enabled
for automatic startup. The lease survives closing/reloading the shell and normal
suspend/resume, but stops with `graphical-session.target` at logout. The existing
25-minute swayidle suspend timer stays running. Releasing the final idle inhibitor
starts a fresh 25-minute interval on the installed swayidle/Hyprland versions.
Manual suspend and lid behavior remain available. The card reads acquired
inhibitors instead of maintaining an optimistic Boolean; other apps' inhibition
is also reported.

History is private local data under `$XDG_STATE_HOME/quickshell/launcher.json`
(default `~/.local/state`); covers live under `$XDG_CACHE_HOME/quickshell/launcher`
(default `~/.cache`). Filenames and clipboard values are never logged or written
into repository files. Runtime IPC `launcher.status` exposes counts/state, not
queries or result contents. Example:

```sh
quickshell ipc --path ~/dotfiles/quickshell call launcher open widgets
quickshell ipc --path ~/dotfiles/quickshell call launcher close
node --test quickshell/tests/launcher-logic.test.cjs
python3 quickshell/tests/launcher-backend.test.py
python3 quickshell/tests/check-launcher-ui
```

The UI check uses an offscreen window with the production content/controller and
a mock transport. It never sends keys to desktop applications or executes power
actions. Backend checks include a harmless fixture desktop launch to verify field
codes and working directory, binary copy, safe addressed paste, incremental
indexing, unavailable actions and failed profile authorization.

## Work Gmail and Calendar

Two compact widgets live in the main status row. Gmail shows an envelope and an
unread-inbox count only when nonzero. Left click opens sender/subject/snippet
previews with a separate **Mark as read** action; right click opens work Gmail.
Clicking a message opens its thread in Gmail. Reading a preview does not mark it
read. The read action removes only `UNREAD` after Google confirms success and
keeps the popup open. Failures preserve the count and allow retry.

The AGS implementations and styles are retained. `ags/features.ts` sets
`legacyStatusWidgetsEnabled` and `legacyGoogleWidgetsEnabled` to `false`, disabling
the old right-hand bar controls and Google extra row. The Google polling helper
and clock timer also stay inactive behind these flags. AGS workspaces and agent
status remain active. The recording implementation is retained, with its Super+E
shortcut disabled.

Calendar shows a meeting icon and the current/next meeting's start time only for
today. `outOfOffice` uses a palm, including all-day absences. Left click opens the
upcoming agenda; each row opens its Google Calendar link. Right click opens work
Calendar. Both popups close with Escape or an outside click. Event titles and
message text are plain text; mail HTML, remote images and attachments are not loaded.

`GoogleWorkState` owns one persistent Python process across monitors. Gmail
bootstraps an exact paginated unread-inbox ID list, then checks mailbox history
every 60 seconds. Only changed IDs are reconciled. Preview pages are fetched on
opening and cached; private custom Gmail queries tag messages on demand. An
expired history cursor causes a full unread-index refresh. Calendar fetches a
paginated eight-day agenda every three minutes. Meeting boundaries and midnight
update locally using the shared clock and one boundary timer. Resume and network
reconnection trigger a coalesced refresh; failed requests use bounded backoff.
Gmail and Calendar have separate error states, preserving cached data as stale.

Install the small Google authentication environment using the system interpreter
so it also sees the installed PyGObject D-Bus bindings:

```sh
uv venv --python /usr/bin/python3 --system-site-packages \
  ~/.local/share/quickshell/google-work-venv
uv pip install --python ~/.local/share/quickshell/google-work-venv/bin/python \
  'google-auth-oauthlib>=1.2,<2'
```

The `google-work` wrapper can use another interpreter via `QS_GOOGLE_PYTHON`.
OAuth desktop credentials live in
`~/.config/quickshell/google-work/credentials.json`; account and optional bucket
settings use `config.json` beside it (see `google-work.example.json`). Tokens live
in `~/.local/state/quickshell/google-work/token.json`, with private cached state
under `~/.cache/quickshell/google-work`. All writes use mode 0600 and atomic
replacement. Standard XDG roots and `QS_GOOGLE_CONFIG`, `QS_GOOGLE_STATE`,
`QS_GOOGLE_CACHE` overrides are supported. Never commit account data or tokens.

`./quickshell/google-work --migrate-ags` imports existing local credentials,
authorization and custom queries once without overwriting a new configuration.
The Google project/client is retained under Desktop Work Hub branding. The work
mailbox is pinned after validation, and web links select that account instead of
relying on browser account index 1. Enabling **Mark as read** requests
`gmail.modify`; Calendar retains `calendar.events.readonly`. Existing read-only
tokens continue to show mail and meetings while the popup offers authorization.
Only an explicit Connect/Enable action opens the browser consent flow, using
PKCE and a loopback callback. A sign-in to a different mailbox is rejected.
Google apps in external Testing status normally need renewed consent after seven
days; renaming the app does not change that Google setting.

Counts-only diagnostics and checks:

```sh
quickshell ipc --path ~/dotfiles/quickshell call work status
python3 quickshell/tests/google-work.test.py
node --test quickshell/tests/google-work-logic.test.cjs
python3 quickshell/tests/check-google-work-ui
```

The UI check uses fake mail/meetings in an offscreen window. It verifies both
mouse buttons, event links, individual read actions, failed writes, zero counts,
out-of-office icons and Escape without modifying actual mail.

## Tray

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

## Keyboard layout

A compact mauve `RU` lettermark appears immediately left of the volume while the main
physical keyboard uses Russian. It hides for other layouts and unavailable data.
The letter shapes are SVG paths, selected as option 04 in the icon comparison;
they render without relying on installed fonts.
Click, press Enter/Space, or use the accessibility action to cycle the identified
keyboard's configured layouts. Hover or focus for its current layout name.

`LayoutState.qml` is shared across outputs. One transient `hyprctl -j devices`
request finds the main keyboard at startup; `activelayout` events from the
existing native Hyprland connection update its name directly. Config reloads and
events from another physical keyboard trigger a coalesced device refresh so the
widget can follow a newly selected main keyboard. Virtual keyboards are ignored.
The device name is discovered rather than hardcoded, and switching uses separate
process arguments. A follow-up snapshot confirms the result of an explicit click.
Newer events take precedence over an older snapshot already in flight.
There is no periodic polling, persistent helper process, or new core patch.
Requests have a two-second timeout and at most two retries after a failed read;
later relevant events can retry after recovery. The native event connection's
restart limitation described below also applies to layout events.

Check discovery, event updates, activation, races, and idle behavior without
changing the user's keyboard:

```sh
node --test quickshell/tests/layout-logic.test.cjs
python3 quickshell/tests/check-layout
```

Compare 16 flags, lettermarks, and icon-set alternatives in the standalone
[`previews/layout-icons.html`](previews/layout-icons.html) page. It previews the
same bar slot, symbol colors, icon heights, and hiding the indicator on English.

References: [Hyprland layout events](https://wiki.hypr.land/IPC/) and
[hyprctl commands](https://wiki.hypr.land/Configuring/Using-hyprctl/).

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
fills from the bottom to the actual charge level while on battery or charging.
Charging uses green without an overlay. When plugged in without charging, the
icon shows a full green battery; the tooltip retains the actual charge level.
The bar shows only the icon in a fixed-width pill; the exact percentage is
available on hover.
While discharging on battery power, the icon stays text gray above 20%, turns
yellow at 11–20%, peach at 6–10%, and red at 0–5%. Charging overrides the
percentage color with green; paused charging on battery stays neutral. The low (20%) and
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
hardware refreshes, including after resume. The Quickshell notification service
and system power policy operate independently of battery monitoring.

## Notifications

Quickshell owns `org.freedesktop.Notifications`. AGS's original notification
implementation is retained behind `legacyNotificationsEnabled = false` in
`ags/features.ts`; disabling that call also prevents AstalNotifd from acquiring
the notification service. AGS's remaining widgets stay active.

One native `NotificationServer` serves all monitors. Compact cards appear at the
top right, below reserved bar space, on the monitor focused when they arrive.
Monitor removal moves live cards to an available output. Popups do not take
keyboard focus, and their rounded input regions leave gaps clickable through.

Explicit sender timeouts are respected, in milliseconds. Zero means no automatic
expiration. When no timeout is supplied (`-1`), low and normal notifications
default to 30 seconds; critical notifications stay until dismissed. An explicit
positive timeout also applies to a critical notification.
Hover does not extend a deadline; leaving a hovered noncritical card dismisses
it immediately. A thin mauve outline traces the rounded border clockwise from
the top center, completing one lap at the notification's deadline. It resets on replacement and resumes at
the correct position after reload or suspend; only visible cards animate.
Clock reconciliation never rewinds the outline, and a completed lap stays full
until expiration instead of restarting for a final frame.
Notifications without a deadline have no timeout indicator. Critical notifications
do not dismiss on hover leave. Sender withdrawal and action
semantics, including resident actions, are handled by the native service.
Timeout sends the expired close reason; the close button and hover leave send
the user-dismissed reason.

At most three cards are visible, with fewer on short screens. Critical alerts
have priority, while the stack under the pointer stays in place on arrival.
Hyprland animations are disabled for the notification layer: animating its height
when a card disappears stretches the colored border into a temporary rectangle.
The timeout outline still animates within each card.
Queued ordinary notifications keep their original deadline. Ordinary bursts are
bounded to 64 active notifications; excess entries expire instead of growing a
backlog. There is no notification center, saved history, DND, or server sound.

Bodies and summaries are literal plain text. App icons and action icons use the
current theme with a bundled bell fallback. Local images and native `image-data`
have bounded display sizes; remote image URLs are not fetched. Cards support
default actions, separate action buttons, and numeric progress hints.

One single-shot timer handles expiration; a `gdbus monitor` process subscribes to
logind resume events without polling. Resume reconciles wall-clock deadlines
immediately, and visible relative timestamps reuse the existing shared clock.
QML reloads retain only lifetime/monitor metadata through `PersistentProperties`;
they preserve the original deadlines and live native actions without disk writes.

`notifications.patch` adds a native replacement event, including replacements
whose content is identical. This is needed to restart the deadline reliably;
upstream only emits the arrival signal for new IDs, and property-change signals
cannot detect identical replacements. The patch is separate from `runtime.patch`
and applied by `build-runtime`. It adds no notification policy to C++.

Validation uses a private D-Bus session, real notification method calls/signals,
and the production cards with Qt mouse events:

```sh
node --test quickshell/tests/notification-logic.test.cjs
quickshell/tests/check-notifications
# Optional full 30-second animation/expiration regression:
quickshell/tests/check-notifications --deadline
```

Privacy-preserving live status: `quickshell ipc --path ~/dotfiles/quickshell call notifications status`.

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
Icons use Papirus-Dark, with Adwaita as a fallback for missing GTK symbolic names.
The theme can be installed per user under `~/.local/share/icons`.
Symbolic icons are tinted to the menu text color so dark source
artwork remains readable against the dark menu background.

## Hyprland workspaces and window icons

The left strip groups every normal workspace with an icon for each of its
windows, including separate icons for multiple windows of the same app. Empty
workspaces retain their numbered button. Numbered workspaces sort numerically;
named workspaces have a stable name order. Special workspaces are identified by
their names and omitted, without hiding normal named workspaces with negative IDs.
The number sits close to its window icons. Spacing stays the same when focus
changes, and workspace backgrounds stay neutral. A workspace visible on another
monitor has a subtle border. The focused window has a mauve underline.

Click a workspace number to activate it, or an app icon to focus that exact
window. Tab moves between buttons; Enter/Space activates the focused button.
Each button has an independent hover/focus highlight and a compact one-line
tooltip. Window tooltips show the app name and title to distinguish duplicates.
Unknown applications and unavailable artwork use a neutral window symbol and
remain clickable. The strip scrolls horizontally when space runs out, and
keyboard focus reveals clipped buttons. The status row keeps its space on the
right; the unused center remains click-through through a union of input regions.

`WorkspaceState.qml` shares the stock native Hyprland models and desktop-entry
catalog across monitor views. `ScriptModel` preserves delegates by native object
identity, and windows keep a stable address order when focus changes. Membership
uses workspace IDs from the initial IPC snapshot and move events. The native
workspace pointer resolves by name, which can group windows incorrectly when
AGS assigns the same name to several numbered workspaces. Workspace selection
also uses IDs from monitor snapshots and workspace events. Wayland app IDs,
exact desktop IDs, and unambiguous
`StartupWMClass` matches resolve app icons. Desktop catalog notifications clear
our icon cache, including when previously missing applications are installed.
When a single registered tray item matches an app ID, desktop-entry ID, or
startup class, its live icon source takes priority. This includes app-provided
pixmaps and icon updates, without app-specific assets or overrides. Missing or
ambiguous tray matches fall back to the desktop icon.
Desktop artwork prefers the configured icon theme using its explicit icon name,
desktop-entry ID, and app IDs before falling back to a bundled image path. This
also covers launchers with absolute `Icon=` paths, such as Zed, without an
app-specific rule. Icon identifiers retain their case.
Explicit user overrides in `WorkspaceState.qml` take precedence: `codex` and
`book-codex-*` app IDs use the bundled Codex SVG artwork also used by AGS.
Kitty uses WhiteSur's terminal artwork, including the terminal fallback. Foliate
uses Phosphor's open-book duotone icon in mauve, selected from
[`previews/foliate-icons.html`](previews/foliate-icons.html). Bundled artwork retains
its upstream license and attribution in `assets/whitesur/` and `assets/phosphor/`.
For Kitty windows, the foreground app in the active tab/pane supplies the icon.
Installed desktop IDs, startup classes, and unambiguous `Exec` executable names
resolve the artwork first. Codex and Claude use bundled overrides when their
foreground executables have no usable app icon. Other unknown apps and shell
prompts fall back to Kitty; failed image loads also retain that fallback.

`KittyApps.qml` owns one shared Python reader. It talks directly to the configured
abstract Kitty sockets, without spawning `kitty @` commands. Focus/title changes
request a refresh, coalesced to at most four queries per second per Kitty process.
Leading activity spinners and their presentation/spacing changes are removed
before comparing titles. Spinner-only updates never request a reader refresh;
meaningful title changes and focus events still do. Initial titles are seeded
from the native model, and cached keys are removed when windows close.
A one-second check reads `/proc` stat fields for known Kitty pane/foreground PIDs
so foreground-group changes and exits also update icons with fixed titles. There
are no periodic process-tree scans or idle Kitty IPC queries. With no Kitty
windows the reader blocks on input. Only app executable basenames reach QML;
command arguments, environment, working directories and session metadata stay
out of the icon state. Multiple OS windows in one Kitty process are matched only
when their classes identify them uniquely; ambiguous windows use the Kitty icon.
Kitty tab/pane switches refresh through meaningful compositor title/focus events.
A switch that leaves both the normalized title and the previously observed
foreground processes unchanged is detected on the next meaningful title/focus event.

The open-window event supplies class metadata before the first full IPC snapshot.
Since that event contains only a workspace name, a single-shot 40 ms timer
coalesces open bursts into one client snapshot to obtain workspace IDs. Initial
load and monitor/configuration changes also refresh metadata once.
Hyprland membership uses no repeating timers, `hyprctl` polling, per-window
processes, or new Quickshell core patches. AGS supplies visual references and
Codex/Claude artwork only. Agent status, agent pills, session tracking, and
workspace renaming are out of scope.

Workspace activation uses the native Hyprland dispatcher with numeric IDs for
numbered workspaces and explicit names for named workspaces, with Lua-mode
support. Window activation uses an exact, validated address.
The Wayland activation method silently returns if Qt has no last input device;
the dispatcher also works before pointer input and for windows on other workspaces.
An empty focus event explicitly clears our window highlight rather than relying
on the native active-toplevel pointer retaining the previous window.

The inspected native event connection does not reconnect automatically after a
socket disconnect. Its last state can remain visible; QML reload alone does not
recreate the native connection. Stop the preview with
`quickshell --path ~/dotfiles/quickshell kill`, then start `./quickshell/run`
after it exits. Restart recovery is checked with private sockets. Automatic
reconnection remains a separate stock-runtime/upstream review.

The initial read-only probe verified Lua mode, workspace membership, and Wayland
mapping against the installed Hyprland 0.56.2. Private request/event sockets and
an offscreen widget check duplicate windows, missing/changing app metadata and
artwork, focus clearing, exact-window mouse and keyboard activation, delegate
reuse, open/close/move/title events, named/special workspaces, workspace
creation/removal/rename, identical workspace names at startup and after moves,
ID-based workspace selection, terminal executable matching and icon fallbacks,
monitor changes, overflow, idle IPC traffic, and
restart recovery. Two disposable application windows verified real exact-window and
cross-workspace activation; the original desktop state was restored afterward.
Physical multi-monitor hotplug and laptop suspend/resume remain unverified.

Run the workspace checks with:

```sh
node --test quickshell/tests/workspace-logic.test.cjs
python3 quickshell/tests/kitty-apps.test.py
python3 quickshell/tests/check-workspaces
```

References: [native Hyprland service](https://quickshell.org/docs/v0.3.2/types/Quickshell.Hyprland/Hyprland/),
[stable script models](https://quickshell.org/docs/v0.3.2/types/Quickshell/ScriptModel/),
and [Hyprland dispatchers](https://wiki.hypr.land/Configuring/Basics/Dispatchers/).

## Local runtime

Upstream source: `~/github/quickshell`, fetched from
<https://github.com/quickshell-mirror/quickshell>.
The local runtime is built against the host Qt version and installed under
`~/.local`. Rebuild Quickshell after Qt upgrades: it uses private Qt APIs.

The current build enables PipeWire, notifications, networking, UPower, the tray, Wayland panels, Hyprland integration, and
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
  -DSERVICE_NOTIFICATIONS=ON -DBLUETOOTH=OFF -DNETWORK=ON -DX11=OFF \
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
