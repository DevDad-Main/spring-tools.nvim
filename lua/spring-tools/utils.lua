local config = require("spring-tools.config")

local M = {}

M.cache = {
  data = nil,
  dirty = false,
}

function M.get_cache_path()
  return config.options.cache_dir .. "/spring-tools.json"
end

function M.load_cache()
  local path = M.get_cache_path()
  local ok, result = pcall(function()
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return vim.json.decode(content)
  end)
  if ok and result then
    M.cache.data = result
  else
    M.cache.data = {}
  end
  return M.cache.data
end

function M.save_cache()
  if not M.cache.dirty then return end
  local path = M.get_cache_path()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local f = io.open(path, "w")
  if not f then return end
  local ok, err = pcall(function()
    f:write(vim.json.encode(M.cache.data))
    f:close()
  end)
  if ok then
    M.cache.dirty = false
  else
    f:close()
  end
end

function M.invalidate_cache()
  M.cache.data = {}
  M.cache.dirty = true
  M.save_cache()
end

function M.mark_dirty()
  M.cache.dirty = true
end

function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.schedule(function()
    vim.notify("[spring-tools] " .. msg, level)
  end)
end

function M.is_maven_project(dir)
  local pom = dir .. "/pom.xml"
  return vim.fn.filereadable(pom) == 1
end

function M.is_gradle_project(dir)
  local gradle = dir .. "/build.gradle"
  local gradle_kts = dir .. "/build.gradle.kts"
  return vim.fn.filereadable(gradle) == 1 or vim.fn.filereadable(gradle_kts) == 1
end

function M.find_project_root(start_path)
  start_path = start_path or vim.fn.getcwd()
  local dir = vim.fn.resolve(start_path)
  local max_depth = 20
  local depth = 0
  while dir ~= "/" and depth < max_depth do
    if M.is_maven_project(dir) or M.is_gradle_project(dir) then
      return dir
    end
    dir = vim.fn.fnamemodify(dir, ":h")
    depth = depth + 1
  end
  return nil
end

function M.find_all_project_roots(start_path)
  start_path = start_path or vim.fn.getcwd()
  start_path = vim.fn.resolve(start_path)
  local roots = {}
  local seen = {}
  local function scan(dir, depth)
    if seen[dir] then return end
    seen[dir] = true
    if M.is_maven_project(dir) or M.is_gradle_project(dir) then
      roots[#roots + 1] = dir
      -- After finding a project root, only scan immediate subdirectories
      -- for child modules (don't recurse deeper than 1 level into children)
      if depth == 0 then
        scan_children(dir)
      end
      return
    end
    if depth > 4 then return end
    local ok, entries = pcall(vim.fn.readdir, dir)
    if not ok then return end
    for _, entry in ipairs(entries) do
      if entry ~= "." and entry ~= ".." and entry ~= ".git" and entry ~= "node_modules" and entry ~= "target" and entry ~= "build" then
        local full = dir .. "/" .. entry
        if vim.fn.isdirectory(full) == 1 then
          scan(full, depth + 1)
        end
      end
    end
  end

  local function scan_children(parent_dir)
    local ok, entries = pcall(vim.fn.readdir, parent_dir)
    if not ok then return end
    for _, entry in ipairs(entries) do
      if entry ~= "." and entry ~= ".." and entry ~= ".git" and entry ~= "node_modules" and entry ~= "target" and entry ~= "build" then
        local full = parent_dir .. "/" .. entry
        if vim.fn.isdirectory(full) == 1 and not seen[full] then
          seen[full] = true
          if M.is_maven_project(full) or M.is_gradle_project(full) then
            roots[#roots + 1] = full
          end
        end
      end
    end
  end

  scan(start_path, 0)
  return roots
end

function M.get_maven_child_modules(project_root)
  local pom = project_root .. "/pom.xml"
  local f = io.open(pom, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  local modules = {}
  for match in content:gmatch("<module>([^<]+)</module>") do
    local name = match:match("([^/]+)$") or match
    modules[name] = true
  end
  return next(modules) ~= nil and modules or nil
end

function M.get_gradle_child_modules(project_root)
  for _, sf in ipairs({ "settings.gradle", "settings.gradle.kts" }) do
    local f = io.open(project_root .. "/" .. sf, "r")
    if f then
      local content = f:read("*a")
      f:close()
      local modules = {}
      for match in content:gmatch("include%s+'([^']+)'") do
        local name = match:match(":([^:]+)$") or match:match("([^/]+)$") or match
        modules[name] = true
      end
      for match in content:gmatch('include%s+"([^"]+)"') do
        local name = match:match(":([^:]+)$") or match:match("([^/]+)$") or match
        modules[name] = true
      end
      return next(modules) ~= nil and modules or nil
    end
  end
  return nil
end

function M.get_child_modules(project_root)
  local mvn = M.get_maven_child_modules(project_root)
  if mvn then return mvn end
  return M.get_gradle_child_modules(project_root)
end

function M.find_build_files(project_root)
  local files = {}
  for _, f in ipairs({ "pom.xml", "build.gradle", "build.gradle.kts" }) do
    local path = project_root .. "/" .. f
    if vim.fn.filereadable(path) == 1 then
      table.insert(files, path)
    end
  end
  return files
end

function M.build_type(project_root)
  if M.is_maven_project(project_root) then return "maven" end
  if M.is_gradle_project(project_root) then return "gradle" end
  return nil
end

function M.find_java_files(dir)
  local args = { "find", dir, "-name", "*.java", "-type", "f" }
  local handle = io.popen(table.concat(args, " "))
  if not handle then return {} end
  local result = handle:read("*a")
  handle:close()
  local files = {}
  for f in vim.gsplit(result, "\n", { plain = true, trimempty = true }) do
    table.insert(files, f)
  end
  return files
end

function M.file_modified_since(path, timestamp)
  local mtime = vim.fn.getftime(path)
  return mtime > timestamp
end

function M.hex_encode(s)
  return s:gsub(".", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
end

function M.escape_shell_arg(arg)
  return "'" .. arg:gsub("'", "'\\''") .. "'"
end

function M.job_start(cmd, opts)
  opts = opts or {}
  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = opts.on_stdout,
    on_stderr = opts.on_stderr,
    on_exit = opts.on_exit,
    stdout_buffered = opts.stdout_buffered ~= false,
    stderr_buffered = opts.stderr_buffered ~= false,
  })
  return job_id
end

function M.has_telescope()
  local ok, _ = pcall(require, "telescope")
  return ok
end

function M.pick(items, opts, callback)
  opts = opts or {}
  if M.has_telescope() and config.options.telescope.enable then
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values

    pickers.new(opts, {
      prompt_title = opts.prompt_title or "Select",
      finder = finders.new_table({
        results = items,
        entry_maker = opts.entry_maker or function(item)
          return { value = item, display = tostring(item), ordinal = tostring(item) }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection and callback then
            callback(selection.value)
          end
        end)
        return true
      end,
    }):find()
  else
    local choices = vim.tbl_map(function(item)
      return tostring(item)
    end, items)
    vim.ui.select(choices, opts, function(choice)
      if choice then
        local idx = nil
        for i, c in ipairs(choices) do
          if c == choice then
            idx = i
            break
          end
        end
        if idx and items[idx] then
          callback(items[idx])
        end
      end
    end)
  end
end

return M
