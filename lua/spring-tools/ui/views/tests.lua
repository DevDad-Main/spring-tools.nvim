local tests_mod = require("spring-tools.tests")
local project = require("spring-tools.project")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")
local utils = require("spring-tools.utils")
local sections = require("spring-tools.ui.sections").new("tests")

local M = {}

M.title = "Tests"

M.items = {}
M._test_classes = nil
M._project_classes = nil

local function scan_dir()
  local proj = project.get_active_project()
  return proj and proj.root or vim.fn.getcwd()
end

function M.header()
  local count = 0
  if project.is_multi_project() and M._project_classes then
    for _, data in pairs(M._project_classes) do
      for _, test in ipairs(data.classes) do
        if test.class then count = count + 1 end
      end
    end
  else
    for _, item in ipairs(M.items) do
      if item.type == "class" then count = count + 1 end
    end
  end
  return { { "Test Explorer (" .. count .. " classes)", "SpringToolsHeader" } }
end

function M:load_items()
  local multi = project.is_multi_project()

  if not multi then
    if #M.items == 0 and not M._test_classes then
      M.items = { { type = "loading", label = "Indexing tests..." } }
      vim.defer_fn(function()
        M._test_classes = tests_mod.find_test_methods(scan_dir())
        sidebar.refresh()
      end, 1)
      return
    end
    M.items = {}
    table.insert(M.items, { type = "all", label = "Run all tests" })
    for _, test in ipairs(M._test_classes) do
      local is_collapsed = sections:is_collapsed(test.class)
      M.items[#M.items + 1] = { type = "class", test = test, label = test.class, section_key = test.class, collapsed = is_collapsed }
      if not is_collapsed then
        for _, method in ipairs(test.methods) do
          M.items[#M.items + 1] = { type = "method", test = test, method = method, label = method.name }
        end
      end
    end
  else
    local projs = project.get_workspace_projects()
    M._project_classes = {}
    M.items = {}

    -- Pre-scan all projects
    for _, proj in ipairs(projs) do
      if not M._project_classes[proj.root] then
        if proj.is_virtual then
          M._project_classes[proj.root] = { name = proj.name, classes = {} }
        else
          local classes = tests_mod.find_test_methods(proj.root)
          M._project_classes[proj.root] = { name = proj.name, classes = classes }
        end
      end
    end

    local function render_proj_tree(proj_list, indent)
      indent = indent or 0
      for _, proj in ipairs(proj_list) do
        local data = M._project_classes[proj.root]
        if not data then
          if proj.is_virtual then
            data = { name = proj.name, classes = {} }
          else
            local classes = tests_mod.find_test_methods(proj.root)
            data = { name = proj.name, classes = classes }
          end
          M._project_classes[proj.root] = data
        end
        local psk = "proj:" .. proj.root
        local proj_collapsed = sections:is_collapsed(psk)
        M.items[#M.items + 1] = { type = "project_header", label = data.name, project_root = proj.root, section_key = psk, collapsed = proj_collapsed, _indent = indent }
        if not proj_collapsed then
          M.items[#M.items + 1] = { type = "all", label = "Run all tests", project_root = proj.root }
          for _, test in ipairs(data.classes) do
            local sk = test.class .. ":" .. proj.root
            local is_collapsed = sections:is_collapsed(sk)
            M.items[#M.items + 1] = { type = "class", test = test, label = test.class, section_key = sk, collapsed = is_collapsed, project_root = proj.root }
            if not is_collapsed then
              for _, method in ipairs(test.methods) do
                M.items[#M.items + 1] = { type = "method", test = test, method = method, label = method.name, project_root = proj.root }
              end
            end
          end
          if proj.children and #proj.children > 0 then
            render_proj_tree(proj.children, indent + 1)
          end
        end
      end
    end

    for _, proj in ipairs(projs) do
      proj.children = {}
    end
    local is_child = {}
    for _, proj in ipairs(projs) do
      for _, parent in ipairs(projs) do
        if proj.root ~= parent.root
          and proj.root:sub(1, #parent.root) == parent.root
          and proj.root:sub(#parent.root + 1, #parent.root + 1) == "/" then
          parent.children[#parent.children + 1] = proj
          is_child[proj.root] = true
          break
        end
      end
    end
    local top_level = {}
    for _, proj in ipairs(projs) do
      if not is_child[proj.root] then table.insert(top_level, proj) end
      if #proj.children == 0 then proj.children = nil end
    end
    render_proj_tree(top_level)
  end
end

function M:render_item(item, selected)
  local multi = project.is_multi_project()
  if item.type == "loading" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsDim"
    return { { "  " .. item.label, hl } }
  end
  if item.type == "project_header" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local pad = item._indent and string.rep("  ", item._indent) or ""
    local hl = selected and "SpringToolsSelected" or "SpringToolsSectionHeader"
    return { { pad .. icon .. " " .. item.label, hl } }
  end
  if item.type == "all" then
    local pfx = multi and "    " or "  "
    local hl = selected and "SpringToolsSelected" or "SpringToolsTestRunAll"
    return { { pfx .. "\u{25b6}" .. " " .. item.label, hl } }
  end
  if item.type == "class" then
    local cr = tests_mod.class_results and tests_mod.class_results[item.test.class]
    local icon
    if cr then
      icon = cr.failed > 0 and "\u{2717}" or "\u{2713}"
    else
      icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    end
    local pfx = multi and "    " or "  "
    local hl = selected and "SpringToolsSelected" or "SpringToolsTestClass"
    return { { pfx .. icon .. " " .. item.label, hl } }
  end
  local pfx = multi and "        " or "      "
  local hl = selected and "SpringToolsSelected" or "SpringToolsTestMethod"
  local mr = tests_mod.method_results
  local status_icon = (mr and mr[item.test.class] and mr[item.test.class][item.method.name]) and (mr[item.test.class][item.method.name] == "failed" and "\u{2717}" or "\u{2713}") or "\u{22a1}"
  return { { pfx .. status_icon .. " " .. item.label, hl } }
end

function M:run_test(cmd)
  local ui = require("spring-tools.ui")
  local output_lines = {}
  output.show({ "Running tests..." }, "Test Output")
  ui.start_background_job(cmd, nil, {
    on_stdout = function(data)
      if data then
        for _, l in ipairs(data) do output.append(l) end
        vim.schedule(function()
          if output.buf and vim.api.nvim_buf_is_valid(output.buf) then
            local lc = vim.api.nvim_buf_line_count(output.buf)
            if lc > 0 then
              pcall(vim.api.nvim_win_set_cursor, output.win, {lc, 0})
            end
          end
        end)
      end
    end,
    on_stderr = function(data)
      if data then for _, l in ipairs(data) do output.append(l) end end
    end,
    on_exit = function(exit_code, all_data)
      tests_mod.handle_test_results(all_data, exit_code)
    end,
  })
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.type == "project_header" then
    sections:toggle(item.section_key)
    sidebar.refresh()
    return
  end

  local proj_root = item.project_root or scan_dir()
  local proj = project.find_project_for_file(proj_root) or project.get_active_project()
  if not proj then utils.notify("No project found", vim.log.levels.WARN) return end
  local be = project.get_backend_for_project(proj)
  if not be then return end

  if item.type == "class" then
    sections:toggle(item.section_key)
    sidebar.refresh()
    return
  end

  local cmd
  if item.type == "all" then
    cmd = be:get_build_command(proj)
    if cmd then table.insert(cmd, "test") end
  elseif item.type == "method" then
    cmd = be:get_test_command(proj, item.test.full_class, item.method.name)
  end
  if cmd then M:run_test(cmd) end
end

function M:fold_all(open)
  if open then
    sections:expand_all()
    sidebar.refresh()
    vim.schedule(function()
      sections:expand_all()
      sidebar.refresh()
    end)
  else
    sections:collapse_all()
    sidebar.refresh()
  end
end

return M
