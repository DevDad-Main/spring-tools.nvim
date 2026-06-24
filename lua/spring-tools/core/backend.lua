local state = require("spring-tools.core.state")

local M = {}

M.backends = {}
M.active_backend = nil

function M.register(backend)
  M.backends[backend.name] = backend
  if not M.active_backend then
    M.active_backend = backend.name
  end
end

function M.get_backend(name)
  return M.backends[name or M.active_backend]
end

function M.set_active_backend(name)
  if M.backends[name] then
    M.active_backend = name
    state.emit("backend_changed", name)
  end
end

function M.get_active_backend()
  return M.backends[M.active_backend]
end

M.BaseBackend = {
  name = "base",
  display_name = "Base Backend",
}

function M.BaseBackend:can_run(project) return false end
function M.BaseBackend:can_build(project) return false end
function M.BaseBackend:get_run_command(project) return nil end
function M.BaseBackend:get_build_command(project) return nil end
function M.BaseBackend:get_test_command(project, class, method) return nil end
function M.BaseBackend:detect(project_root) return false end
function M.BaseBackend:get_status(project) return "stopped" end
function M.BaseBackend:get_logs(project) return {} end

function M.BaseBackend:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

local ProcessManager = {
  processes = {},
  log_buffers = {},
}

function ProcessManager.start(_, project, cmd, cwd, callbacks, track)
  callbacks = callbacks or {}
  local logs = {}
  local start_time = os.time()

  local partial_out = ""
  local partial_err = ""

  -- track defaults to true; pass false for one-off commands (e.g. "mvn clean compile")
  -- to avoid creating a process record that would show the project as "running"
  if track == nil then track = true end

  local key = vim.fn.resolve(project.root)

  local job_id = vim.fn.jobstart(cmd, {
    cwd = cwd,
    on_stdout = function(_, data, _)
      if not data or #data == 0 then return end
      if partial_out ~= "" then
        data[1] = partial_out .. (data[1] or "")
        partial_out = ""
      end
      local partial = #data > 0 and data[#data] ~= ""
      local limit = partial and #data - 1 or #data
      for i = 1, limit do
        local line = data[i]
        if line ~= "" then
          line = line:gsub("\r$", "")
          table.insert(logs, line)
          if callbacks.on_stdout then callbacks.on_stdout(line) end
        end
      end
      if partial then
        partial_out = data[#data]
      end
    end,
    on_stderr = function(_, data, _)
      if not data or #data == 0 then return end
      if partial_err ~= "" then
        data[1] = partial_err .. (data[1] or "")
        partial_err = ""
      end
      local partial = #data > 0 and data[#data] ~= ""
      local limit = partial and #data - 1 or #data
      for i = 1, limit do
        local line = data[i]
        if line ~= "" then
          line = line:gsub("\r$", "")
          table.insert(logs, line)
          if callbacks.on_stderr then callbacks.on_stderr(line) end
        end
      end
      if partial then
        partial_err = data[#data]
      end
    end,
    on_exit = function(_, exit_code, _)
      local my_job_id = job_id
      vim.schedule(function()
        if partial_out ~= "" then
          table.insert(logs, partial_out)
          if callbacks.on_stdout then callbacks.on_stdout(partial_out) end
        end
        if partial_err ~= "" then
          table.insert(logs, partial_err)
          if callbacks.on_stderr then callbacks.on_stderr(partial_err) end
        end
        local proc = ProcessManager.get(nil, project)
        if proc and proc.job_id == my_job_id then
          proc.status = exit_code == 0 and "stopped" or "failed"
          proc.exit_code = exit_code
        end
        if callbacks.on_exit then callbacks.on_exit(exit_code, logs) end
        state.emit("process_exited", project, exit_code)
      end)
    end,
  })

  if job_id and job_id > 0 then
    if track then
      ProcessManager.processes[key] = {
        job_id = job_id,
        status = "running",
        cmd = cmd,
        cwd = cwd,
        start_time = start_time,
        logs = logs,
        port = nil,
        profile = nil,
      }
      state.emit("process_started", project)
    end
    return job_id, ProcessManager.get(nil, project)
  end

  return nil, nil
end

function ProcessManager.stop(_, project)
  local proc = ProcessManager.get(nil, project)
  if proc and proc.status == "running" then
    vim.fn.jobstop(proc.job_id)
    if proc.port then
      if vim.fn.executable("fuser") == 1 then
        vim.fn.system("fuser -k " .. proc.port .. "/tcp 2>/dev/null &")
      elseif vim.fn.executable("lsof") == 1 then
        vim.fn.system("lsof -ti :" .. proc.port .. " | xargs kill -9 2>/dev/null &")
      end
    end
    proc.status = "stopped"
    state.emit("process_stopped", project)
    return true
  end
  return false
end

function ProcessManager.restart(_, project, callbacks)
  local proc = ProcessManager.get(nil, project)
  if proc then
    local cmd = proc.cmd
    local cwd = proc.cwd
    ProcessManager.stop(nil, project)
    vim.defer_fn(function()
      ProcessManager.start(nil, project, cmd, cwd, callbacks)
    end, 1000)
  end
end

function ProcessManager.get(_, project)
  local resolved = vim.fn.resolve(project.root)
  return ProcessManager.processes[resolved] or ProcessManager.processes[project.root]
end

function ProcessManager.get_all()
  return ProcessManager.processes
end

function ProcessManager.extract_port(_, project, line)
  local proc = ProcessManager.get(nil, project)
  if proc then
    local port = line:match("Tomcat initialized with port[s:]*(%d+)")
      or line:match("Tomcat started on port[s:]*(%d+)")
      or line:match("Netty started on port[s:]*(%d+)")
      or line:match("port[s]?:%s*(%d+)")
    if port then proc.port = port end
    local profile = line:match("The following profiles are active:%s*(%S+)")
    if profile then proc.profile = profile end
  end
end

M.ProcessManager = ProcessManager

return M