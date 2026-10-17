-- Loaded from the main config. Runtime window identities come from book-desktop up.
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
hl.bind(toggle, hl.dsp.exec_cmd(command .. " toggle"))

file = io.open(dir .. "/enabled.lua", "r")
if not file then return end
file:close()
local setup = dofile(dir .. "/enabled.lua")
if setup.instance ~= os.getenv("HYPRLAND_INSTANCE_SIGNATURE") then return end
local active = setup.windows[1] and setup.windows[1].id
file = io.open(dir .. "/active", "r")
if file then active = file:read("*l") or active; file:close() end

for _, id in ipairs({ setup.codex_workspace, setup.books_workspace }) do
    hl.workspace_rule({ workspace = tostring(id), layout = "monocle", persistent = true })
end

hl.on("window.active", function(window)
    if not window then return end
    for _, book in ipairs(setup.windows) do
        if window.address == book.reader and window.workspace.id == setup.books_workspace and active ~= book.id then
            active = book.id
            local out = io.open(dir .. "/active.tmp", "w")
            if out then
                out:write(active, "\n")
                out:close()
                os.rename(dir .. "/active.tmp", dir .. "/active")
            end
            hl.exec_cmd(command .. " sync")
            break
        end
    end
end)

-- This also handles swipes and bar clicks, without sending a Codex prompt.
hl.on("workspace.active", function(workspace)
    if workspace.id == setup.codex_workspace then hl.exec_cmd(command .. " sync") end
end)

for _, direction in ipairs({ "up", "down" }) do
    local key = "SUPER + " .. direction
    hl.unbind(key)
    hl.bind(key, function()
        local workspace = hl.get_active_workspace()
        local id = workspace and workspace.id
        if id == setup.books_workspace or id == setup.codex_workspace then
            hl.dispatch(hl.dsp.layout(direction == "up" and "cycleprev" or "cyclenext"))
        else
            hl.dispatch(hl.dsp.focus({ direction = direction }))
        end
    end)
end
