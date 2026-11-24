-- Keep the two reading workspaces adjacent while the desktop is active.
local dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/book-desktop"
local config = os.getenv("HOME") .. "/.config/book-desktop/books.toml"
local command = os.getenv("HOME") .. "/.local/bin/book-desktop"

-- Read the configurable toggle even while the desktop is stopped.
local toggle = "SUPER + SHIFT + B"
local file = io.open(config, "r")
if file then
    for line in file:lines() do
        local key = line:match('^toggle_key%s*=%s*"([^"]+)"')
        if key then toggle = key; break end
    end
    file:close()
end
shortcut(toggle, "Toggle reading desktop", hl.dsp.exec_cmd(command .. " toggle"))

file = io.open(dir .. "/enabled.lua", "r")
if not file then return end
file:close()
local setup = dofile(dir .. "/enabled.lua")
if setup.instance ~= os.getenv("HYPRLAND_INSTANCE_SIGNATURE") then return end
for _, id in ipairs({ setup.codex_workspace, setup.books_workspace }) do
    hl.workspace_rule({ workspace = tostring(id), layout = "monocle", persistent = true })
end
