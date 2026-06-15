local config_mod = require("spring-tools.config_explorer")
local config = require("spring-tools.config")
local project = require("spring-tools.project")
local utils = require("spring-tools.utils")

local M = {}

M._filter = { changed = true, left_only = true, right_only = true }

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

  local hl_a, hl_b = {}, {}
  local same, changed, left_only, right_only = 0, 0, 0, 0

  for _, pa in ipairs(props_a) do
    local pb = map_b[pa.key]
    if not pb then
      hl_a[pa.line] = "left_only"; left_only = left_only + 1
    elseif pa.value ~= pb.value then
      hl_a[pa.line] = "changed"; hl_b[pb.line] = "changed"
      changed = changed + 1
    else
      same = same + 1
    end
  end
  for _, pb in ipairs(props_b) do
    if not hl_b[pb.line] then
      local found = false
      for _, pa in ipairs(props_a) do
        if pa.key == pb.key then found = true; break end
      end
      if not found then
        hl_b[pb.line] = "right_only"; right_only = right_only + 1
      end
    end
  end

  local filter = { changed = true, left_only = true, right_only = true }
  local ns = vim.api.nvim_create_namespace("spring_tools_diff")

  local function hl_group_for(diff_type)
    local hls = config.options.diff.highlights
    if diff_type == "changed" then return hls.changed or "SpringToolsLogInfo"
    elseif diff_type == "left_only" then return hls.left_only or "SpringToolsLogWarn"
    elseif diff_type == "right_only" then return hls.right_only or "SpringToolsLogWarn"
    end
  end

  local function apply_highlights(buf, highlights)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for line_num, diff_type in pairs(highlights) do
      if filter[diff_type] then
        local hl_group = hl_group_for(diff_type)
        if hl_group then
          vim.api.nvim_buf_add_highlight(buf, ns, hl_group, line_num - 1, 0, -1)
        end
      end
    end
  end

  local counts = { same = same, changed = changed, left_only = left_only, right_only = right_only }
  local function echo_summary()
    local parts = {}
    table.insert(parts, " ")
    table.insert(parts, (filter.changed and "C:" or "·:") .. changed)
    table.insert(parts, (filter.left_only and " L:" or " ·:") .. left_only)
    table.insert(parts, (filter.right_only and " R:" or " ·:") .. right_only)
    table.insert(parts, "  s:same " .. same .. "  " .. name_a .. " ↔ " .. name_b)
    vim.api.nvim_echo({{ table.concat(parts, " "), "SpringToolsAccent" }}, false, {})
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
  vim.cmd("edit " .. vim.fn.fnameescape(file_a))
  local buf_a = vim.api.nvim_get_current_buf()
  vim.bo[buf_a].bufhidden = "wipe"
  vim.bo[buf_a].modifiable = false
  apply_highlights(buf_a, hl_a)

  -- Open file B
  vim.cmd("belowright vsplit " .. vim.fn.fnameescape(file_b))
  local buf_b = vim.api.nvim_get_current_buf()
  vim.bo[buf_b].bufhidden = "wipe"
  vim.bo[buf_b].modifiable = false
  apply_highlights(buf_b, hl_b)

  echo_summary()

  -- Filter keymaps + close
  local function close()
    pcall(vim.api.nvim_buf_delete, buf_a, { force = true })
    pcall(vim.api.nvim_buf_delete, buf_b, { force = true })
  end

  local function toggle_filter(key)
    filter[key] = not filter[key]
    apply_highlights(buf_a, hl_a)
    apply_highlights(buf_b, hl_b)
    echo_summary()
  end

  for _, b in ipairs({ buf_a, buf_b }) do
    vim.keymap.set("n", "q", close, { buffer = b, silent = true, nowait = true })
    vim.keymap.set("n", "<Esc>", close, { buffer = b, silent = true, nowait = true })
    vim.keymap.set("n", "c", function() toggle_filter("changed") end, { buffer = b, silent = true, nowait = true, desc = "Toggle changed lines" })
    vim.keymap.set("n", "l", function() toggle_filter("left_only") end, { buffer = b, silent = true, nowait = true, desc = "Toggle left-only lines" })
    vim.keymap.set("n", "r", function() toggle_filter("right_only") end, { buffer = b, silent = true, nowait = true, desc = "Toggle right-only lines" })
    vim.keymap.set("n", "a", function()
      filter.changed = true; filter.left_only = true; filter.right_only = true
      apply_highlights(buf_a, hl_a)
      apply_highlights(buf_b, hl_b)
      echo_summary()
    end, { buffer = b, silent = true, nowait = true, desc = "Show all highlights" })
  end
end

return M
