local utils = require("spring-tools.utils")

local M = {}

M.projects = {}
M.active_project_root = nil
M._excluded = {}

function M.cache_path()
  return vim.fn.stdpath("data") .. "/spring-tools/projects.json"
end

function M.load_cache()
  local path = M.cache_path()
  local ok, data = pcall(function()
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return vim.json.decode(content)
  end)
  if ok and type(data) == "table" and #data > 0 then
    M.projects = data
  end
end

function M.save_cache()
  local path = M.cache_path()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  pcall(function()
    local f = io.open(path, "w")
    if not f then return end
    f:write(vim.json.encode(M.projects))
    f:close()
  end)
end

function M.build_entry(project_root)
  return {
    name = vim.fn.fnamemodify(project_root, ":t"),
    root = project_root,
    build_type = utils.build_type(project_root),
    has_spring_boot = M.detect_spring_boot(project_root),
    backends = {},
  }
end

function M.add_entry(entry)
  if M._excluded[entry.root] then return end
  for i, p in ipairs(M.projects) do
    if p.root == entry.root then
      M.projects[i] = entry
      M.save_cache()
      return
    end
  end
  table.insert(M.projects, entry)
  M.save_cache()
end

function M.remove_project(root)
  for i, p in ipairs(M.projects) do
    if p.root == root then
      table.remove(M.projects, i)
      if M.active_project_root == root then
        M._excluded[root] = true
        M.active_project_root = nil
      end
      M.save_cache()
      local state = require("spring-tools.core.state")
      state.set_projects(M.projects)
      return true
    end
  end
  return false
end

function M.detect_projects(start_path)
  M.load_cache()
  start_path = start_path or vim.fn.getcwd()
  local project_root = utils.find_project_root(start_path)
  if not project_root then
    local state = require("spring-tools.core.state")
    state.set_projects(M.projects)
    return M.projects
  end
  local entry = M.build_entry(project_root)
  local backends_mod = require("spring-tools.backends")
  entry.backends = {}
  for name, be in pairs(backends_mod.backends) do
    if be:detect(project_root) then
      table.insert(entry.backends, name)
    end
  end
  M.add_entry(entry)
  local state = require("spring-tools.core.state")
  state.set_projects(M.projects)
  return M.projects
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
  if M.active_project_root then
    for _, proj in ipairs(M.projects) do
      if proj.root == M.active_project_root then
        return proj
      end
    end
  end
  local cwd = vim.fn.getcwd()
  for _, proj in ipairs(M.projects) do
    if cwd:find(proj.root, 1, true) == 1 then
      M.active_project_root = proj.root
      return proj
    end
  end
  if #M.projects > 0 then
    M.active_project_root = M.projects[1].root
    return M.projects[1]
  end
  return nil
end

function M.set_active_project(proj)
  M.active_project_root = proj and proj.root or nil
end

local backend_priority = { spring_boot = 1, docker = 2 }

function M.get_backend_for_project(project, backend_name)
  local backends_mod = require("spring-tools.backends")
  if backend_name then
    return backends_mod.backends[backend_name]
  end
  if project and project.backends and #project.backends > 0 then
    local best, best_rank = nil, math.huge
    for _, name in ipairs(project.backends) do
      local rank = backend_priority[name] or 99
      if rank < best_rank then
        best = backends_mod.backends[name]
        best_rank = rank
      end
    end
    return best
  end
  return backends_mod.get_active_backend()
end

return M