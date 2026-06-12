local config = require("spring-tools.config")
local utils = require("spring-tools.utils")

local M = {}

M.projects = {}
M.watchers = {}

function M.detect_projects(start_path)
  start_path = start_path or vim.fn.getcwd()
  local project_root = utils.find_project_root(start_path)
  if not project_root then
    return {}
  end

  local projects = {}
  local root_name = vim.fn.fnamemodify(project_root, ":t")

  local entry = {
    name = root_name,
    root = project_root,
    build_type = utils.build_type(project_root),
    build_files = utils.find_build_files(project_root),
    has_spring_boot = false,
  }

  entry.has_spring_boot = M.detect_spring_boot(project_root)
  table.insert(projects, entry)

  M.projects = projects
  return projects
end

function M.detect_spring_boot(project_root)
  local java_files = utils.find_java_files(project_root)
  for _, file in ipairs(java_files) do
    local f = io.open(file, "r")
    if f then
      local content = f:read("*a")
      f:close()
      if content:find("@SpringBootApplication") then
        return true
      end
    end
  end
  return false
end

function M.get_active_project()
  local cwd = vim.fn.getcwd()
  for _, proj in ipairs(M.projects) do
    if cwd:find(proj.root, 1, true) == 1 then
      return proj
    end
  end
  if #M.projects > 0 then
    return M.projects[1]
  end
  return nil
end

function M.get_build_command(project)
  if not project then return nil end
  local cmd
  if project.build_type == "maven" then
    if vim.fn.executable("./mvnw") == 1 then
      cmd = { "./mvnw" }
    else
      cmd = { "mvn" }
    end
  elseif project.build_type == "gradle" then
    if vim.fn.executable("./gradlew") == 1 then
      cmd = { "./gradlew" }
    else
      cmd = { "gradle" }
    end
  end
  return cmd
end

function M.get_run_command(project)
  local cmd = M.get_build_command(project)
  if not cmd then return nil end
  local args = vim.deepcopy(cmd)
  if project.build_type == "maven" then
    table.insert(args, "spring-boot:run")
  else
    table.insert(args, "bootRun")
  end
  return args
end

function M.get_test_command(project, test_class, test_method)
  local cmd = M.get_build_command(project)
  if not cmd then return nil end
  local args = vim.deepcopy(cmd)
  if project.build_type == "maven" then
    args[#args + 1] = "test"
    args[#args + 1] = "-Dtest=" .. test_class
    if test_method then
      args[#args] = args[#args] .. "#" .. test_method
    end
  else
    args[#args + 1] = "test"
    args[#args + 1] = "--tests"
    local test_ref = test_class
    if test_method then
      test_ref = test_ref .. "." .. test_method
    end
    args[#args + 1] = test_ref
  end
  return args
end

return M
