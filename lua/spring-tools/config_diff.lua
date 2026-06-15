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
        M.show_diff(files[a_idx], b_path)
      end
    end)
  end)
end

function M.show_diff(file_a, file_b)
  -- Close any existing diff windows
  vim.cmd("diffoff!")

  -- Open file A in current window
  vim.cmd("edit " .. vim.fn.fnameescape(file_a))
  vim.bo.bufhidden = "wipe"
  vim.cmd("diffthis")
  vim.bo.modifiable = false

  -- Open file B in vertical split
  vim.cmd("belowright vsplit " .. vim.fn.fnameescape(file_b))
  vim.bo.bufhidden = "wipe"
  vim.cmd("diffthis")
  vim.bo.modifiable = false

  -- Set up close keymaps on both buffers
  local bufs = { vim.fn.bufnr(file_a), vim.fn.bufnr(file_b) }
  local function close()
    vim.cmd("diffoff!")
    for _, b in ipairs(bufs) do
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
  for _, b in ipairs(bufs) do
    if vim.api.nvim_buf_is_valid(b) then
      vim.keymap.set("n", "q", close, { buffer = b, silent = true, nowait = true })
      vim.keymap.set("n", "<Esc>", close, { buffer = b, silent = true, nowait = true })
    end
  end

  utils.notify(string.format("Diff: %s ↔ %s",
    vim.fn.fnamemodify(file_a, ":t"), vim.fn.fnamemodify(file_b, ":t")))
end

return M
