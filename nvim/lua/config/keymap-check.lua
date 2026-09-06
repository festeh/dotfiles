local M = {}
local api = vim.api
local definitions, overwrites, reported = {}, {}, {}
local installed, pending = false, false
local modes = { "n", "x", "s", "o", "i", "c", "t" }
local config_dir = vim.fn.stdpath("config")
local init_file = vim.uv.fs_realpath(config_dir .. "/init.lua")
local module_file = debug.getinfo(1, "S").source:gsub("^@", "")
local roots = {
  config_dir,
  init_file and vim.fs.dirname(init_file) or config_dir,
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(module_file))),
}

local function is_config(filename)
  for _, root in ipairs(roots) do
    if filename:sub(1, #root + 1) == root .. "/" then return true end
  end
  return false
end

local function source_file(info)
  return info.source:sub(1, 1) == "@" and vim.fn.fnamemodify(info.source:sub(2), ":p") or ""
end

local function normalize(lhs)
  lhs = lhs:gsub("<[Ll][Ee][Aa][Dd][Ee][Rr]>", function()
    return vim.g.mapleader or "\\"
  end)
  lhs = lhs:gsub("<[Ll][Oo][Cc][Aa][Ll][Ll][Ee][Aa][Dd][Ee][Rr]>", function()
    return vim.g.maplocalleader or "\\"
  end)
  return api.nvim_replace_termcodes(lhs, true, true, true)
end

local function expand_modes(mode)
  local result = {}
  for _, value in ipairs(type(mode) == "table" and mode or { mode }) do
    vim.list_extend(
      result,
      ({ [""] = { "n", "x", "s", "o" }, v = { "x", "s" }, ["!"] = { "i", "c" } })[value]
        or { value }
    )
  end
  return result
end

local function scope(opts)
  local buf = opts and opts.buffer
  return (buf == true or buf == 0) and api.nvim_get_current_buf() or (buf or -1)
end

local function id(mode, buf, key)
  return mode .. ":" .. buf .. ":" .. key
end

local function is_nop(map)
  return not map.callback and (map.rhs == "" or (map.rhs or ""):lower() == "<nop>")
end

local function same_action(a, b)
  if a.callback or b.callback then return a.callback == b.callback end
  return a.rhs == b.rhs and a.expr == b.expr and a.remap == b.remap
end

local function record(mode, lhs, rhs, opts, site)
  local key, buf = normalize(lhs), scope(opts)
  for _, expanded in ipairs(expand_modes(mode)) do
    local map_id = id(expanded, buf, key)
    local current = {
      rhs = type(rhs) == "string" and rhs or nil,
      callback = type(rhs) == "function" and rhs or nil,
      desc = opts and opts.desc,
      expr = opts and opts.expr,
      remap = opts and opts.remap,
      site = site,
    }
    local previous = definitions[map_id]
    if
      previous
      and not is_nop(previous)
      and not is_nop(current)
      and not same_action(previous, current)
      and previous.site ~= current.site
    then
      overwrites[map_id] = { before = previous, after = current }
    end
    definitions[map_id] = current
  end
end

-- Lazy installs placeholder callbacks, so retain the original declarations for
-- conflict detection. Filetype-local keys are checked when their config runs.
function M.track_specs(plugins)
  if type(plugins) ~= "table" then return end
  for _, plugin in ipairs(plugins) do
    if type(plugin) == "table" and plugin.enabled ~= false and plugin.cond ~= false then
      for index, key in ipairs(type(plugin.keys) == "table" and plugin.keys or {}) do
        if type(key) == "table" and key[2] and not key.ft then
          local site = (plugin[1] or plugin.url or plugin.name or "plugin")
            .. " keys["
            .. index
            .. "]: "
            .. key[1]
          if type(key[2]) == "function" then
            local info = debug.getinfo(key[2], "S")
            site = info.source:gsub("^@", "") .. ":" .. info.linedefined
          end
          record(key.mode or "n", key[1], key[2], key, site)
        end
      end
      M.track_specs(plugin.dependencies or {})
    end
  end
  -- Allow native Lazy spec modules to return their tracked declarations.
  return plugins
end

local function location(map)
  if map.site then return map.site end
  if type(map.callback) == "function" then
    local info = debug.getinfo(map.callback, "S")
    return info.source:gsub("^@", "") .. ":" .. info.linedefined
  end
  return map.desc or map.rhs or "mapping"
end

local function label(map)
  return (map.desc and map.desc .. " — " or "") .. location(map)
end

-- Inspect the effective global + buffer-local mappings. Buffer-local overrides
-- are normal; only same-scope redefinitions are recorded as overwrites.
function M.collect(buf)
  buf = buf or api.nvim_get_current_buf()
  local conflicts = {}
  for _, mode in ipairs(modes) do
    local effective = {}
    for _, scope_buf in ipairs({ -1, buf }) do
      local maps = scope_buf == -1 and api.nvim_get_keymap(mode)
        or api.nvim_buf_get_keymap(scope_buf, mode)
      for _, map in ipairs(maps) do
        local key = normalize(map.lhs)
        local definition = definitions[id(mode, scope_buf, key)]
        map.key, map.scope = key, scope_buf
        map.owned = definition ~= nil
        map.site = definition and definition.site
        -- Lazy's temporary expression callback must not hide a prefix conflict
        -- in the original, non-expression key declaration.
        map.expression = definition and definition.expr == true or not definition and map.expr == 1
        effective[key] = map
        local overwrite = overwrites[id(mode, scope_buf, key)]
        if overwrite then
          conflicts[#conflicts + 1] = {
            kind = "overwrite",
            mode = mode,
            lhs = key,
            buffer = scope_buf,
            message = ("[%s] %s overwritten\n  before: %s\n  after:  %s"):format(
              mode,
              vim.fn.keytrans(key),
              label(overwrite.before),
              label(overwrite.after)
            ),
          }
        end
      end
    end

    local keys = vim.tbl_keys(effective)
    table.sort(keys)
    for index, key in ipairs(keys) do
      local shorter = effective[key]
      -- Expression/operator mappings often deliberately read the next key.
      -- <Nop> leader reservations and <Plug> implementation mappings are benign.
      if
        not is_nop(shorter)
        and not shorter.expression
        and not vim.fn.keytrans(key):find("<Plug>", 1, true)
      then
        for next_index = index + 1, #keys do
          local longer_key = keys[next_index]
          if longer_key:sub(1, #key) ~= key then break end
          local longer = effective[longer_key]
          if (shorter.owned or longer.owned) and not is_nop(longer) then
            conflicts[#conflicts + 1] = {
              kind = "prefix",
              mode = mode,
              lhs = key,
              other_lhs = longer_key,
              buffer = shorter.scope == -1 and longer.scope or shorter.scope,
              message = ("[%s] %s prefixes %s%s\n  shorter: %s\n  longer:  %s"):format(
                mode,
                vim.fn.keytrans(key),
                vim.fn.keytrans(longer_key),
                shorter.nowait == 1 and " (nowait can shadow the longer mapping)"
                  or " (waits for timeoutlen)",
                label(shorter),
                label(longer)
              ),
            }
          end
        end
      end
    end
  end
  table.sort(conflicts, function(a, b)
    return a.message < b.message
  end)
  return conflicts
end

local function report_new()
  local new = {}
  for _, conflict in ipairs(M.collect()) do
    if not reported[conflict.message] then
      reported[conflict.message] = true
      new[#new + 1] = conflict
    end
  end
  if #new > 0 then
    vim.notify(
      ("%d mapping conflict(s) detected. Run :KeymapCheck for details."):format(#new),
      vim.log.levels.WARN,
      { title = "Keymaps" }
    )
  end
end

local function schedule_check()
  if pending or vim.v.vim_did_enter == 0 then return end
  pending = true
  vim.defer_fn(function()
    pending = false
    if vim.v.exiting == vim.NIL then report_new() end
  end, 100)
end

function M.show()
  local conflicts = M.collect()
  if #conflicts == 0 then
    vim.notify("No mapping conflicts detected.", vim.log.levels.INFO, { title = "Keymaps" })
    return
  end
  local lines = {
    "Mapping conflicts",
    "",
    "Overwrites: Lua mappings defined by this config in the same mode and scope.",
    "Prefixes: effective mappings involving this config; expression maps are excluded.",
    "",
  }
  for _, conflict in ipairs(conflicts) do
    vim.list_extend(lines, vim.split(conflict.message, "\n", { plain = true }))
    lines[#lines + 1] = ""
  end
  vim.cmd("botright new")
  vim.bo.buftype, vim.bo.bufhidden, vim.bo.swapfile, vim.bo.buflisted =
    "nofile", "wipe", false, false
  api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.modifiable = false
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, silent = true })
end

function M.setup()
  if installed then return end
  installed = true
  local set, del = vim.keymap.set, vim.keymap.del
  vim.keymap.set = function(mode, lhs, rhs, opts)
    local caller = debug.getinfo(2, "Sl")
    set(mode, lhs, rhs, opts)
    local filename = source_file(caller)
    -- Plugin internals routinely replace their own mappings (e.g. Lazy and
    -- completion fallbacks). Track config definitions without flagging those.
    if not is_config(filename) then return end
    local parent = debug.getinfo(3, "Sl")
    local line = parent and parent.source == caller.source and parent.currentline
      or caller.currentline
    record(mode, lhs, rhs, opts, filename .. ":" .. line)
    schedule_check()
  end
  vim.keymap.del = function(mode, lhs, opts)
    local caller = debug.getinfo(2, "S")
    del(mode, lhs, opts)
    if not is_config(source_file(caller)) then return end
    for _, expanded in ipairs(expand_modes(mode)) do
      local map_id = id(expanded, scope(opts), normalize(lhs))
      definitions[map_id], overwrites[map_id] = nil, nil
    end
  end

  local group = api.nvim_create_augroup("ConfigKeymapCheck", { clear = true })
  api.nvim_create_autocmd(
    { "VimEnter", "BufEnter", "LspAttach" },
    { group = group, callback = schedule_check }
  )
  api.nvim_create_autocmd(
    "User",
    { group = group, pattern = "VeryLazy", callback = schedule_check }
  )
  api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(event)
      for map_id in pairs(definitions) do
        if map_id:match("^[^:]+:(%d+):") == tostring(event.buf) then
          definitions[map_id], overwrites[map_id] = nil, nil
        end
      end
    end,
  })
  api.nvim_create_user_command(
    "KeymapCheck",
    M.show,
    { desc = "Show conflicting mappings in the current buffer" }
  )
end

return M
