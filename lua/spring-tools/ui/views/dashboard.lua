local config = require("spring-tools.config")
local project = require("spring-tools.project")
local backend = require("spring-tools.backends")
local state = require("spring-tools.core.state")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")
local utils = require("spring-tools.utils")

local M = {}

M.title = "Dashboard"

function M.header()
  local count = #state.get_projects()
  local parts = { "Spring Tools \u{b7} " .. count .. " project" .. (count ~= 1 and "s" or "") }
  return { { table.concat(parts, ""), "SpringToolsHeader" } }
end

M.items = {}

function M:load_items()
  state.set_projects(project.detect_projects())
  local projs = state.get_projects()
  local active = project.get_active_project()
  M.items = {}
  for _, proj in ipairs(projs) do
    local be = project.get_backend_for_project(proj)
    local status = be and be:get_status(proj) or "stopped"
    M.items[#M.items + 1] = {
      type = "project",
      project = proj,
      backend = be,
      status = status,
      is_active = active and proj.root == active.root,
    }
  end
end

function M:render_item(item, selected)
  local proj = item.project
  local be = item.backend
  local status = item.status
  local proc = be and require("spring-tools.core.backend").ProcessManager.get(nil, proj)
  local is_running = status == "running"
  local is_failed = status == "failed"

  local dot, dot_hl
  if is_running then
    dot = "\u{25cf}"
    dot_hl = "SpringToolsRunning"
  elseif is_failed then
    dot = "\u{25cf}"
    dot_hl = "SpringToolsError"
  else
    dot = "\u{25cb}"
    dot_hl = "SpringToolsDim"
  end

  local status_tag, status_hl
  if is_running then
    local parts = {}
    local port = (be and be.get_port and be:get_port(proj)) or ""
    local profile = (be and be.get_profile and be:get_profile(proj)) or ""
    local uptime = (be and be.get_uptime and be:get_uptime(proj)) or ""
    if port ~= "" then table.insert(parts, ":" .. port) end
    if profile ~= "" and profile ~= "default" then table.insert(parts, profile) end
    if uptime ~= "" then table.insert(parts, uptime) end
    table.insert(parts, "running")
    status_tag = table.concat(parts, "  ")
    status_hl = "SpringToolsRunning"
  elseif is_failed then
    local code = proc and proc.exit_code or "?"
    status_tag = "failed" .. (code ~= "" and " exit " .. code or "")
    status_hl = "SpringToolsError"
  else
    status_tag = "stopped"
    status_hl = "SpringToolsDim"
  end

  local build_type = (proj.build_type or ""):len() > 0 and proj.build_type or nil

  local active_mark = item.is_active and "\u{2605} " or "  "

  if selected then
    local line = active_mark .. dot .. "  " .. proj.name .. "  " .. status_tag .. (build_type and "  " .. build_type or "")
    return { { line, "SpringToolsSelected" } }
  end

  return { {
    segments = {
      { active_mark .. dot .. "  ", dot_hl },
      { proj.name, "SpringToolsDashboardProject" },
      { "  " .. status_tag, status_hl },
      { build_type and "  " .. build_type or "", build_type and "SpringToolsDashboardBuildType" or nil },
    },
  } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  local proj = item.project
  local be = item.backend

  project.set_active_project(proj)

  if item.status == "running" then
    local actions = {
      { label = "View logs", action = function() M.show_logs(proj) end },
      { label = "Stop", action = function() backend.ProcessManager:stop(proj); sidebar.refresh() end },
      { label = "Restart", action = function()
        output.show({ "Restarting " .. proj.name .. "..." }, proj.name)
        backend.ProcessManager:restart(proj, {
          on_stdout = function(line)
            backend.ProcessManager:extract_port(proj, line)
            local logs = be:get_logs(proj)
            if #logs > 0 then
              local start = math.max(1, #logs - 50)
              local recent = {}
              for i = start, #logs do table.insert(recent, logs[i]) end
              vim.schedule(function()
                if output.win and vim.api.nvim_win_is_valid(output.win) then
                  vim.bo[output.buf].modifiable = true
                  vim.api.nvim_buf_set_lines(output.buf, 0, -1, false, recent)
                  vim.bo[output.buf].modifiable = false
                end
              end)
            end
          end,
          on_exit = function(exit_code)
            vim.schedule(function()
              local log_lines = be:get_logs(proj)
              local recent = {}
              local start = math.max(1, #log_lines - 100)
              for i = start, #log_lines do table.insert(recent, log_lines[i]) end
              local cause = M.extract_cause(recent)
              table.insert(recent, "")
              table.insert(recent, exit_code == 0 and "Restarted successfully" or "Restart failed with code " .. exit_code)
              local final = {}
              for _, l in ipairs(cause) do table.insert(final, l) end
              if #cause > 0 then table.insert(final, "\u{2550}\u{2550}\u{2550} Full output \u{2550}\u{2550}\u{2550}") end
              for _, l in ipairs(recent) do table.insert(final, l) end
              if output.win and vim.api.nvim_win_is_valid(output.win) then
                output.show(final, proj.name .. (exit_code == 0 and "" or " (exit " .. exit_code .. ")"))
              end
              if exit_code ~= 0 then
                utils.notify(proj.name .. " restart failed", vim.log.levels.ERROR)
              end
              sidebar.refresh()
            end)
          end,
        })
      end },
      { label = "Open config", action = function() M.open_config(proj) end },
    }
    M.show_actions(actions)
  elseif item.status == "failed" then
    local actions = {
      { label = "View logs", action = function() M.show_logs(proj) end },
      { label = "Restart", action = function()
        output.show({ "Restarting " .. proj.name .. "..." }, proj.name)
        backend.ProcessManager:restart(proj, {
          on_stdout = function(line)
            backend.ProcessManager:extract_port(proj, line)
            local logs = be:get_logs(proj)
            if #logs > 0 then
              local start = math.max(1, #logs - 50)
              local recent = {}
              for i = start, #logs do table.insert(recent, logs[i]) end
              vim.schedule(function()
                if output.win and vim.api.nvim_win_is_valid(output.win) then
                  vim.bo[output.buf].modifiable = true
                  vim.api.nvim_buf_set_lines(output.buf, 0, -1, false, recent)
                  vim.bo[output.buf].modifiable = false
                end
              end)
            end
          end,
          on_exit = function(exit_code)
            vim.schedule(function()
              local log_lines = be:get_logs(proj)
              local recent = {}
              local start = math.max(1, #log_lines - 100)
              for i = start, #log_lines do table.insert(recent, log_lines[i]) end
              local cause = M.extract_cause(recent)
              table.insert(recent, "")
              table.insert(recent, exit_code == 0 and "Restarted successfully" or "Restart failed with code " .. exit_code)
              local final = {}
              for _, l in ipairs(cause) do table.insert(final, l) end
              if #cause > 0 then table.insert(final, "\u{2550}\u{2550}\u{2550} Full output \u{2550}\u{2550}\u{2550}") end
              for _, l in ipairs(recent) do table.insert(final, l) end
              if output.win and vim.api.nvim_win_is_valid(output.win) then
                output.show(final, proj.name .. (exit_code == 0 and "" or " (exit " .. exit_code .. ")"))
              end
              if exit_code ~= 0 then
                utils.notify(proj.name .. " restart failed", vim.log.levels.ERROR)
              end
              sidebar.refresh()
            end)
          end,
        })
      end },
    }
    M.show_actions(actions)
  elseif item.status == "stopped" then
    local default_cmd = be and be:get_run_command(proj)
    if not default_cmd then utils.notify("No run command available for " .. proj.name, vim.log.levels.WARN) return end
    local default_str = table.concat(default_cmd, " ")
    local build_type = proj.build_type or "maven"
    local suggestions = { default_str }
    if build_type == "maven" then
      suggestions[#suggestions + 1] = "mvn clean compile"
      suggestions[#suggestions + 1] = "mvn test"
      suggestions[#suggestions + 1] = "mvn package -DskipTests"
      suggestions[#suggestions + 1] = "mvn clean install"
    else
      suggestions[#suggestions + 1] = "gradle build"
      suggestions[#suggestions + 1] = "gradle test"
      suggestions[#suggestions + 1] = "gradle clean build"
      suggestions[#suggestions + 1] = "gradle bootRun"
    end
    suggestions[#suggestions + 1] = "Custom..."

    local function run_cmd(cmd)
      output.show({ "Starting " .. proj.name .. " with: " .. table.concat(cmd, " ") }, proj.name)
      local ok = backend.ProcessManager:start(proj, cmd, proj.root, {
        on_stdout = function(line)
          backend.ProcessManager:extract_port(proj, line)
          local logs = be:get_logs(proj)
          if #logs > 0 then
            local start = math.max(1, #logs - 50)
            local recent = {}
            for i = start, #logs do table.insert(recent, logs[i]) end
            vim.schedule(function()
              if output.win and vim.api.nvim_win_is_valid(output.win) then
                vim.bo[output.buf].modifiable = true
                vim.api.nvim_buf_set_lines(output.buf, 0, -1, false, recent)
                vim.bo[output.buf].modifiable = false
              end
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
            local cause = M.extract_cause(recent)
            table.insert(recent, "")
            if exit_code == 0 then
              table.insert(recent, "Process exited cleanly")
            else
              table.insert(recent, "Process exited with code " .. exit_code)
            end
            local final = {}
            for _, l in ipairs(cause) do table.insert(final, l) end
            if #cause > 0 then table.insert(final, "═══ Full output ═══") end
            for _, l in ipairs(recent) do table.insert(final, l) end
            if output.win and vim.api.nvim_win_is_valid(output.win) then
              output.show(final, proj.name .. " (exit " .. exit_code .. ")")
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
      end
      sidebar.refresh()
    end

    vim.ui.select(suggestions, { prompt = "Select or enter a command:" }, function(choice)
      if not choice then return end
      if choice == "Custom..." then
        vim.ui.input({ prompt = "Run command:", default = default_str }, function(input)
          if input == nil then return end
          run_cmd(input == "" and default_cmd or vim.split(input, "%s+"))
        end)
      else
        run_cmd(vim.split(choice, "%s+"))
      end
    end)
  end
end

function M:on_remove(idx)
  local item = M.items[idx]
  if not item then
    utils.notify("No item selected", vim.log.levels.WARN)
    return
  end
  local proj = item.project
  local was_active = item.is_active
  local ok = project.remove_project(proj.root)
  if ok then
    utils.notify("Removed " .. proj.name .. " from project cache")
    if was_active then
      project.set_active_project(nil)
    end
    sidebar.refresh()
  else
    utils.notify("Could not remove " .. proj.name .. " (not in cache)", vim.log.levels.WARN)
  end
end

function M.show_actions(actions)
  local labels = vim.tbl_map(function(a) return a.label end, actions)
  local map = {}
  for _, a in ipairs(actions) do
    map[a.label] = a.action
  end
  vim.ui.select(labels, {
    prompt = "Select action:",
  }, function(choice)
    if choice and map[choice] then map[choice]() end
  end)
end

function M.extract_cause(logs)
  local causes = {}
  for _, line in ipairs(logs) do
    local cause = line:match("Caused by: (.+)")
    if cause then
      table.insert(causes, cause)
    end
  end
  if #causes > 0 then
    local summary = { "", "═══ Root cause ═══" }
    for _, c in ipairs(causes) do
      table.insert(summary, "  " .. c)
    end
    table.insert(summary, "")
    return summary
  end
  return {}
end

function M.show_logs(proj)
  local be = project.get_backend_for_project(proj)
  local logs = (be and be.get_logs and be:get_logs(proj)) or {}
  if #logs == 0 then
    output.show({ "(no logs captured)" }, proj.name)
    return
  end
  local start = math.max(1, #logs - 100)
  local recent = {}
  for i = start, #logs do table.insert(recent, logs[i]) end
  local cause = M.extract_cause(logs)
  local final = {}
  for _, l in ipairs(cause) do table.insert(final, l) end
  if #cause > 0 then table.insert(final, "═══ Full output ═══") end
  for _, l in ipairs(recent) do table.insert(final, l) end
  local proc = be and require("spring-tools.core.backend").ProcessManager.get(nil, proj)
  local title = proc and proc.status == "failed" and (proj.name .. " (exit " .. (proc.exit_code or "?") .. ")") or proj.name
  output.show(final, title)
end

function M.open_config(proj)
  local files = {
    proj.root .. "/src/main/resources/application.properties",
    proj.root .. "/src/main/resources/application.yml",
    proj.root .. "/src/main/resources/application.yaml",
  }
  local found = {}
  for _, f in ipairs(files) do
    if vim.fn.filereadable(f) == 1 then table.insert(found, f) end
  end
  if #found == 0 then
    output.show({ "(no config files found)" }, "Config")
    return
  end
  vim.ui.select(found, { prompt = "Open config:" }, function(path)
    if path then sidebar.open_in_main(path) end
  end)
end

return M
