local config = require("spring-tools.config")
local project = require("spring-tools.project")
local backend = require("spring-tools.backends")
local state = require("spring-tools.core.state")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")
local utils = require("spring-tools.utils")
local mvn = require("spring-tools.mvn_completion")

local M = {}

M.title = "Dashboard"

function M.header()
  local count = #state.get_projects()
  local parts = { "Spring Tools \u{b7} " .. count .. " project" .. (count ~= 1 and "s" or "") }
  return { { table.concat(parts, ""), "SpringToolsHeader" } }
end

M.items = {}

function M:load_items()
  mvn.invalidate_cache()
  state.set_projects(project.detect_projects())
  local projs = state.get_projects()
  local active = project.get_active_project()
  M.items = {}
  local maven_roots = {}
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
    if proj.build_type == "maven" then
      maven_roots[#maven_roots + 1] = proj.root
    end
  end
  if #maven_roots > 0 then
    mvn.fetch_dynamic_goals(maven_roots)
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
    local cache_key = "recent_cmds:" .. proj.root
    local recent = (utils.cache.data and utils.cache.data[cache_key]) or {}
    local suggestions = { default_str }
    if #recent > 0 then
      table.insert(suggestions, "--- recent ---")
      for _, cmd in ipairs(recent) do suggestions[#suggestions + 1] = cmd end
      table.insert(suggestions, "--- common ---")
    end
    if build_type == "maven" then
      for _, cmd in ipairs({
        "mvn clean compile",
        "mvn test",
        "mvn package -DskipTests",
        "mvn clean install",
        "mvn verify",
        "mvn clean",
      }) do suggestions[#suggestions + 1] = cmd end
      local plugin_goals = mvn.get_plugin_goals(proj.root)
      for _, goal in ipairs(plugin_goals) do
        if not goal:match(":$") then
          suggestions[#suggestions + 1] = "mvn " .. goal
        end
      end
    else
      for _, cmd in ipairs({
        "gradle build",
        "gradle test",
        "gradle clean build",
        "gradle bootRun",
        "gradle dependencies",
        "gradle clean",
        "gradle compileJava",
        "gradle check",
        "gradle assemble",
        "gradle bootJar",
        "gradle bootRun --debug",
        "gradle bootRun --args='--server.port=9090'",
      }) do suggestions[#suggestions + 1] = cmd end
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

    local function save_and_run(input)
      if input == "" then return end
      if input ~= default_str then
        recent[#recent + 1] = input
        if #recent > 10 then table.remove(recent, 1) end
        if not utils.cache.data then utils.cache.data = {} end
        utils.cache.data[cache_key] = recent
        utils.mark_dirty()
        utils.save_cache()
      end
      run_cmd(vim.split(input, "%s+"))
    end

    vim.ui.select(suggestions, { prompt = "Select a command:" }, function(choice)
      if not choice then return end
      if choice:match("^---") then return end
      if choice == "Custom..." then
        M._show_command_input(proj, "", function(input)
          save_and_run(input)
        end)
      else
        save_and_run(choice)
      end
    end)
  end
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

  if not first:match("^mv") and not first:match("^gradle") then
    for _, c in ipairs({ "mvn", "mvnw", "mvnDebug", "gradle", "gradlew" }) do
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

  local plugin_goals = mvn.get_plugin_goals(proj.root)

  M._omni_data = M._omni_data or {}
  M._omni_data[buf] = { goals = plugin_goals, phases = mvn.phases, dprops = mvn.d_properties, gprops = mvn.gradle_d_properties, gtasks = mvn.gradle_tasks,
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

  vim.keymap.set("i", "<Tab>", function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "n")
    else
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })

  vim.keymap.set("i", "<C-j>", function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })

  vim.keymap.set("i", "<C-k>", function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-p>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })

  vim.keymap.set("n", "<Esc>", cleanup, { buffer = buf, silent = true })
  vim.keymap.set("n", "q", cleanup, { buffer = buf, silent = true })
  vim.keymap.set("n", "<CR>", function()
    local text = vim.api.nvim_get_current_line()
    cleanup()
    on_submit(text)
  end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-w>", "<Nop>", { buffer = buf })
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
      if col < 2 then return end
      local line = vim.api.nvim_get_current_line()
      local char = line:sub(col, col)
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
