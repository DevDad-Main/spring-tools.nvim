local project = require("spring-tools.project")
local ui = require("spring-tools.ui")
local utils = require("spring-tools.utils")
local config = require("spring-tools.config")
local jp = require("spring-tools.java_parser")

local M = {}

M.results = {}
M.current_job = nil
M.class_results = {}
M.method_results = {}

local function parse_surefire_per_class(output)
  local classes = {}
  for line in output:gmatch("([^\n]+)") do
    local run, failures, errors, skipped, full_class = line:match("Tests run: (%d+), Failures: (%d+), Errors: (%d+), Skipped: (%d+).*in (%S+)")
    if not run then
      run, failures, errors, skipped, full_class = line:match("%[INFO%]%s*Tests run: (%d+), Failures: (%d+), Errors: (%d+), Skipped: (%d+).*in (%S+)")
    end
    if run then
      local simple_name = full_class:match("([%w]+)$")
      local failed = tonumber(failures) + tonumber(errors)
      classes[simple_name] = {
        passed = tonumber(run) - failed - tonumber(skipped),
        failed = failed,
        skipped = tonumber(skipped),
        total = tonumber(run),
      }
    end
  end
  return classes
end

local function parse_surefire_xml(proj_root)
  local method_results = {}
  local reports_dir = proj_root .. "/target/surefire-reports"
  local ok, files = pcall(vim.fn.readdir, reports_dir)
  if not ok or not files then return {} end
  for _, file in ipairs(files) do
    if file:match("%.xml$") then
      local ok2, lines = pcall(vim.fn.readfile, reports_dir .. "/" .. file)
      if ok2 and lines then
        local content = table.concat(lines, "\n")
        local classname = content:match('<testsuite%s+name="([^"]+)"')
          or content:match('classname="([^"]+)"')
        if classname then
          local simple_class = classname:match("([%w]+)$")
          method_results[simple_class] = method_results[simple_class] or {}
          for tc in content:gmatch('<testcase(.-)</testcase>') do
            local method = tc:match('name="([^"]+)"')
            if method then
              local failed = tc:find('<failure') and true or false
              method_results[simple_class][method] = failed and "failed" or "passed"
            end
          end
          for tc in content:gmatch('<testcase(.-)/>') do
            local method = tc:match('name="([^"]+)"')
            if method and not method_results[simple_class][method] then
              method_results[simple_class][method] = "passed"
            end
          end
        end
      end
    end
  end
  return method_results
end

local function parse_gradle_per_class(output)
  local classes = {}
  for line in output:gmatch("([^\n]+)") do
    local status, full_name = line:match("^%s*%w+%s+(%w+)%s+(%S+)")
    if status then
      local simple_name = full_name:match("^(.+)%.[^%.]+$") or full_name
      if not classes[simple_name] then
        classes[simple_name] = { passed = 0, failed = 0, skipped = 0, total = 0 }
      end
      local c = classes[simple_name]
      c.total = c.total + 1
      if status == "PASSED" then c.passed = c.passed + 1
      elseif status == "FAILED" then c.failed = c.failed + 1
      elseif status == "SKIPPED" then c.skipped = c.skipped + 1 end
    end
  end
  return classes
end

local function parse_gradle_per_method(output)
  local method_results = {}
  for line in output:gmatch("([^\n]+)") do
    local full_class, method_name, status = line:match("^%s*(%S+)%s+>%s+(%S+)%s+(%w+)")
    if full_class and method_name and status then
      local simple_class = full_class:match("([%w]+)$")
      if simple_class then
        method_results[simple_class] = method_results[simple_class] or {}
        if status == "PASSED" then
          method_results[simple_class][method_name] = "passed"
        elseif status == "FAILED" then
          method_results[simple_class][method_name] = "failed"
        end
      end
    end
  end
  return method_results
end

local function parse_junit5_output(output)
  local results = {
    tests = {},
    passed = 0,
    failed = 0,
    skipped = 0,
    duration = 0,
    stack_traces = {},
  }

  local tests_run = output:match("Tests run:%s*(%d+)")
  local failures = output:match("Failures:%s*(%d+)")
  local errors = output:match("Errors:%s*(%d+)")
  local skipped = output:match("Skipped:%s*(%d+)")
  local elapsed = output:match("Time elapsed:%s*([%d%.]+)%s*s")

  if not tests_run then
    tests_run = output:match("%[INFO%]%s*Tests%srun:%s*(%d+)")
  end

  results.duration = elapsed and (tonumber(elapsed) * 1000) or 0

  local failed_count = (tonumber(failures) or 0) + (tonumber(errors) or 0)
  results.failed = failed_count
  results.passed = (tonumber(tests_run) or 0) - failed_count - (tonumber(skipped) or 0)

  if results.failed > 0 then
    for line in output:gmatch("([^\n]+)") do
      if line:find("ERROR") or line:find("FAILURE") or line:find("AssertionError") or line:find("expected:") then
        table.insert(results.stack_traces, line)
      end
      local stack_file = line:match("%((%w+%.java:%d+)%)")
      if stack_file then
        table.insert(results.stack_traces, "  at " .. stack_file)
      end
    end
  end

  return results
end

local function parse_gradle_output(output)
  local results = {
    tests = {},
    passed = 0,
    failed = 0,
    skipped = 0,
    duration = 0,
    stack_traces = {},
  }

  local duration_match = output:match("Execution finished in ([%d%.]+)s")
  if duration_match then
    results.duration = tonumber(duration_match) * 1000
  end

  for line in output:gmatch("([^\n]+)") do
    local test_passed = line:match("^%s*%w+%s+PASSED%s+(%S+)")
    local test_failed = line:match("^%s*%w+%s+FAILED%s+(%S+)")
    local test_skipped = line:match("^%s*%w+%s+SKIPPED%s+(%S+)")

    if test_passed then
      results.passed = results.passed + 1
      table.insert(results.tests, { name = test_passed, status = "passed" })
    elseif test_failed then
      results.failed = results.failed + 1
      table.insert(results.tests, { name = test_failed, status = "failed" })
    elseif test_skipped then
      results.skipped = results.skipped + 1
      table.insert(results.tests, { name = test_skipped, status = "skipped" })
    end

    if line:find("expected:") or line:find("but was:") or line:find("AssertionError") then
      table.insert(results.stack_traces, line)
    end
  end

  return results
end

M._test_cache = {}

function M.invalidate_test_cache(project_root)
  if project_root then
    M._test_cache[project_root] = nil
    if utils.cache.data then
      utils.cache.data["test_index:" .. project_root] = nil
      utils.mark_dirty()
    end
  else
    M._test_cache = {}
  end
end

function M.find_test_methods(dir)
  dir = dir or vim.fn.getcwd()
  local project_root = utils.find_project_root(dir)
  if not project_root then return {} end

  if M._test_cache[project_root] then
    return M._test_cache[project_root]
  end

  local cache_key = "test_index:" .. project_root
  if utils.cache.data and utils.cache.data[cache_key] then
    local cached = utils.cache.data[cache_key]
    if cached.mtimes then
      local valid = true
      for file, mtime in pairs(cached.mtimes) do
        if utils.file_modified_since(file, mtime) then
          valid = false
          break
        end
      end
      if valid then
        M._test_cache[project_root] = cached.tests
        return cached.tests
      end
    end
  end

  local tests = {}
  local mtimes = {}
  local java_files = utils.find_java_files(project_root)

  for _, file in ipairs(java_files) do
    local mtime = vim.fn.getftime(file)
    local parsed = jp.parse_file(file)
    if not parsed then goto continue end

    local test_methods = jp.find_test_methods_in_file(parsed)
    if #test_methods == 0 then
      parsed:cleanup()
      goto continue
    end

    local class_name = jp.find_class_name(parsed)
    local package_name = jp.find_package_name(parsed)
    local full_class = package_name and (package_name .. "." .. class_name) or class_name

    local methods = {}
    for _, tm in ipairs(test_methods) do
      table.insert(methods, { name = tm.name, line = tm.line })
    end

    table.insert(tests, {
      class = class_name,
      full_class = full_class,
      file = file,
      package = package_name,
      methods = methods,
    })
    mtimes[file] = mtime

    parsed:cleanup()
    ::continue::
  end

  M._test_cache[project_root] = tests
  if not utils.cache.data then utils.cache.data = {} end
  utils.cache.data[cache_key] = { tests = tests, mtimes = mtimes }
  utils.mark_dirty()
  utils.save_cache()
  return tests
end

function M.run_test_class(test_class)
  local proj = project.get_active_project()
  if not proj then
    utils.notify("No project found", vim.log.levels.WARN)
    return
  end

  local cmd = project.get_test_command(proj, test_class, nil)
  if not cmd then return end

  utils.notify("Running tests: " .. test_class)
  M.run_test_process(cmd, proj.root)
end

function M.run_test_method(test_class, test_method)
  local proj = project.get_active_project()
  if not proj then
    utils.notify("No project found", vim.log.levels.WARN)
    return
  end

  local cmd = project.get_test_command(proj, test_class, test_method)
  if not cmd then return end

  utils.notify("Running test: " .. test_class .. "#" .. test_method)
  M.run_test_process(cmd, proj.root)
end

function M.run_all_tests()
  local proj = project.get_active_project()
  if not proj then
    utils.notify("No project found", vim.log.levels.WARN)
    return
  end

  local build = project.get_build_command(proj)
  if not build then return end
  local cmd = vim.deepcopy(build)
  table.insert(cmd, "test")

  utils.notify("Running all tests...")
  M.run_test_process(cmd, proj.root)
end

function M.run_test_process(cmd, cwd)
  local output_lines = {}

  M.current_job = utils.job_start(cmd, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(output_lines, line)
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(output_lines, line)
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        M.handle_test_results(output_lines, exit_code)
      end)
    end,
  })

  if M.current_job <= 0 then
    utils.notify("Failed to start test process", vim.log.levels.ERROR)
  end
end

function M.handle_test_results(output_lines, exit_code)
  M.method_results = {}
  local raw_output = table.concat(output_lines, "\n")
  local results
  local proj = project.get_active_project()

  if proj and proj.build_type == "gradle" then
    results = parse_gradle_output(raw_output)
    M.class_results = parse_gradle_per_class(raw_output)
    M.method_results = parse_gradle_per_method(raw_output)
  else
    results = parse_junit5_output(raw_output)
    M.class_results = parse_surefire_per_class(raw_output)
    M.method_results = proj and proj.root and parse_surefire_xml(proj.root) or {}
  end

  M.results = results
  M.show_results(results)
  vim.schedule(function()
    require("spring-tools.ui.sidebar").refresh()
  end)
end

function M.show_results(results)
  local buf, win = ui.create_float_win({
    width = 80,
    height = 20,
    title = " Test Results ",
  })

  local lines = {}
  local summary_color = results.failed > 0 and "FAIL" or "PASS"

  table.insert(lines, " Results: " .. summary_color)
  table.insert(lines, " Duration: " .. math.floor(results.duration) .. "ms")
  table.insert(lines, " Passed: " .. results.passed .. " | Failed: " .. results.failed .. " | Skipped: " .. results.skipped)
  table.insert(lines, "")

  if results.failed > 0 then
    table.insert(lines, " Failures:")
    for _, trace in ipairs(results.stack_traces) do
      table.insert(lines, "  " .. trace)
    end
    table.insert(lines, "")
  end

  table.insert(lines, " Actions:")
  table.insert(lines, "  q - close    f - jump to first failure")

  ui.set_lines(buf, lines)

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true, nowait = true })
  if results.stack_traces and #results.stack_traces > 0 then
    vim.api.nvim_buf_set_keymap(buf, "n", "f", ":lua require('spring-tools.tests').jump_to_failure()<CR>", { noremap = true, silent = true, nowait = true })
  end
end

function M.jump_to_failure()
  if not M.results or #M.results.stack_traces == 0 then
    utils.notify("No failures to jump to", vim.log.levels.INFO)
    return
  end

  for _, trace in ipairs(M.results.stack_traces) do
    local file_path, line_num = trace:match("%((.-):(%d+)%)")
    if file_path then
      local full_path = vim.fn.findfile(file_path)
      if full_path ~= "" then
        vim.cmd("edit " .. full_path)
        vim.api.nvim_win_set_cursor(0, { tonumber(line_num), 0 })
        vim.cmd("normal! zz")
        return
      end
    end
  end
  utils.notify("Could not locate failure source file", vim.log.levels.WARN)
end

function M.test_explorer()
  local dir = vim.fn.getcwd()
  local tests = M.find_test_methods(dir)

  if #tests == 0 then
    utils.notify("No test classes found", vim.log.levels.INFO)
    return
  end

  local items = {}
  table.insert(items, { label = "[Run all tests]", type = "all" })

  for _, test in ipairs(tests) do
    table.insert(items, { label = test.class, type = "class", test = test })
    for _, method in ipairs(test.methods) do
      table.insert(items, { label = "  " .. method.name, type = "method", test = test, method = method })
    end
  end

  utils.pick(items, {
    prompt_title = " Java Tests ",
    entry_maker = function(item)
      return { value = item, display = item.label, ordinal = item.label }
    end,
  }, function(item)
    if item.type == "all" then
      M.run_all_tests()
    elseif item.type == "class" then
      M.run_test_class(item.test.full_class)
    elseif item.type == "method" then
      M.run_test_method(item.test.full_class, item.method.name)
    end
  end)
end

function M.run_current_method()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if not file:match("%.java$") then
    utils.notify("Not a Java file", vim.log.levels.WARN)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local class_match = nil
  local method_match = nil

  for i = cursor[1] - 1, 1, -1 do
    if content[i] and content[i]:find("@Test") then
      for j = i, math.min(i + 3, #content) do
        local m = content[j]:match("void%s+(%w+)%s*%(")
        if m then
          method_match = m
          break
        end
      end
      break
    end
  end

  for i = 1, cursor[1] - 1 do
    local c = content[i]:match("class%s+(%w+)")
    if c then class_match = c end
  end

  if not method_match then
    utils.notify("No @Test method found at cursor", vim.log.levels.WARN)
    return
  end

  local project_root = utils.find_project_root(file)
  local tests = M.find_test_methods(project_root)
  local full_class = nil

  for _, test in ipairs(tests) do
    if test.class == class_match then
      full_class = test.full_class
      break
    end
  end

  if full_class then
    M.run_test_method(full_class, method_match)
  else
    utils.notify("Could not resolve full class name", vim.log.levels.WARN)
  end
end

function M.run_current_class()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if not file:match("%.java$") then
    utils.notify("Not a Java file", vim.log.levels.WARN)
    return
  end

  local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local class_match = nil
  local package_match = nil

  for _, line in ipairs(content) do
    local p = line:match("package%s+([%w%.]+)")
    if p then package_match = p end
    local c = line:match("class%s+(%w+)")
    if c then class_match = c end
  end

  if class_match then
    local full_class = package_match and (package_match .. "." .. class_match) or class_match
    M.run_test_class(full_class)
  else
    utils.notify("Could not determine class name", vim.log.levels.WARN)
  end
end

return M
