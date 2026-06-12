local project = require("spring-tools.project")
local ui = require("spring-tools.ui")
local config = require("spring-tools.config")
local utils = require("spring-tools.utils")

local M = {}

M.processes = {}
M.selected = 1
M.projects = {}
M.dashboard_buf = nil
M.dashboard_win = nil

local function format_uptime(start_time)
  if not start_time then return "--" end
  local elapsed = os.difftime(os.time(), start_time)
  if elapsed < 60 then return math.floor(elapsed) .. "s"
  elseif elapsed < 3600 then return math.floor(elapsed / 60) .. "m"
  else return math.floor(elapsed / 3600) .. "h " .. math.floor((elapsed % 3600) / 60) .. "m" end
end

local function render_dashboard()
  if not M.dashboard_buf or not vim.api.nvim_buf_is_valid(M.dashboard_buf) then return end
  local buf = M.dashboard_buf

  M.projects = project.detect_projects()
  if #M.projects == 0 then
    ui.set_lines(buf, {
      "  No Spring Boot projects detected",
      "",
      "  Looking for: pom.xml, build.gradle, build.gradle.kts",
      "  Also scanning for @SpringBootApplication annotation",
      "",
      "  Press 'r' to refresh, 'q' to close",
    })
    return
  end

  if M.selected > #M.projects then M.selected = 1 end
  if M.selected < 1 then M.selected = 1 end

  local lines = {}
  table.insert(lines, "  Spring Boot Applications")
  table.insert(lines, "  " .. string.rep("─", 50))
  table.insert(lines, "")

  for idx, proj in ipairs(M.projects) do
    local prefix = idx == M.selected and "▸ " or "  "
    local proc = M.processes[proj.root]
    local is_running = proc and proc.status == "running"

    if is_running then
      table.insert(lines, prefix .. "✓ " .. proj.name .. "  (running)")
    else
      table.insert(lines, prefix .. "○ " .. proj.name .. "  (stopped)")
    end

    table.insert(lines, "     Build: " .. (proj.build_type or "?"))
    if is_running then
      table.insert(lines, "     Port: " .. (proc.port or "8080") .. "  Profile: " .. (proc.profile or "default"))
      table.insert(lines, "     Uptime: " .. format_uptime(proc.start_time) .. "  PID: " .. (proc.job_id or "?"))
      table.insert(lines, "     Log lines: " .. #(proc.logs or {}))
    end
    table.insert(lines, "")
  end

  table.insert(lines, "  " .. string.rep("─", 50))
  table.insert(lines, "  j/k: navigate  s: start  t: stop  r: restart")
  table.insert(lines, "  l: view logs  c: config  R: refresh  q: quit")

  ui.set_lines(buf, lines)

  local selected_line = 3
  if M.selected > 1 then
    for i = 1, M.selected - 1 do
      selected_line = selected_line + 1
      local proc = M.processes[M.projects[i].root]
      if proc and proc.status == "running" then
        selected_line = selected_line + 4
      else
        selected_line = selected_line + 2
      end
    end
  end
  pcall(function()
    vim.api.nvim_win_set_cursor(M.dashboard_win, { selected_line, 0 })
  end)
end

function M.dashboard()
  local buf, win = ui.create_float_win({
    fullscreen = true,
    title = " Spring Boot Dashboard ",
    border = "double",
  })

  M.dashboard_buf = buf
  M.dashboard_win = win

  render_dashboard()

  vim.api.nvim_buf_set_keymap(buf, "n", "j", "", {
    noremap = true, silent = true, nowait = true,
    callback = function()
      if M.selected < #M.projects then
        M.selected = M.selected + 1
        render_dashboard()
      end
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "k", "", {
    noremap = true, silent = true, nowait = true,
    callback = function()
      if M.selected > 1 then
        M.selected = M.selected - 1
        render_dashboard()
      end
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "s", "", {
    noremap = true, silent = true, nowait = true,
    callback = function()
      M.start_selected()
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "t", "", {
    noremap = true, silent = true, nowait = true,
    callback = function()
      M.stop_selected()
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "r", "", {
    noremap = true, silent = true, nowait = true,
    callback = function()
      M.restart_selected()
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "l", "", {
    noremap = true, silent = true, nowait = true,
    callback = function()
      M.view_selected_logs()
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "c", "", {
    noremap = true, silent = true, nowait = true,
    callback = function()
      M.open_selected_config()
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "R", "", {
    noremap = true, silent = true, nowait = true,
    callback = function()
      M.selected = 1
      render_dashboard()
      utils.notify("Dashboard refreshed")
    end,
  })
end

function M.get_selected_project()
  if #M.projects == 0 then
    utils.notify("No Spring Boot projects detected", vim.log.levels.WARN)
    return nil
  end
  return M.projects[M.selected]
end

function M.start_selected()
  local proj = M.get_selected_project()
  if not proj then return end

  if M.processes[proj.root] and M.processes[proj.root].status == "running" then
    utils.notify(proj.name .. " is already running", vim.log.levels.INFO)
    return
  end

  local cmd = project.get_run_command(proj)
  if not cmd then
    utils.notify("Could not determine run command", vim.log.levels.ERROR)
    return
  end

  local logs = {}

  local job_id, _ = ui.start_background_job(cmd, proj.root, {
    on_stdout = function(data)
      for _, line in ipairs(data or {}) do
        if line ~= "" then
          table.insert(logs, line)
          local port_match = line:match("Tomcat initialized with port%s*[:=]?%s*(%d+)")
          if port_match and M.processes[proj.root] then
            M.processes[proj.root].port = port_match
          end
          local profile_match = line:match("The following profiles are active:%s*(%w+)")
          if profile_match and M.processes[proj.root] then
            M.processes[proj.root].profile = profile_match
          end
        end
      end
      if M.processes[proj.root] then
        M.processes[proj.root].logs = logs
      end
    end,
    on_stderr = function(data)
      for _, line in ipairs(data or {}) do
        if line ~= "" then
          table.insert(logs, line)
        end
      end
      if M.processes[proj.root] then
        M.processes[proj.root].logs = logs
      end
    end,
    on_exit = function(exit_code)
      M.processes[proj.root] = M.processes[proj.root] or {}
      M.processes[proj.root].status = "stopped"
      M.processes[proj.root].logs = logs
      utils.notify(proj.name .. " exited with code " .. exit_code)
      if M.dashboard_buf and vim.api.nvim_buf_is_valid(M.dashboard_buf) then
        render_dashboard()
      end
    end,
  })

  if job_id and job_id > 0 then
    M.processes[proj.root] = {
      status = "running",
      job_id = job_id,
      port = "8080",
      profile = "default",
      start_time = os.time(),
      logs = logs,
    }
    utils.notify(proj.name .. " starting...")
  else
    utils.notify("Failed to start " .. proj.name, vim.log.levels.ERROR)
  end

  render_dashboard()
end

function M.stop_selected()
  local proj = M.get_selected_project()
  if not proj then return end

  local proc = M.processes[proj.root]
  if not proc or proc.status ~= "running" then
    utils.notify(proj.name .. " is not running", vim.log.levels.WARN)
    return
  end

  vim.fn.jobstop(proc.job_id)
  proc.status = "stopped"
  utils.notify("Stopped " .. proj.name)
  render_dashboard()
end

function M.restart_selected()
  local proj = M.get_selected_project()
  if not proj then return end

  local proc = M.processes[proj.root]
  if proc and proc.status == "running" then
    vim.fn.jobstop(proc.job_id)
    proc.status = "stopped"
  end

  vim.defer_fn(function()
    M.start_selected()
  end, 1500)
end

function M.view_selected_logs()
  local proj = M.get_selected_project()
  if not proj then return end

  local proc = M.processes[proj.root]
  local logs = proc and proc.logs or {}

  if #logs == 0 then
    logs = { "  (no logs yet)", "", "  Start the application first or check the path:" }
    local log_file = proj.root .. "/logs/spring.log"
    if vim.fn.filereadable(log_file) == 1 then
      table.insert(logs, "  " .. log_file)
      local f = io.open(log_file, "r")
      if f then
        for line in f:lines() do
          table.insert(logs, line)
        end
        f:close()
      end
    end
  end

  ui.show_log_viewer(proj.name .. " Logs", logs)
end

function M.open_selected_config()
  local proj = M.get_selected_project()
  if not proj then return end

  local config_files = {
    proj.root .. "/src/main/resources/application.properties",
    proj.root .. "/src/main/resources/application.yml",
    proj.root .. "/src/main/resources/application.yaml",
    proj.root .. "/src/main/resources/application-dev.properties",
    proj.root .. "/src/main/resources/application-dev.yml",
    proj.root .. "/src/main/resources/bootstrap.properties",
    proj.root .. "/src/main/resources/bootstrap.yml",
  }

  local found = {}
  for _, f in ipairs(config_files) do
    if vim.fn.filereadable(f) == 1 then
      table.insert(found, f)
    end
  end

  if #found == 0 then
    utils.notify("No application config found for " .. proj.name, vim.log.levels.WARN)
    return
  end

  utils.pick(found, { prompt_title = " " .. proj.name .. " Config " }, function(path)
    vim.cmd("edit " .. path)
  end)
end

function M.stop_all()
  for root, proc in pairs(M.processes) do
    if proc.status == "running" then
      vim.fn.jobstop(proc.job_id)
      proc.status = "stopped"
    end
  end
  utils.notify("All applications stopped")
end

return M
