-- Hyprland Lua config. Go template rendered by ~/Installer into
-- hosts/<host>/generated/hyprland_template.lua and symlinked to ~/.config/hypr/hyprland.lua.
-- Edit this file, then run `cd ~/Installer && ./installer -c config`.
-- Docs: https://wiki.hypr.land/configuring/
-- NOTE: Go templates treat two consecutive opening braces as an action; keep a space between nested table braces.

-- Timestamped logs for diagnosing compositor/AGS IPC failures.
hl.config({
    debug = {
        disable_logs = false,
        disable_time = false,
        enable_stdout_logs = true,
    },
})

------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "{{ or .SCALING 2 }}",
})

{{if .BIND_WORKSPACES_TO_EDP1}}
-- Bind workspaces 1-3 to eDP-1
for i = 1, 3 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1" })
end
{{end}}

-- Headless outputs for screen sharing (Sunshine, etc.)
for i = 1, 10 do
    hl.monitor({
        output   = "HEADLESS-" .. i,
        mode     = "1920x1080@60",
        position = "auto",
        scale    = "1",
    })
end

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/hypr/scripts/monitor.sh")
    hl.exec_cmd("uwsm app -- ~/.config/hypr/scripts/sleep.sh")

    -- clipboard history (text and images)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us,ru",
        kb_options = "grp:alt_shift_toggle,compose:rctrl",

        follow_mouse = 1,

        touchpad = {
            natural_scroll = false,
        },

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
    },
    gestures = {
        workspace_swipe_invert = false,
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = {{ or .GAPS_OUT 10 }},
        border_size = {{ or .BORDER_SIZE 2 }},

        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        layout = "dwindle",
    },

    decoration = {
        rounding = 10,

        blur = {
            enabled = true,
            size    = 3,
            passes  = 1,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows",     enabled = true, speed = 7,  bezier = "myBezier" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 7,  bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "fade",        enabled = true, speed = 7,  bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "default" })

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Described binds appear in the shortcut launcher (mainMod + /), which runs
-- the selected one through `hyprctl eval 'hl.dispatch(shortcuts[...])'`.
shortcuts = {}
function shortcut(keys, description, action, opts)
    opts = opts or {}
    opts.description = description
    shortcuts[description] = action
    return hl.bind(keys, action, opts)
end

shortcut(mainMod .. " + slash",     "Show shortcuts",          hl.dsp.exec_cmd('rofi -show shortcuts -modes "shortcuts:rofi-shortcuts"'))
shortcut(mainMod .. " + SHIFT + Q", "Close window",            hl.dsp.window.close())
shortcut(mainMod .. " + C",         "Close window",            hl.dsp.window.close())
shortcut(mainMod .. " + Return",    "Open terminal",           hl.dsp.exec_cmd("kitty"))
shortcut(mainMod .. " + E",         "Start voice recording",   hl.dsp.exec_cmd('astal -i astal "toggle-recording"'))
shortcut(mainMod .. " + D",         "Launch app",              hl.dsp.exec_cmd("rofi -show drun"))
shortcut(mainMod .. " + R",         "Run command",             hl.dsp.exec_cmd("rofi -show run"))
shortcut(mainMod .. " + B",         "Open book",               hl.dsp.exec_cmd('rofi -show books -modes "books:rofi-books" -show-icons'))
shortcut(mainMod .. " + P",         "Pseudotile window",       hl.dsp.window.pseudo())
shortcut(mainMod .. " + J",         "Toggle split direction",  hl.dsp.layout("togglesplit"))
shortcut(mainMod .. " + F",         "Toggle fullscreen",       hl.dsp.window.fullscreen())
shortcut(mainMod .. " + SHIFT + M", "Power menu",              hl.dsp.exec_cmd('rofi -show power-menu -modi "power-menu:rofi-power-menu --confirm=lockscreen "'))

-- clipboard picker
shortcut(mainMod .. " + V", "Clipboard history", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))

-- Navigate existing workspaces horizontally; move window focus vertically.
shortcut(mainMod .. " + left",  "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
shortcut(mainMod .. " + right", "Next workspace",     hl.dsp.focus({ workspace = "e+1" }))
shortcut(mainMod .. " + up",    "Focus window above", hl.dsp.focus({ direction = "up" }))
shortcut(mainMod .. " + down",  "Focus window below", hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace (silently) with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    shortcut(mainMod .. " + " .. key,         "Go to workspace " .. i,         hl.dsp.focus({ workspace = i }))
    shortcut(mainMod .. " + SHIFT + " .. key, "Move window to workspace " .. i, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media / brightness keys
shortcut("XF86AudioRaiseVolume", "Volume up",       hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+"), { locked = true, repeating = true })
shortcut("XF86AudioLowerVolume", "Volume down",     hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -10%"), { locked = true, repeating = true })
shortcut("XF86AudioMute",        "Mute audio",      hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"),  { locked = true, transparent = true })
shortcut("XF86AudioMicMute",     "Mute microphone", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

shortcut("XF86MonBrightnessUp",   "Screen brightness up",     hl.dsp.exec_cmd("brightnessctl set +10%"), { locked = true, repeating = true })
shortcut("XF86MonBrightnessDown", "Screen brightness down",   hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })
shortcut("XF86KbdBrightnessUp",   "Keyboard backlight up",    hl.dsp.exec_cmd("brightnessctl --device='*::kbd_backlight' set +25%"), { locked = true, repeating = true })
shortcut("XF86KbdBrightnessDown", "Keyboard backlight down",  hl.dsp.exec_cmd("brightnessctl --device='*::kbd_backlight' set 25%-"), { locked = true, repeating = true })

-- Toolbox tmux window switcher
shortcut(mainMod .. " + T", "Toggle toolbox", hl.dsp.workspace.toggle_special("toolbox"))
hl.window_rule({
    name      = "toolbox",
    match     = { class = "^(com.example.toolbox)$" },
    float     = true,
    center    = true,
    workspace = "special:toolbox silent",
})

-- Keep temporary XWayland drag windows from taking focus.
hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

-- Optional reading desktop: book-desktop up/down, or Super+Shift+B.
local books_config = os.getenv("HOME") .. "/.config/book-desktop/hyprland.lua"
local books_file = io.open(books_config, "r")
if books_file then
    books_file:close()
    dofile(books_config)
end
