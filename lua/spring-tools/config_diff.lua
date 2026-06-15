local config_mod = require("spring-tools.config_explorer")
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

    local remaining = {}
    local remaining_paths = {}
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
  if file_path:match("%.ya?ml$") then
    local ok, lines = pcall(vim.fn.readfile, file_path)
    if not ok or not lines then return {} end
    return config_mod.parse_yaml(lines, file_path)
  else
    local ok, lines = pcall(vim.fn.readfile, file_path)
    if not ok or not lines then return {} end
    return config_mod.parse_properties(lines, vim.fn.fnamemodify(file_path, ":t"))
  end
end

local function pad_right(str, len)
  if #str >= len then return str:sub(1, len) end
  return str .. string.rep(" ", len - #str)
end

local function truncate(str, len)
  if #str <= len then return str end
  return str:sub(1, len - 1) .. "\u{2026}"
end

function M.show_diff(file_a, file_b, name_a, name_b)
  name_a = name_a or vim.fn.fnamemodify(file_a, ":t")
  name_b = name_b or vim.fn.fnamemodify(file_b, ":t")

  local props_a = parse_file(file_a)
  local props_b = parse_file(file_b)

  local all_keys = {}
  local seen = {}
  for _, p in ipairs(props_a) do
    if not seen[p.key] then seen[p.key] = true; all_keys[#all_keys + 1] = p.key end
  end
  for _, p in ipairs(props_b) do
    if not seen[p.key] then seen[p.key] = true; all_keys[#all_keys + 1] = p.key end
  end
  table.sort(all_keys)

  local map_a, map_b = {}, {}
  for _, p in ipairs(props_a) do map_a[p.key] = p end
  for _, p in ipairs(props_b) do map_b[p.key] = p end

  local ns = vim.api.nvim_create_namespace("spring_tools_diff")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "springtools-diff"
  vim.bo[buf].bufhidden = "wipe"

  local lines = {}
  local highlights = {}
  local left_width = 45

  table.insert(lines, "")
  table.insert(lines, "  " .. name_a .. string.rep(" ", 38) .. " │ " .. name_b)
  table.insert(lines, "  " .. string.rep("─", left_width) .. "─┼─" .. string.rep("─", left_width))
  table.insert(highlights, nil); table.insert(highlights, nil); table.insert(highlights, nil)

  local same, changed, left_only, right_only = 0, 0, 0, 0

  for _, key in ipairs(all_keys) do
    local pa, pb = map_a[key], map_b[key]
    local va = pa and pa.value or "\u{2014}"
    local vb = pb and pb.value or "\u{2014}"

    local diff_type
    if not pa then
      diff_type = "right_only"; right_only = right_only + 1
    elseif not pb then
      diff_type = "left_only"; left_only = left_only + 1
    elseif va ~= vb then
      diff_type = "changed"; changed = changed + 1
    else
      diff_type = "same"; same = same + 1
    end

    local left_col = pad_right("  " .. key .. " = " .. truncate(va, 28), left_width)
    local right_col = key .. " = " .. truncate(vb, 28)
    local line = left_col .. " │ " .. right_col
    table.insert(lines, line)
    table.insert(highlights, { diff_type = diff_type })
  end

  table.insert(lines, "  " .. string.rep("─", left_width) .. "─┴─" .. string.rep("─", left_width))
  table.insert(highlights, nil)
  local summary = string.format("  %d same  %d changed  %d " .. name_a .. "-only  %d " .. name_b .. "-only",
    same, changed, left_only, right_only)
  table.insert(lines, summary)
  table.insert(highlights, nil)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  for line_idx, h in ipairs(highlights) do
    if h then
      local hl_group
      if h.diff_type == "changed" then
        hl_group = "SpringToolsLogInfo"
      elseif h.diff_type == "left_only" then
        hl_group = "SpringToolsLogWarn"
      elseif h.diff_type == "right_only" then
        hl_group = "SpringToolsAccent"
      end
      -- Only highlight changed/different lines, leave "same" with no highlight
      if hl_group then
        vim.api.nvim_buf_add_highlight(buf, ns, hl_group, line_idx - 1, 0, -1)
      end
    end
  end

  vim.bo[buf].modifiable = false

  -- Open in main editor window
  local sidebar_mod = require("spring-tools.ui.sidebar")
  local target_win = nil
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if w ~= sidebar_mod.win then
      local b = vim.api.nvim_win_get_buf(w)
      if vim.bo[b].filetype ~= "springtools-output" then
        target_win = w; break
      end
    end
  end
  if target_win then vim.api.nvim_set_current_win(target_win) end
  vim.api.nvim_set_current_buf(buf)

  local function close()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true, nowait = true })
end

return M
