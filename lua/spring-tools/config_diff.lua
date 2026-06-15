local config_mod = require("spring-tools.config_explorer")
local config = require("spring-tools.config")
local project = require("spring-tools.project")
local utils = require("spring-tools.utils")

local M = {}

function M.open()
  local proj = project.get_active_project()
  local root = proj and proj.root or vim.fn.getcwd()
  local files = config_mod.find_config_files(root)

  if #files < 2 then
    utils.notify("Need at least 2 config files to diff (found " .. #files .. ")", vim.log.levels.WARN)
    return
  end

  local display_names = vim.tbl_map(function(f)
    return vim.fn.fnamemodify(f, ":t")
  end, files)

  vim.ui.select(display_names, {
    prompt = "Select first file (left):",
  }, function(choice_a)
    if not choice_a then return end
    local a_idx = nil
    for i, name in ipairs(display_names) do
      if name == choice_a then a_idx = i; break end
    end

    local remaining, remaining_paths = {}, {}
    for i, name in ipairs(display_names) do
      if i ~= a_idx then
        remaining[#remaining + 1] = name
        remaining_paths[#remaining_paths + 1] = files[i]
      end
    end

    vim.ui.select(remaining, {
      prompt = "Compare '" .. choice_a .. "' with:",
    }, function(choice_b)
      if not choice_b then return end
      local b_path = nil
      for i, name in ipairs(remaining) do
        if name == choice_b then b_path = remaining_paths[i]; break end
      end
      if b_path then
        M.show_diff(files[a_idx], b_path, choice_a, choice_b)
      end
    end)
  end)
end

local function parse_file(file_path)
  local ok, lines = pcall(vim.fn.readfile, file_path)
  if not ok or not lines then return {} end
  local name = vim.fn.fnamemodify(file_path, ":t")
  if file_path:match("%.ya?ml$") then
    return config_mod.parse_yaml(lines, file_path)
  end
  return config_mod.parse_properties(lines, name)
end

function M.show_diff(file_a, file_b, name_a, name_b)
  name_a = name_a or vim.fn.fnamemodify(file_a, ":t")
  name_b = name_b or vim.fn.fnamemodify(file_b, ":t")

  local props_a = parse_file(file_a)
  local props_b = parse_file(file_b)

  local map_b = {}
  for _, p in ipairs(props_b) do map_b[p.key] = p end

  -- Build diff_type per line per file
  local diff_a, diff_b = {}, {}
  local same, changed, left_only, right_only = 0, 0, 0, 0

  for _, pa in ipairs(props_a) do
    local pb = map_b[pa.key]
    if not pb then
      diff_a[pa.line] = "left_only"; left_only = left_only + 1
    elseif pa.value ~= pb.value then
      diff_a[pa.line] = "changed"; diff_b[pb.line] = "changed"
      changed = changed + 1
    else
      diff_a[pa.line] = "same"; diff_b[pb.line] = "same"
      same = same + 1
    end
  end
  for _, pb in ipairs(props_b) do
    if not diff_b[pb.line] then
      local found = false
      for _, pa in ipairs(props_a) do
        if pa.key == pb.key then found = true; break end
      end
      if not found then
        diff_b[pb.line] = "right_only"; right_only = right_only + 1
      end
    end
  end

  local filter = { changed = true, left_only = true, right_only = true, same = true }
  local ns = vim.api.nvim_create_namespace("spring_tools_diff")

  local function hl_group_for(diff_type, none_ok)
    local hls = config.options.diff.highlights
    if diff_type == "same" then return hls.same or "SpringToolsRunning"
    elseif diff_type == "changed" then return hls.changed or "SpringToolsLogWarn"
    elseif diff_type == "left_only" then return hls.left_only or "SpringToolsError"
    elseif diff_type == "right_only" then return hls.right_only or "SpringToolsError"
    end
  end

  -- Store original lines; filter function rebuilds buffer content
  local orig_a = vim.fn.readfile(file_a)
  local orig_b = vim.fn.readfile(file_b)

  local function rebuild(buf, orig_lines, diff_map)
    local filtered, new_hl = {}, {}
    local new_line = 1
    for i, line in ipairs(orig_lines) do
      local dt = diff_map[i] or "other"
      if dt == "other" or filter[dt] then
        filtered[#filtered + 1] = line
        if dt ~= "other" then
          new_hl[new_line] = dt
        end
        new_line = new_line + 1
      end
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, filtered)
    vim.bo[buf].modifiable = false
    return new_hl
  end

  local function apply_highlights(buf, hl_map)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for line_num, diff_type in pairs(hl_map) do
      local hl_group = hl_group_for(diff_type)
      if hl_group then
        vim.api.nvim_buf_add_highlight(buf, ns, hl_group, line_num - 1, 0, -1)
      end
    end
  end

  -- Open file A
  local sidebar_mod = require("spring-tools.ui.sidebar")
  local main_win = nil
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if w ~= sidebar_mod.win then
      local b = vim.api.nvim_win_get_buf(w)
      if vim.bo[b].filetype ~= "springtools-output" then main_win = w; break end
    end
  end
  if main_win then vim.api.nvim_set_current_win(main_win) end

  -- Create scratch buffers (never touch real files)
  local buf_a = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf_a)
  vim.bo[buf_a].buftype = "nofile"
  vim.bo[buf_a].bufhidden = "wipe"
  vim.bo[buf_a].filetype = vim.filetype.match({ filename = file_a }) or "properties"
  local hl_a = rebuild(buf_a, orig_a, diff_a)
  apply_highlights(buf_a, hl_a)

  -- File B in vertical split
  vim.cmd("belowright vsplit")
  local buf_b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf_b)
  vim.bo[buf_b].buftype = "nofile"
  vim.bo[buf_b].bufhidden = "wipe"
  vim.bo[buf_b].filetype = vim.filetype.match({ filename = file_b }) or "properties"
  local hl_b = rebuild(buf_b, orig_b, diff_b)
  apply_highlights(buf_b, hl_b)

  -- Shared floating toolbar (replaces duplicate winbars)
  local toolbar_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[toolbar_buf].buftype = "nofile"
  vim.bo[toolbar_buf].modifiable = true

  local function update_toolbar()
    local parts = {}
    local function f(label, key, count)
      if filter[key] then table.insert(parts, label .. ":" .. count) else table.insert(parts, "·:" .. count) end
    end
    f("C", "changed", changed); f("L", "left_only", left_only)
    f("R", "right_only", right_only); f("S", "same", same)
    local counts = table.concat(parts, " ")
    local files = string.format("%-28s │ %s", name_a, name_b)
    local kb = "(c:changed  l:left  r:right  s:same  a:all  ?:help  q:close)"
    vim.bo[toolbar_buf].modifiable = true
    vim.api.nvim_buf_set_lines(toolbar_buf, 0, -1, false, { "  " .. files, "  " .. counts, "  " .. kb })
    vim.bo[toolbar_buf].modifiable = false
  end
  update_toolbar()

  local toolbar_width = 72
  local toolbar_win = vim.api.nvim_open_win(toolbar_buf, false, {
    relative = "editor",
    width = toolbar_width,
    height = 3,
    row = math.max(0, vim.o.lines - 5),
    col = math.floor((vim.o.columns - toolbar_width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Config Diff ",
    title_pos = "center",
    noautocmd = true,
  })
  vim.wo[toolbar_win].winhl = "Normal:SpringToolsNormal,FloatBorder:SpringToolsAccent"

  -- Highlights on toolbar lines
  local tns = vim.api.nvim_create_namespace("spring_tools_toolbar")
  vim.api.nvim_buf_add_highlight(toolbar_buf, tns, "SpringToolsDashboardProject", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(toolbar_buf, tns, "SpringToolsDim", 1, 0, -1)

  local function close()
    pcall(vim.api.nvim_win_close, toolbar_win, true)
    pcall(vim.api.nvim_buf_delete, toolbar_buf, { force = true })
    pcall(vim.api.nvim_buf_delete, buf_a, { force = true })
    pcall(vim.api.nvim_buf_delete, buf_b, { force = true })
  end

  local function show_help()
    local lines = {
      "  Config Diff",
      "  ───────────",
      "",
      "  c  Changed values (same key, different value)",
      "  l  Left-only (only in this file)",
      "  r  Right-only (only in other file)",
      "  s  Same values (identical in both)",
      "  a  Show all lines",
      "",
      "  q / Esc  Close",
    }
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    local w = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = 48, height = #lines, style = "minimal",
      border = "rounded", title = " Keybinds ", title_pos = "center",
      row = math.floor((vim.o.lines - #lines) / 2),
      col = math.floor((vim.o.columns - 48) / 2),
    })
    vim.keymap.set("n", "?", function() pcall(vim.api.nvim_win_close, w, true) end, { buffer = buf, silent = true })
    vim.keymap.set("n", "q", function() pcall(vim.api.nvim_win_close, w, true) end, { buffer = buf, silent = true })
    vim.keymap.set("n", "<Esc>", function() pcall(vim.api.nvim_win_close, w, true) end, { buffer = buf, silent = true })
  end

  local function toggle_filter(key)
    filter[key] = not filter[key]
    hl_a = rebuild(buf_a, orig_a, diff_a)
    hl_b = rebuild(buf_b, orig_b, diff_b)
    apply_highlights(buf_a, hl_a)
    apply_highlights(buf_b, hl_b)
    update_toolbar()
  end

  for _, b in ipairs({ buf_a, buf_b }) do
    vim.keymap.set("n", "q", close, { buffer = b, silent = true, nowait = true })
    vim.keymap.set("n", "<Esc>", close, { buffer = b, silent = true, nowait = true })
    vim.keymap.set("n", "c", function() toggle_filter("changed") end, { buffer = b, silent = true, nowait = true })
    vim.keymap.set("n", "l", function() toggle_filter("left_only") end, { buffer = b, silent = true, nowait = true })
    vim.keymap.set("n", "r", function() toggle_filter("right_only") end, { buffer = b, silent = true, nowait = true })
    vim.keymap.set("n", "s", function() toggle_filter("same") end, { buffer = b, silent = true, nowait = true })
    vim.keymap.set("n", "a", function()
      filter.changed = true; filter.left_only = true; filter.right_only = true; filter.same = true
      hl_a = rebuild(buf_a, orig_a, diff_a); hl_b = rebuild(buf_b, orig_b, diff_b)
      apply_highlights(buf_a, hl_a); apply_highlights(buf_b, hl_b)
      update_toolbar()
    end, { buffer = b, silent = true, nowait = true })
    vim.keymap.set("n", "?", show_help, { buffer = b, silent = true, nowait = true })
  end
end

return M
