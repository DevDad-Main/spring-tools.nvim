local config = require("spring-tools.config")
local utils = require("spring-tools.utils")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")
local jp = require("spring-tools.java_parser")

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("SpringBoot", function()
    M.open_sidebar("dashboard")
  end, { desc = "Open Spring Boot Dashboard" })

  vim.api.nvim_create_user_command("SpringBeans", function()
    M.open_sidebar("beans")
  end, { desc = "Open Spring Bean Explorer" })

  vim.api.nvim_create_user_command("SpringEndpoints", function()
    M.open_sidebar("endpoints")
  end, { desc = "Open REST Endpoint Explorer" })

  vim.api.nvim_create_user_command("SpringTest", function()
    M.open_sidebar("tests")
  end, { desc = "Open Java Test Runner" })

  vim.api.nvim_create_user_command("SpringConfig", function()
    M.open_sidebar("config")
  end, { desc = "Open Spring Configuration Explorer" })

  vim.api.nvim_create_user_command("SpringTools", function()
    M.open_sidebar("dashboard")
  end, { desc = "Open Spring Tools" })

  vim.api.nvim_create_user_command("SpringInit", function()
    M.open_sidebar("initializer")
  end, { desc = "Spring Initializr — generate a new Spring Boot project" })

  vim.api.nvim_create_user_command("SpringRefresh", function()
    require("spring-tools.utils").invalidate_cache()
    local build = require("spring-tools.build_completion")
    build.invalidate_cache()
    local project = require("spring-tools.project")
    project._excluded = {}
    sidebar.refresh()
    local state = require("spring-tools.core.state")
    local maven_roots = {}
    local gradle_roots = {}
    for _, proj in ipairs(state.get_projects()) do
      if proj.build_type == "maven" then
        maven_roots[#maven_roots + 1] = proj.root
      elseif proj.build_type == "gradle" then
        gradle_roots[#gradle_roots + 1] = proj.root
      end
    end
    if #maven_roots > 0 then
      build.fetch_dynamic_goals(maven_roots)
    end
    if #gradle_roots > 0 then
      build.fetch_gradle_tasks(gradle_roots)
    end
    utils.notify("Spring Tools indexes refreshed")
  end, { desc = "Refresh all Spring Tools indexes" })

  vim.api.nvim_create_user_command("SpringClearCache", function()
    utils.invalidate_cache()
    require("spring-tools.build_completion").invalidate_cache()
    require("spring-tools.project")._excluded = {}
    os.remove(vim.fn.stdpath("data") .. "/spring-tools/projects.json")
    require("spring-tools.project").projects = {}
    vim.schedule(function()
      require("spring-tools.ui.sidebar").refresh()
    end)
    utils.notify("Spring Tools caches cleared — sidebar refreshed")
  end, { desc = "Clear all Spring Tools caches (project cache + dynamic goals)" })

  vim.api.nvim_create_user_command("SpringTestClass", function()
    M.run_current_test("class")
  end, { desc = "Run current test class" })

  vim.api.nvim_create_user_command("SpringTestMethod", function()
    M.run_current_test("method")
  end, { desc = "Run current test method" })

  vim.api.nvim_create_user_command("SpringConfigSearch", function(opts)
    local query = opts.args
    if query == "" then
      utils.notify("Usage: SpringConfigSearch <query>", vim.log.levels.WARN)
      return
    end
    local config_mod = require("spring-tools.config_explorer")
    config_mod.build_index()
    local results = {}
    for _, prop in ipairs(config_mod.properties) do
      if prop.key:lower():find(query:lower(), 1, true) or
         (prop.value and prop.value:lower():find(query:lower(), 1, true)) then
        table.insert(results, prop)
      end
    end
    if #results == 0 then
      utils.notify("No matching properties found for: " .. query, vim.log.levels.INFO)
      return
    end
    utils.pick(results, {
      prompt_title = " Search Results (" .. #results .. ") ",
      entry_maker = function(prop)
        return { value = prop, display = prop.key .. " = " .. prop.value .. "  (" .. prop.source .. ")", ordinal = prop.key }
      end,
    }, function(prop)
      if prop.file then vim.cmd("edit " .. prop.file) end
    end)
  end, { nargs = 1, desc = "Search configuration properties" })
  vim.api.nvim_create_user_command("SpringConfigDiff", function()
    require("spring-tools.config_diff").open()
  end, { desc = "Diff two config files side-by-side" })
  vim.api.nvim_create_user_command("SpringSearch", function()
    require("spring-tools.search").open()
  end, { desc = "Search all beans, endpoints, tests, and config properties" })
  vim.api.nvim_create_user_command("SpringCommands", function()
    require("spring-tools.command_history").open()
  end, { desc = "Browse, re-run, and manage saved custom commands" })
end

function M.open_sidebar(view)
  require("spring-tools.ui.components").setup_highlights()
  require("spring-tools.ui.views")
  if sidebar.win and vim.api.nvim_win_is_valid(sidebar.win) then
    sidebar.close()
    return
  end
  if view then sidebar.switch_view(view) end
  sidebar.open()
end

function M.setup_keymaps()
  if not config.options.keymaps.enable then return end
  local km = config.options.keymaps
  if km.boot and km.boot ~= "" then
    vim.keymap.set("n", km.boot, function() M.open_sidebar("dashboard") end, { desc = "Spring Boot Dashboard" })
  end
  if km.beans and km.beans ~= "" then
    vim.keymap.set("n", km.beans, function() M.open_sidebar("beans") end, { desc = "Spring Bean Explorer" })
  end
  if km.endpoints and km.endpoints ~= "" then
    vim.keymap.set("n", km.endpoints, function() M.open_sidebar("endpoints") end, { desc = "Spring Endpoint Explorer" })
  end
  if km.tests and km.tests ~= "" then
    vim.keymap.set("n", km.tests, function() M.open_sidebar("tests") end, { desc = "Spring Test Runner" })
  end
  if km.config and km.config ~= "" then
    vim.keymap.set("n", km.config, function() M.open_sidebar("config") end, { desc = "Spring Config Explorer" })
  end
  if km.init and km.init ~= "" then
    vim.keymap.set("n", km.init, function() M.open_sidebar("initializer") end, { desc = "Spring Initializr" })
  end
  if km.search and km.search ~= "" then
    vim.keymap.set("n", km.search, function() require("spring-tools.search").open() end, { desc = "Spring Search" })
  end
end

function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup("SpringTools", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = { "*.java", "pom.xml", "build.gradle", "build.gradle.kts" },
    callback = function()
      if require("spring-tools.config").options.auto_refresh then
        require("spring-tools.utils").mark_dirty()
        sidebar.refresh()
      end
      require("spring-tools.ui.views.dashboard").auto_restart(vim.fn.expand("<afile>:p"))
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      require("spring-tools.utils").save_cache()
    end,
  })
end

function M.run_current_test(type)
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if not file:match("%.java$") then
    utils.notify("Not a Java file", vim.log.levels.WARN)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local proj_mod = require("spring-tools.project")

  local parsed = jp.parse_lines(content)
  if not parsed then
    utils.notify("Could not parse Java file", vim.log.levels.WARN)
    return
  end

  local class_name = jp.find_class_name(parsed)
  local package_name = jp.find_package_name(parsed)
  local method_name = nil

  if type == "method" then
    local method = jp.get_test_method_at_or_after(parsed, cursor[1])
    if method then
      method_name = method.name
    end
  end

  parsed:cleanup()

  if not class_name then
    utils.notify("Could not determine class name", vim.log.levels.WARN)
    return
  end

  local full_class = package_name and (package_name .. "." .. class_name) or class_name
  local proj = proj_mod.get_active_project()
  if not proj then
    utils.notify("No project found", vim.log.levels.WARN)
    return
  end

  local be = proj_mod.get_backend_for_project(proj)
  if not be then return end

  local cmd
  if type == "method" and method_name then
    cmd = be:get_test_command(proj, full_class, method_name)
    utils.notify("Running test: " .. full_class .. "#" .. method_name)
  else
    cmd = be:get_test_command(proj, full_class, nil)
    utils.notify("Running tests: " .. full_class)
  end

  if not cmd then return end

  output.open()
  local tests_view = require("spring-tools.ui.views.tests")
  tests_view.run_test(cmd)
end

return M