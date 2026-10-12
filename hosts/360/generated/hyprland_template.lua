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
    scale    = "1",
})


-- Bind workspaces 1-3 to eDP-1
for i = 1, 3 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1" })
end


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
        gaps_out    = 10,
        border_size = 2,

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

hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + C",         hl.dsp.window.close())
hl.bind(mainMod .. " + Return",    hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd('astal -i astal "toggle-recording"'))
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd("rofi -show run"))
hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd('rofi -show books -modes "books:rofi-books" -show-icons'))
hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd('rofi -show power-menu -modi "power-menu:rofi-power-menu --confirm=lockscreen "'))

-- clipboard picker
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace (silently) with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media / brightness keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -10%"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"),  { locked = true, transparent = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set +10%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl --device='*::kbd_backlight' set +25%"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl --device='*::kbd_backlight' set 25%-"), { locked = true, repeating = true })

-- Toolbox tmux window switcher
hl.bind(mainMod .. " + T", hl.dsp.workspace.toggle_special("toolbox"))
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
