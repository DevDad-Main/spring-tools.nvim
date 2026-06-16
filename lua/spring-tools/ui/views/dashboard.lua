local config = require("spring-tools.config")
local project = require("spring-tools.project")
local backend = require("spring-tools.backends")
local state = require("spring-tools.core.state")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")
local utils = require("spring-tools.utils")
local build = require("spring-tools.build_completion")
local sections = require("spring-tools.ui.sections").new("dashboard")

local M = {}

M.title = "Dashboard"

function M.header()
  local count = #state.get_projects()
  local ws = state.get_workspace_root()
  if ws and count > 1 then
    local ws_name = vim.fn.fnamemodify(ws, ":t")
    return { { "Spring Tools \u{b7} 1 workspace \u{b7} " .. count .. " project" .. (count ~= 1 and "s" or ""), "SpringToolsHeader" } }
  end
  local parts = { "Spring Tools \u{b7} " .. count .. " project" .. (count ~= 1 and "s" or "") }
  return { { table.concat(parts, ""), "SpringToolsHeader" } }
end

M.items = {}
M._auto_restart = {}
M._restart_timers = {}
M._last_restart = {}
M._auto_clean = {}

function M:load_items()
  build.invalidate_cache()
  state.set_projects(project.detect_projects(), project.workspace_root)
  local projs = state.get_projects()
  local active = project.get_active_project()
  local ws = state.get_workspace_root()
  M.items = {}
  local maven_roots = {}
  local gradle_roots = {}

  -- Restore persisted auto-restart toggles
  if utils.cache.data then
    for _, proj in ipairs(projs) do
      local ar_key = "auto_restart:" .. proj.root
      if utils.cache.data[ar_key] ~= nil then
        M._auto_restart[proj.root] = utils.cache.data[ar_key]
      end
      local cl_key = "auto_clean:" .. proj.root
      if utils.cache.data[cl_key] ~= nil then
        M._auto_clean[proj.root] = utils.cache.data[cl_key]
      end
    end
  end

  local function build_project_item(proj)
    local be = project.get_backend_for_project(proj)
    local status = be and be:get_status(proj) or "stopped"
    if proj.build_type == "maven" then
      maven_roots[#maven_roots + 1] = proj.root
    elseif proj.build_type == "gradle" then
      gradle_roots[#gradle_roots + 1] = proj.root
    end
    return {
      type = "project",
      project = proj,
      backend = be,
      status = status,
      is_active = active and proj.root == active.root,
    }
  end

  local function add_project_items(proj_list, indent)
    indent = indent or 0
    for _, proj in ipairs(proj_list) do
      local has_children = proj.children and #proj.children > 0
      if has_children then
        local sk = "parent:" .. proj.root
        local is_collapsed = sections:is_collapsed(sk)
        M.items[#M.items + 1] = { type = "parent_header", project = proj, label = proj.name, section_key = sk, collapsed = is_collapsed, indent = indent }
        if not is_collapsed then
          add_project_items(proj.children, indent + 1)
        end
      else
        local item = build_project_item(proj)
        item.indent = indent
        table.insert(M.items, item)
      end
    end
  end

  local ws_is_project = false
  if ws and #projs > 1 then
    local ws_resolved = vim.fn.resolve(ws)
    for _, proj in ipairs(projs) do
      if proj.is_top_level and vim.fn.resolve(proj.root) == ws_resolved then
        ws_is_project = true
        break
      end
    end
    local top_level = {}
    for _, proj in ipairs(projs) do
      if proj.is_top_level then table.insert(top_level, proj) end
    end
    local docker_compose_file
    for _, f in ipairs({ "docker-compose.yml", "docker-compose.yaml" }) do
      local p = ws .. "/" .. f
      if vim.fn.filereadable(p) == 1 then docker_compose_file = p; break end
    end
    if ws_is_project then
      add_project_items(top_level)
      if docker_compose_file then
        M.items[#M.items + 1] = { type = "docker", label = "docker-compose", compose_file = docker_compose_file, indent = 0 }
      end
    else
      local ws_name = vim.fn.fnamemodify(ws, ":t")
      local sk = "parent:" .. ws
      local is_collapsed = sections:is_collapsed(sk)
      M.items[#M.items + 1] = { type = "parent_header", label = ws_name, section_key = sk, collapsed = is_collapsed, indent = 0 }
      if not is_collapsed then
        for _, proj in ipairs(top_level) do
          local item = build_project_item(proj)
          item.indent = 1
          table.insert(M.items, item)
        end
        if docker_compose_file then
          M.items[#M.items + 1] = { type = "docker", label = "docker-compose", compose_file = docker_compose_file, indent = 1 }
        end
      end
    end
  else
    add_project_items(projs)
  end
  if #maven_roots > 0 then
    build.fetch_dynamic_goals(maven_roots)
  end
  if #gradle_roots > 0 then
    build.fetch_gradle_tasks(gradle_roots)
  end
end

function M:render_item(item, selected)
  if item.type == "workspace" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsSectionHeader"
    return { { "  \u{25be} " .. item.label, hl } }
  end
  if item.type == "parent_header" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local indent = string.rep("  ", item.indent or 0)
    local hl = selected and "SpringToolsSelected" or "SpringToolsAccent"
    return { { indent .. icon .. "  " .. item.label, hl } }
  end
  if item.type == "docker" then
    local indent = string.rep("  ", item.indent or 0)
    local hl = selected and "SpringToolsSelected" or "SpringToolsDashboardProject"
    return { { indent .. "  " .. "\u{f308}  " .. item.label, hl } }
  end
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
  local auto_restart = M._auto_restart[proj.root] and "\u{21bb} " or ""

  local indent = string.rep("  ", item.indent or 0)
  local active_mark = item.is_active and "\u{2605} " or "  "

  if selected then
    local line = indent .. active_mark .. dot .. "  " .. proj.name .. "  " .. auto_restart .. status_tag .. (build_type and "  " .. build_type or "")
    return { { line, "SpringToolsSelected" } }
  end

  return { {
    segments = {
      { indent .. active_mark .. dot .. "  ", dot_hl },
      { proj.name, "SpringToolsDashboardProject" },
      { "  " .. auto_restart .. status_tag, status_hl },
      { build_type and "  " .. build_type or "", build_type and "SpringToolsDashboardBuildType" or nil },
    },
  } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item or item.type == "workspace" then return end
  if item.type == "parent_header" then
    sections:toggle(item.section_key)
    sidebar.refresh()
    return
  end
  if item.type == "docker" then
    local docker_menu = {}
    for _, cmd in ipairs({ "up", "down", "build", "up -d", "logs -f", "ps", "restart", "pull", "stop", "start", "exec", "run", "top", "config", "rm" }) do
      docker_menu[#docker_menu + 1] = {
        label = "  docker-compose " .. cmd,
        action = function()
          local full_cmd = "docker-compose -f " .. item.compose_file .. " " .. cmd
          output.show({ "Running: " .. full_cmd }, "docker-compose")
          vim.fn.jobstart(vim.split(full_cmd, " "), {
            cwd = state.get_workspace_root(),
            on_stdout = function(_, data)
              if data then vim.schedule(function()
                for _, l in ipairs(data) do if #l > 0 then output.append(l) end end
              end) end
            end,
            on_stderr = function(_, data)
              if data then vim.schedule(function()
                for _, l in ipairs(data) do if #l > 0 then output.append(l) end end
              end) end
            end,
          })
        end,
      }
    end
    M.show_actions(docker_menu)
    return
  end
  local proj = item.project
  local be = item.backend

  project.set_active_project(proj)

  local default_cmd = be and be:get_run_command(proj)
  local default_str = default_cmd and table.concat(default_cmd, " ") or nil
  local build_type = proj.build_type or "maven"
  local cache_key = "recent_cmds:" .. proj.root
  local recent = (utils.cache.data and utils.cache.data[cache_key]) or {}

  local function run_cmd(cmd)
    output.show({ "Starting " .. proj.name .. " with: " .. table.concat(cmd, " ") }, proj.name)
    local ok = require("spring-tools.core.backend").ProcessManager:start(proj, cmd, proj.root, {
      on_stdout = function(line)
        require("spring-tools.core.backend").ProcessManager:extract_port(proj, line)
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
          local out = {}
          for i = start, #log_lines do table.insert(out, log_lines[i]) end
          local cause = M.extract_cause(out)
          table.insert(out, "")
          table.insert(out, exit_code == 0 and "Process exited cleanly" or "Process exited with code " .. exit_code)
          local final = {}
          for _, l in ipairs(cause) do table.insert(final, l) end
          if #cause > 0 then table.insert(final, '═' .. '═' .. '═' .. " Full output " .. '═' .. '═' .. '═') end
          for _, l in ipairs(out) do table.insert(final, l) end
          if output.win and vim.api.nvim_win_is_valid(output.win) then
            output.show(final, proj.name .. " (exit " .. exit_code .. ")", { footer = true })
          end
          if exit_code ~= 0 and exit_code ~= 143 then
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

  local function save_and_run(input)
    if input == "" then return end
    if default_str and input ~= default_str then
      recent[#recent + 1] = input
      if #recent > 10 then table.remove(recent, 1) end
      if not utils.cache.data then utils.cache.data = {} end
      utils.cache.data[cache_key] = recent
      utils.mark_dirty()
      utils.save_cache()
    end
    run_cmd(vim.split(input, "%s+"))
  end

  local function do_restart()
    output.show({ "Restarting " .. proj.name .. "..." }, proj.name)
    require("spring-tools.core.backend").ProcessManager:restart(proj, {
      on_stdout = function(line)
        require("spring-tools.core.backend").ProcessManager:extract_port(proj, line)
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
          local start = math.max(1, #log_lines - 100)
          local out = {}
          for i = start, #log_lines do table.insert(out, log_lines[i]) end
          local cause = M.extract_cause(out)
          table.insert(out, "")
          table.insert(out, exit_code == 0 and "Restarted successfully" or "Restart failed with code " .. exit_code)
          local final = {}
          for _, l in ipairs(cause) do table.insert(final, l) end
          if #cause > 0 then table.insert(final, '═' .. '═' .. '═' .. " Full output " .. '═' .. '═' .. '═') end
          for _, l in ipairs(out) do table.insert(final, l) end
          if output.win and vim.api.nvim_win_is_valid(output.win) then
            output.show(final, proj.name .. (exit_code == 0 and "" or " (exit " .. exit_code .. ")"), { footer = true })
          end
          if exit_code ~= 0 and exit_code ~= 143 then
            utils.notify(proj.name .. " restart failed", vim.log.levels.ERROR)
          end
          sidebar.refresh()
        end)
      end,
    })
  end

  local menu = {}

  local function has_docker_compose()
    local ws = state.get_workspace_root()
    if not ws then return nil end
    if vim.fn.filereadable(ws .. "/docker-compose.yml") == 1 then return ws .. "/docker-compose.yml" end
    if vim.fn.filereadable(ws .. "/docker-compose.yaml") == 1 then return ws .. "/docker-compose.yaml" end
    return nil
  end
  local docker_compose = has_docker_compose()
  local has_dockerfile = vim.fn.filereadable(proj.root .. "/Dockerfile") == 1

  if item.status ~= "running" then
    local run_items = {}
    if default_str then
      run_items[#run_items + 1] = { label = "  " .. default_str, action = function() save_and_run(default_str) end }
    end
    if #recent > 0 then
      local seen = {}
      for i = #recent, 1, -1 do
        local cmd = recent[i]
        if not seen[cmd] then
          seen[cmd] = true
          run_items[#run_items + 1] = { label = "  " .. cmd, action = function() M._run_or_delete(proj, cmd, save_and_run) end }
        end
      end
    end
    menu[#menu + 1] = { label = " Recent & default (" .. #run_items .. ")", submenu = run_items }

    local common_items = {}
    if build_type == "maven" then
      for _, cmd in ipairs({
        "mvn clean compile", "mvn test", "mvn package -DskipTests", "mvn clean install", "mvn verify", "mvn clean",
      }) do
        common_items[#common_items + 1] = { label = "  " .. cmd, action = function() save_and_run(cmd) end }
      end
      local plugin_goals = build.get_plugin_goals(proj.root)
      for _, goal in ipairs(plugin_goals) do
        if not goal:match(":$") then
          common_items[#common_items + 1] = { label = "  mvn " .. goal, action = function() save_and_run("mvn " .. goal) end }
        end
      end
    else
      for _, cmd in ipairs({
        "gradle build", "gradle test", "gradle clean build", "gradle bootRun", "gradle dependencies",
        "gradle clean", "gradle compileJava", "gradle check", "gradle assemble", "gradle bootJar",
        "gradle bootRun --debug", "gradle bootRun --args='--server.port=9090'",
      }) do
        common_items[#common_items + 1] = { label = "  " .. cmd, action = function() save_and_run(cmd) end }
      end
      local gradle_tasks = build.get_gradle_tasks(proj.root)
      for _, task in ipairs(gradle_tasks) do
        common_items[#common_items + 1] = { label = "  gradle " .. task, action = function() save_and_run("gradle " .. task) end }
      end
    end
    if docker_compose or has_dockerfile then
      local docker_items = {}
      if has_dockerfile then
        docker_items[#docker_items + 1] = { label = "  docker build -t " .. proj.name .. " .", action = function() save_and_run("docker build -t " .. proj.name .. " .") end }
      end
      if docker_compose then
        docker_items[#docker_items + 1] = { label = "  docker-compose up", action = function() save_and_run("docker-compose -f " .. docker_compose .. " up") end }
        docker_items[#docker_items + 1] = { label = "  docker-compose down", action = function() save_and_run("docker-compose -f " .. docker_compose .. " down") end }
      end
      docker_items[#docker_items + 1] = { label = "  docker ps", action = function() save_and_run("docker ps") end }
      docker_items[#docker_items + 1] = { label = "  docker logs " .. proj.name, action = function() save_and_run("docker logs -f " .. proj.name) end }
      menu[#menu + 1] = { label = " Docker (" .. #docker_items .. ")", submenu = docker_items }
    end
    menu[#menu + 1] = { label = " Common commands (" .. #common_items .. ")", submenu = common_items }
    menu[#menu + 1] = { label = "  Custom run...", action = function()
      M._show_command_input(proj, "", function(input)
        save_and_run(input)
      end)
    end }
  end

  if item.status == "failed" then
    menu[#menu + 1] = { label = "  View logs", action = function() M.show_logs(proj) end }
  end
  if item.status == "running" then
    menu[#menu + 1] = { label = "  Stop", action = function() require("spring-tools.core.backend").ProcessManager:stop(proj); sidebar.refresh() end }
    menu[#menu + 1] = { label = "  View logs", action = function() M.show_logs(proj) end }
    menu[#menu + 1] = { label = "  Restart", action = do_restart }
    if docker_compose then
      local docker_items = {}
      docker_items[#docker_items + 1] = { label = "  docker ps", action = function() save_and_run("docker ps") end }
      docker_items[#docker_items + 1] = { label = "  docker logs " .. proj.name, action = function() save_and_run("docker logs -f " .. proj.name) end }
      docker_items[#docker_items + 1] = { label = "  docker-compose logs", action = function() save_and_run("docker-compose -f " .. docker_compose .. " logs -f") end }
      menu[#menu + 1] = { label = " Docker (" .. #docker_items .. ")", submenu = docker_items }
    end
    local ar_on = M._auto_restart[proj.root]
    menu[#menu + 1] = { label = (ar_on and "↻  Auto-restart: on" or "↻  Auto-restart: off"), action = function()
      M._auto_restart[proj.root] = not ar_on
      if not utils.cache.data then utils.cache.data = {} end
      utils.cache.data["auto_restart:" .. proj.root] = not ar_on
      utils.mark_dirty()
      sidebar.refresh()
    end }
    if ar_on then
      local cl_on = M._auto_clean[proj.root]
      menu[#menu + 1] = { label = (cl_on and "  Clean rebuild: on" or "  Clean rebuild: off"), action = function()
        M._auto_clean[proj.root] = not cl_on
        if not utils.cache.data then utils.cache.data = {} end
        utils.cache.data["auto_clean:" .. proj.root] = not cl_on
        utils.mark_dirty()
        sidebar.refresh()
      end }
    end
  end
  if item.status == "failed" then
    menu[#menu + 1] = { label = "  Restart", action = do_restart }
  end
  menu[#menu + 1] = { label = "  Open config", action = function() M._open_config_wrapped(proj, menu) end }

  M.show_actions(menu)
end

function M._open_config_wrapped(proj, back_menu)
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
    M.show_actions(back_menu)
    return
  end
  vim.ui.select(found, { prompt = "Open config:" }, function(path)
    if not path then
      M.show_actions(back_menu)
      return
    end
    sidebar.open_in_main(path, 1)
  end)
end

function M._run_or_delete(proj, cmd, run_fn)
  local actions = {
    { label = "  Run", action = function() run_fn(cmd) end },
    { label = "  Delete from history", action = function()
      local cache_key = "recent_cmds:" .. proj.root
      local recent = utils.cache.data[cache_key]
      if recent then
        for i = #recent, 1, -1 do
          if recent[i] == cmd then table.remove(recent, i) end
        end
        utils.cache.data[cache_key] = recent
        utils.mark_dirty()
        utils.save_cache()
      end
      utils.notify("Deleted: " .. cmd)
    end },
  }
  vim.ui.select(actions, {
    prompt = cmd,
    format_item = function(a) return a.label end,
  }, function(choice)
    if choice and choice.action then choice.action() end
  end)
end

function M.show_actions(actions)
  local parent = nil
  local function show(items, on_back)
    vim.ui.select(items, {
      prompt = "Select action:",
      format_item = function(item) return item.label end,
    }, function(choice)
      if not choice then
        if on_back then show(on_back[1], on_back[2]) end
        return
      end
      if choice.submenu then
        show(choice.submenu, { items, on_back })
      elseif choice.action then
        choice.action()
      end
    end)
  end
  show(actions)
end

function M.auto_restart(file_path)
  if not config.options.auto_restart.enable then return end

  -- Skip test files
  if config.options.auto_restart.skip_tests ~= false then
    if file_path:find("/src/test/") or file_path:find("\\src\\test\\") then return end
  end

  local delay = config.options.auto_restart.delay or 500
  local cooldown = config.options.auto_restart.cooldown or 3000
  local proj = project.find_project_for_file(file_path)
  if not proj then return end
  if not M._auto_restart[proj.root] then return end

  -- Cooldown check
  if M._last_restart[proj.root] then
    if os.time() * 1000 - M._last_restart[proj.root] < cooldown then return end
  end

  local be = project.get_backend_for_project(proj)
  if not be then return end
  local proc = require("spring-tools.core.backend").ProcessManager.get(nil, proj)
  if not proc or proc.status ~= "running" then return end

  -- Cancel previous timer for this project
  if M._restart_timers[proj.root] then
    vim.fn.timer_stop(M._restart_timers[proj.root])
  end

  local changed_file = vim.fn.fnamemodify(file_path, ":t")

  M._restart_timers[proj.root] = vim.fn.timer_start(delay, function()
    M._restart_timers[proj.root] = nil
    vim.schedule(function()
      local output_was_open = output.win and vim.api.nvim_win_is_valid(output.win)
      if not output_was_open then output._suppress_open = true end
      utils.notify("Auto-restarting " .. proj.name .. "...", vim.log.levels.INFO)
      local restart_done = false
      local per_clean = M._auto_clean[proj.root]
      local do_clean = (per_clean ~= nil) and per_clean or config.options.auto_restart.clean

      local function do_restart()
        require("spring-tools.core.backend").ProcessManager:restart(proj, {
        on_stdout = function(line)
          require("spring-tools.core.backend").ProcessManager:extract_port(proj, line)
          local logs = be:get_logs(proj)
          if #logs > 0 then
            output.store_logs(logs)
            if output.win and vim.api.nvim_win_is_valid(output.win) then
              vim.schedule(function()
                output.update_from_logs(logs, proj.name)
              end)
            end
          end
          if not restart_done and line:find("Started .+ in %d+") then
            restart_done = true
            local started_time = line:match(" in ([%d.]+) seconds?")
            vim.schedule(function()
              local proc = require("spring-tools.core.backend").ProcessManager.get(nil, proj)
              local port_str = (proc and proc.port) and (":" .. proc.port) or ""
              M._last_restart[proj.root] = os.time() * 1000
              output._suppress_open = false
              if output.buf and vim.api.nvim_buf_is_valid(output.buf) then
                output.append("")
                output.append("✓  Auto-restarted — " .. proj.name .. " " .. port_str .. " · " .. (started_time and (started_time .. "s") or "ready") .. " · " .. changed_file)
              end
              sidebar.refresh()
            end)
          end
        end,
        on_exit = function(exit_code)
          vim.schedule(function()
            output._suppress_open = false
            if exit_code ~= 0 and exit_code ~= 143 then
              local log_lines = be:get_logs(proj)
              local start = math.max(1, #log_lines - 100)
              local out = {}
              for i = start, #log_lines do table.insert(out, log_lines[i]) end
              local cause = M.extract_cause(out)
              table.insert(out, "")
              table.insert(out, "Auto-restart failed with code " .. exit_code)
              local final = {}
              for _, l in ipairs(cause) do table.insert(final, l) end
              if #cause > 0 then table.insert(final, "═══ Full output ═══") end
              for _, l in ipairs(out) do table.insert(final, l) end
              if output.win and vim.api.nvim_win_is_valid(output.win) then
                output.show(final, proj.name .. " (exit " .. exit_code .. ")", { footer = true })
              end
              utils.notify(proj.name .. " auto-restart failed (exit " .. exit_code .. ")", vim.log.levels.ERROR)
            elseif exit_code == 0 then
              utils.notify(proj.name .. " auto-restarted successfully", vim.log.levels.INFO)
            end
            sidebar.refresh()
          end)
        end,
      })
      end

      if do_clean then
        local proc = require("spring-tools.core.backend").ProcessManager.get(nil, proj)
        if proc then require("spring-tools.core.backend").ProcessManager.stop(nil, proj) end
        local build_type = proj.build_type or "maven"
        local clean_cmd = build_type == "maven" and { "mvn", "clean" } or { "gradle", "clean" }
        vim.fn.jobstart(clean_cmd, {
          cwd = proj.root,
          on_exit = function()
            vim.schedule(function()
              do_restart()
            end)
          end,
        })
      else
        do_restart()
      end
    end)
  end)
end

function M._omni(findstart, base)
  local bufnr = vim.api.nvim_get_current_buf()
  local data = M._omni_data and M._omni_data[bufnr]
  if not data then return {} end

  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local start = col
    while start > 0 and line:sub(start, start):match("[%w:_%-.@/]") do
      start = start - 1
    end
    if start == col then return col end
    return start
  end

  local results = {}
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before = line:sub(1, col)
  local words = vim.split(before, "%s+", { trimempty = true })
  local first = words[1] or ""

  if base:match("^-D") then
    local props = first:match("^gradle") and data.gprops or data.dprops
    for _, p in ipairs(props) do
      if p:lower():find(base:lower(), 1, true) then
        table.insert(results, p)
      end
    end
    return results
  end

  if base:find(":", 1, true) then
    for _, g in ipairs(data.goals) do
      if g:lower():find(base:lower(), 1, true) then
        table.insert(results, g)
      end
    end
    return results
  end

  if not first:match("^mv") and not first:match("^gradle") and not first:match("^docker") then
    for _, c in ipairs({ "mvn", "mvnw", "mvnDebug", "gradle", "gradlew", "docker", "docker-compose" }) do
      if c:lower():find(base:lower(), 1, true) then
        table.insert(results, c)
      end
    end
    for _, g in ipairs(data.goals) do
      if g:lower():find(base:lower(), 1, true) then
        table.insert(results, g)
      end
    end
    for _, p in ipairs(data.phases) do
      if p:lower():find(base:lower(), 1, true) then
        table.insert(results, p)
      end
    end
    return results
  end

  if first:match("^docker$") then
    for _, cmd in ipairs({ "build", "run", "ps", "logs", "exec", "stop", "start", "restart", "pull", "push", "images", "rm", "rmi", "network", "volume", "compose", "system", "inspect" }) do
      if cmd:lower():find(base:lower(), 1, true) then
        table.insert(results, cmd)
      end
    end
    return results
  end

  if first:match("^docker%-compose$") then
    for _, cmd in ipairs({ "up", "down", "build", "logs", "ps", "restart", "pull", "exec", "run", "start", "stop", "config", "top" }) do
      if cmd:lower():find(base:lower(), 1, true) then
        table.insert(results, cmd)
      end
    end
    return results
  end

  if first:match("^mv") then
    for _, p in ipairs(data.phases) do
      if p:lower():find(base:lower(), 1, true) then
        table.insert(results, p)
      end
    end
    for _, g in ipairs(data.goals) do
      if g:lower():find(base:lower(), 1, true) then
        table.insert(results, g)
      end
    end
    return results
  end

  if first:match("^gradle") then
    for _, t in ipairs(data.gtasks) do
      if t:lower():find(base:lower(), 1, true) then
        table.insert(results, t)
      end
    end
    return results
  end

  return results
end

function M._show_command_input(proj, default_text, on_submit)
  local km_input = config.options.command_input.keymaps
  local width = math.min(80, vim.o.columns - 4)
  local height = 1
  local pos = config.options.command_input and config.options.command_input.position or "center"
  local row
  if pos == "top" then
    row = 1
  elseif pos == "bottom" then
    row = vim.o.lines - 4
  else
    row = math.floor((vim.o.lines - 3) / 2)
  end
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local saved_buftype = vim.bo[buf].buftype
  local saved_complete = vim.bo[buf].complete
  local saved_omnifunc = vim.bo[buf].omnifunc
  vim.bo[buf].buftype = "prompt"
  pcall(vim.fn.prompt_setprompt, buf, "")
  vim.bo[buf].complete = ""
  vim.b[buf].cmp_enabled = false
  vim.b[buf].cmp_disable = true
  vim.b[buf].blink_cmp_disable = true

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Run command ",
    title_pos = "center",
  })
  vim.wo[win].winfixbuf = true

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default_text })

  local closing = false

  local function cleanup()
    closing = true
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end

  local plugin_goals = build.get_plugin_goals(proj.root)

  M._omni_data = M._omni_data or {}
  M._omni_data[buf] = { goals = plugin_goals, phases = build.phases, dprops = build.d_properties, gprops = build.gradle_d_properties, gtasks = build.gradle_tasks,
    saved_complete = saved_complete, saved_omnifunc = saved_omnifunc, saved_buftype = saved_buftype }

  vim.bo[buf].omnifunc = "SpringToolsOmni"
  if not M._omni_reg then
    M._omni_reg = true
    pcall(vim.cmd, [[
      function! SpringToolsOmni(findstart, base)
        return luaeval("require('spring-tools.ui.views.dashboard')._omni(_A[1], _A[2])", [a:findstart, a:base])
      endfunction
    ]])
  end

  local function restore_buf()
    local d = M._omni_data[buf]
    if d then
      pcall(function() vim.bo[buf].buftype = d.saved_buftype end)
      pcall(function() vim.bo[buf].complete = d.saved_complete end)
      pcall(function() vim.bo[buf].omnifunc = d.saved_omnifunc end)
      vim.b[buf].cmp_enabled = nil
      vim.b[buf].cmp_disable = nil
      vim.b[buf].blink_cmp_disable = nil
    end
    M._omni_data[buf] = nil
  end

  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = buf,
    once = true,
    callback = restore_buf,
  })

  vim.keymap.set("i", "<CR>", function()
    if vim.fn.pumvisible() == 1 then
      local info = vim.fn.complete_info()
      local items = info and info.items or {}
      local selected = info and info.selected or 0
      if selected >= 0 and selected < #items then
        local word = items[selected + 1].word
        if word then
          local line = vim.api.nvim_get_current_line()
          local col = vim.api.nvim_win_get_cursor(0)[2]
          local start = col
          while start > 0 and line:sub(start, start):match("[%w:_%-.@/]") do
            start = start - 1
          end
          local new_line = line:sub(1, start) .. word
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, { new_line })
          vim.api.nvim_win_set_cursor(win, { 1, start + #word })
        end
      end
    end
    local text = vim.api.nvim_get_current_line()
    cleanup()
    on_submit(text)
  end, { buffer = buf, silent = true })

  vim.keymap.set("i", km_input.complete, function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "n")
    else
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })

  vim.keymap.set("i", km_input.trigger, function()
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n")
  end, { buffer = buf, silent = true })

  vim.keymap.set("i", km_input.popup_next, function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })

  vim.keymap.set("i", km_input.popup_prev, function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-p>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })

  vim.keymap.set("n", km_input.close, cleanup, { buffer = buf, silent = true })
  vim.keymap.set("n", km_input.close_alt, cleanup, { buffer = buf, silent = true })
  vim.keymap.set("n", "<CR>", function()
    local text = vim.api.nvim_get_current_line()
    cleanup()
    on_submit(text)
  end, { buffer = buf, silent = true })
  -- <C-w> intentionally left unmapped to preserve i_<C-w> word-delete in prompt buffers
  vim.keymap.set("n", "<C-h>", "<Nop>", { buffer = buf })
  vim.keymap.set("n", "<C-j>", "<Nop>", { buffer = buf })
  vim.keymap.set("n", "<C-k>", "<Nop>", { buffer = buf })
  vim.keymap.set("n", "<C-l>", "<Nop>", { buffer = buf })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = function()
      if closing then return end
      vim.schedule(function()
        pcall(vim.api.nvim_win_close, win, true)
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end)
    end,
  })

  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = buf,
    callback = function()
      if vim.fn.pumvisible() == 1 then return end
      local col = vim.api.nvim_win_get_cursor(0)[2]
      if col < 1 then return end
      local line = vim.api.nvim_get_current_line()
      local char = line:sub(col + 1, col + 1)
      if not char:match("[%w:_%-.@/]") then return end
      vim.schedule(function()
        if vim.fn.mode() ~= "i" then return end
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n")
      end)
    end,
  })

  vim.bo[buf].filetype = "springtools-cmd-input"

  vim.cmd("startinsert!")
  vim.api.nvim_win_set_cursor(win, { 1, #default_text })
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
  output.show(final, title, { footer = true })
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
