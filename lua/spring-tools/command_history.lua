local utils = require("spring-tools.utils")
local config = require("spring-tools.config")
local project = require("spring-tools.project")
local state = require("spring-tools.core.state")
local backend = require("spring-tools.core.backend")
local output = require("spring-tools.ui.output")
local sidebar = require("spring-tools.ui.sidebar")

local M = {}

function M.list()
  local projects = state.get_projects()
  if not utils.cache.data then utils.cache.data = {} end
  local entries = {}
  for _, proj in ipairs(projects) do
    local cache_key = "recent_cmds:" .. proj.root
    local cmds = utils.cache.data[cache_key] or {}
    for _, cmd in ipairs(cmds) do
      entries[#entries + 1] = {
        project = proj.name,
        root = proj.root,
        command = cmd,
      }
    end
  end
  return entries
end

function M.delete(entry)
  if not entry then return end
  local cache_key = "recent_cmds:" .. entry.root
  local cmds = utils.cache.data[cache_key]
  if not cmds then return end
  for i = #cmds, 1, -1 do
    if cmds[i] == entry.command then
      table.remove(cmds, i)
    end
  end
  utils.cache.data[cache_key] = cmds
  utils.mark_dirty()
  utils.save_cache()
  utils.notify("Removed: " .. entry.command)
end

function M.run(entry)
  if not entry then return end
  local proj
  for _, p in ipairs(state.get_projects()) do
    if p.root == entry.root then proj = p; break end
  end
  if not proj then
    utils.notify("Project not found for: " .. entry.project, vim.log.levels.ERROR)
    return
  end
  local be = project.get_backend_for_project(proj)
  local cmd = vim.split(entry.command, "%s+")
  output.show({ "Starting " .. proj.name .. " with: " .. entry.command }, proj.name)
  local ok = backend.ProcessManager:start(proj, cmd, proj.root, {
    on_stdout = function(line)
      backend.ProcessManager:extract_port(proj, line)
      local logs = be:get_logs(proj)
      if #logs > 0 then
        vim.schedule(function()
          output.update_from_logs(logs, proj.name)
        end)
      end
    end,
    on_exit = function(exit_code)
      vim.schedule(function()
        local log_lines = be:get_logs(proj)
        if #log_lines == 0 then log_lines = { "(no output captured)" } end
        local start = math.max(1, #log_lines - 100)
        local recent = {}
        for i = start, #log_lines do table.insert(recent, log_lines[i]) end
        table.insert(recent, "")
        if exit_code == 0 then
          table.insert(recent, "Process exited cleanly")
        else
          table.insert(recent, "Process exited with code " .. exit_code)
        end
        local final = {}
        table.insert(final, "═══ Full output ═══")
        for _, l in ipairs(recent) do table.insert(final, l) end
        if output.win and vim.api.nvim_win_is_valid(output.win) then
          output.show(final, proj.name .. " (exit " .. exit_code .. ")", { footer = true })
        end
        if exit_code ~= 0 then
          utils.notify(proj.name .. " exited with code " .. exit_code, vim.log.levels.ERROR)
        end
        sidebar.refresh()
      end)
    end,
  })
  if not ok then
    utils.notify("Failed to start " .. proj.name, vim.log.levels.ERROR)
  else
    sidebar.refresh()
  end
end

function M.open()
  local entries = M.list()
  if #entries == 0 then
    utils.notify("No saved custom commands", vim.log.levels.WARN)
    return
  end

  local items = {}
  local last_project = nil
  for _, entry in ipairs(entries) do
    if entry.project ~= last_project then
      items[#items + 1] = {
        display = "─── " .. entry.project .. " ───",
        entry = nil,
        separator = true,
      }
      last_project = entry.project
    end
    items[#items + 1] = {
      display = string.format("  %s", entry.command),
      entry = entry,
      separator = false,
    }
  end

  if utils.has_telescope() and config.options.telescope.enable then
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values

    pickers.new({}, {
      prompt_title = "Command History (" .. #entries .. " cmds)",
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          return {
            value = item.entry,
            display = item.display,
            ordinal = item.display,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, _)
        local select_default = actions.select_default
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if not selection or not selection.value then return end
          actions.close(prompt_bufnr)
          vim.schedule(function()
            M.show_actions(selection.value)
          end)
        end)
        return true
      end,
    }):find()
    return
  end

  -- vim.ui.select fallback
  local non_separators = {}
  for _, item in ipairs(items) do
    if not item.separator then
      non_separators[#non_separators + 1] = item
    end
  end

  vim.ui.select(non_separators, {
    prompt = "Command History (" .. #entries .. " cmds)",
    format_item = function(item)
      return item.entry.project .. "  →  " .. item.entry.command
    end,
  }, function(choice)
    if not choice then return end
    M.show_actions(choice.entry)
  end)
end

function M.show_actions(entry)
  local actions = {
    { label = "▶  Re-run", action = function() M.run(entry) end },
    { label = "  Copy", action = function()
      vim.fn.setreg("+", entry.command)
      utils.notify("Copied: " .. entry.command)
    end },
    { label = "✕  Delete", action = function()
      M.delete(entry)
      utils.notify("Deleted: " .. entry.command)
    end },
  }

  vim.ui.select(actions, {
    prompt = entry.project .. " → " .. entry.command,
    format_item = function(a) return a.label end,
  }, function(choice)
    if not choice then return end
    choice.action()
  end)
end

return M
