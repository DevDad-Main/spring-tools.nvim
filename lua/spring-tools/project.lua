local utils = require("spring-tools.utils")
local jp = require("spring-tools.java_parser")

local M = {}

M.projects = {}
M.active_project_root = nil
M.workspace_root = nil
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

function M.build_entry(project_root, cached)
  local has_sb
  if cached and cached.has_spring_boot ~= nil then
    has_sb = cached.has_spring_boot
  else
    has_sb = M.detect_spring_boot(project_root)
  end
  return {
    name = vim.fn.fnamemodify(project_root, ":t"),
    root = project_root,
    build_type = utils.build_type(project_root),
    has_spring_boot = has_sb,
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
      state.set_projects(M.projects, M.workspace_root)
      local cache_prefixes = { "bean_index:", "endpoint_index:", "config_index_v2:", "test_index:", "mvn_dynamic_goals:", "gradle_tasks:", "auto_restart:", "auto_clean:", "recent_cmds:" }
      for _, pfx in ipairs(cache_prefixes) do
        local key = pfx .. root
        if utils.cache.data and utils.cache.data[key] ~= nil then
          utils.cache.data[key] = nil
          utils.mark_dirty()
        end
      end
      require("spring-tools.build_completion").invalidate_cache(root)
      utils.save_cache()
      require("spring-tools.tests").invalidate_test_cache(root)
      return true
    end
  end
  return false
end

function M.detect_projects(start_path)
  start_path = start_path or vim.fn.getcwd()
  local resolved = vim.fn.resolve(start_path)

  if M.workspace_root and vim.fn.resolve(M.workspace_root) ~= resolved then
    M.projects = {}
  else
    M.load_cache()
  end

  M.workspace_root = resolved

  local all_roots = utils.find_all_project_roots(start_path)
  if #all_roots == 0 then
    local state = require("spring-tools.core.state")
    state.set_projects(M.projects, M.workspace_root)
    return M.projects
  end

  for _, root in ipairs(all_roots) do
    local cached
    for _, p in ipairs(M.projects) do
      if p.root == root then cached = p; break end
    end
    local entry = M.build_entry(root, cached)
    local backends_mod = require("spring-tools.backends")
    entry.backends = {}
    for name, be in pairs(backends_mod.backends) do
      if be:detect(root) then
        table.insert(entry.backends, name)
      end
    end
    M.add_entry(entry)
  end

  -- Build parent-child tree: a root nested under another root is a child
  for _, proj in ipairs(M.projects) do
    proj.children = nil
  end
  table.sort(M.projects, function(a, b) return #a.root < #b.root end)
  local child_roots = {}
  local parent_modules = {}
  for _, proj in ipairs(M.projects) do
    parent_modules[proj.root] = utils.get_child_modules(proj.root)
  end
  for _, proj in ipairs(M.projects) do
    for _, parent in ipairs(M.projects) do
      if proj.root ~= parent.root and proj.root:sub(1, #parent.root) == parent.root and proj.root:sub(#parent.root + 1, #parent.root + 1) == "/" then
        local child_name = vim.fn.fnamemodify(proj.root, ":t")
        local pmodules = parent_modules[parent.root]
        -- Only treat as child if parent explicitly declares it as a module
        if pmodules and pmodules[child_name] then
          if not parent.children then parent.children = {} end
          parent.children[#parent.children + 1] = proj
          child_roots[proj.root] = true
          break
        end
      end
    end
  end
  -- Mark top-level status
  for _, proj in ipairs(M.projects) do
    proj.is_top_level = not child_roots[proj.root]
  end

  if not M.active_project_root then
    local cwd = vim.fn.getcwd()
    for _, proj in ipairs(M.projects) do
      if cwd:find(proj.root, 1, true) == 1 then
        M.active_project_root = proj.root
        break
      end
    end
    if not M.active_project_root and #M.projects > 0 then
      M.active_project_root = M.projects[1].root
    end
  end

  local state = require("spring-tools.core.state")
  state.set_projects(M.projects, M.workspace_root)
  return M.projects
end

function M.detect_spring_boot(project_root)
  local java_files = utils.find_java_files(project_root)
  for _, file in ipairs(java_files) do
    local parsed = jp.parse_file(file)
    if parsed then
      local has_sba = jp.has_spring_boot_application(parsed)
      parsed:cleanup()
      if has_sba then return true end
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

function M.is_multi_project()
  return #M.projects > 1
end

function M.get_workspace_projects()
  if M.workspace_root and #M.projects > 0 then
    return M.projects
  end
  return {}
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

function M.find_project_for_file(file_path)
  if not file_path then return nil end
  local normalized = vim.fn.fnamemodify(file_path, ":p"):gsub("/$", "")
  local best_root, best_proj
  for _, p in ipairs(M.projects) do
    local root = vim.fn.fnamemodify(p.root, ":p"):gsub("/$", "")
    if normalized:find(root, 1, true) == 1 then
      if not best_root or #root > #best_root then
        best_root = root
        best_proj = p
      end
    end
  end
  return best_proj
end

return M
