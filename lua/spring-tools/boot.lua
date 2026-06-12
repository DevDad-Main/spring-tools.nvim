local project = require("spring-tools.project")
local ui = require("spring-tools.ui")
local config = require("spring-tools.config")
local utils = require("spring-tools.utils")

local M = {}

M.processes = {}

function M.dashboard()
  local buf, win = ui.create_float_win({
    width = 70,
    height = 16,
    title = " Spring Boot Dashboard ",
  })

  local projects = project.detect_projects()
  if #projects == 0 then
    ui.set_lines(buf, {
      " No Spring Boot projects detected",
      "",
      " Looking for: pom.xml, build.gradle, build.gradle.kts",
      " Also scanning for @SpringBootApplication annotation",
      "",
      " Press 'r' to refresh, 'q' to close",
    })
    return
  end

  local lines = { " Spring Boot Applications", "" }
  local highlights = {}
  local line_num = 0

  for _, proj in ipairs(projects) do
    local status_icon = "○"
    local profile = ""
    local port = ""

    if M.processes[proj.root] then
      local proc = M.processes[proj.root]
      status_icon = proc.status == "running" and "✓" or "○"
      port = proc.port or ""
      profile = proc.profile or ""
    end

    local status_line = status_icon .. " " .. proj.name
    table.insert(lines, status_line)
    highlights[#highlights + 1] = { group = "Title", line = #lines - 1 }

    if port ~= "" then
      table.insert(lines, "   port: " .. port)
    end
    if profile ~= "" then
      table.insert(lines, "   profile: " .. profile)
    end
    local status_text = M.processes[proj.root] and "running" or "stopped"
    table.insert(lines, "   status: " .. status_text)
    table.insert(lines, "")
  end

  table.insert(lines, " Actions:")
  table.insert(lines, "  r - refresh    s - start    t - stop   l - view logs")
  table.insert(lines, "  c - config     q - close")

  ui.set_lines(buf, lines)
  ui.set_highlights(buf, highlights)

  vim.api.nvim_buf_set_keymap(buf, "n", "r", ":lua require('spring-tools.boot').dashboard()<CR>", { noremap = true, silent = true, nowait = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "s", ":lua require('spring-tools.boot').start_app()<CR>", { noremap = true, silent = true, nowait = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "t", ":lua require('spring-tools.boot').stop_app()<CR>", { noremap = true, silent = true, nowait = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "l", ":lua require('spring-tools.boot').view_logs()<CR>", { noremap = true, silent = true, nowait = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "c", ":lua require('spring-tools.boot').open_config()<CR>", { noremap = true, silent = true, nowait = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "R", ":lua require('spring-tools.boot').restart_app()<CR>", { noremap = true, silent = true, nowait = true })
end

function M.start_app()
  local proj = project.get_active_project()
  if not proj then
    utils.notify("No Spring Boot project found", vim.log.levels.WARN)
    return
  end

  local cmd = project.get_run_command(proj)
  if not cmd then
    utils.notify("Could not determine run command", vim.log.levels.ERROR)
    return
  end

  M.processes[proj.root] = {
    status = "running",
    pid = nil,
    port = "8080",
    profile = "default",
    logs = {},
  }

  ui.run_in_terminal(cmd, proj.root, function()
    if M.processes[proj.root] then
      M.processes[proj.root].status = "stopped"
    end
  end)

  utils.notify("Starting " .. proj.name)
  M.dashboard()
end

function M.stop_app()
  local proj = project.get_active_project()
  if not proj then return end

  local proc = M.processes[proj.root]
  if proc and proc.pid then
    vim.fn.jobstop(proc.pid)
    proc.status = "stopped"
    utils.notify("Stopped " .. proj.name)
  else
    utils.notify("No running process found", vim.log.levels.WARN)
  end
  M.dashboard()
end

function M.restart_app()
  M.stop_app()
  vim.defer_fn(function()
    M.start_app()
  end, 1000)
end

function M.view_logs()
  local proj = project.get_active_project()
  if not proj then return end

  local proc = M.processes[proj.root]
  if not proc then
    utils.notify("No logs available. Start the application first.", vim.log.levels.INFO)
    return
  end

  local log_file = proj.root .. "/logs/spring.log"
  local alt_log = proj.root .. "/target/surefire-reports/"

  local lines = { "Logs for " .. proj.name, "" }

  if vim.fn.filereadable(log_file) == 1 then
    local f = io.open(log_file, "r")
    if f then
      for line in f:lines() do
        table.insert(lines, line)
      end
      f:close()
    end
  else
    table.insert(lines, " No log file found at " .. log_file)
    table.insert(lines, " Check console output for running process")
  end

  ui.show_log_win(lines, proj.name .. " Logs")
end

function M.open_config()
  local proj = project.get_active_project()
  if not proj then return end

  local config_files = {
    proj.root .. "/src/main/resources/application.properties",
    proj.root .. "/src/main/resources/application.yml",
    proj.root .. "/src/main/resources/application.yaml",
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
    utils.notify("No application config found", vim.log.levels.WARN)
    return
  end

  utils.pick(found, { prompt_title = " Application Config " }, function(path)
    vim.cmd("edit " .. path)
  end)
end

return M
