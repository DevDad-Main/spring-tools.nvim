local backend = require("spring-tools.core.backend")
local utils = require("spring-tools.utils")

local DockerBackend = backend.BaseBackend:new({
  name = "docker",
  display_name = "Docker",
})

function DockerBackend:can_run(proj)
  return proj and vim.fn.filereadable(proj.root .. "/Dockerfile") == 1
end

function DockerBackend:can_build(proj)
  return self:can_run(proj)
end

function DockerBackend:detect(project_root)
  return vim.fn.filereadable(project_root .. "/Dockerfile") == 1
    or vim.fn.filereadable(project_root .. "/docker-compose.yml") == 1
    or vim.fn.filereadable(project_root .. "/docker-compose.yaml") == 1
end

function DockerBackend:get_build_command(proj)
  if not self:can_build(proj) then return nil end
  local tag = vim.fn.fnamemodify(proj.root, ":t"):lower()
  return { "docker", "build", "-t", tag, "." }
end

function DockerBackend:get_run_command(proj)
  if not self:can_run(proj) then return nil end
  local tag = vim.fn.fnamemodify(proj.root, ":t"):lower()
  return { "docker", "run", "--rm", "-p", "8080:8080", tag }
end

function DockerBackend:get_test_command(proj, class, method)
  if not self:can_run(proj) then return nil end
  local tag = vim.fn.fnamemodify(proj.root, ":t"):lower()
  local cmd = { "docker", "run", "--rm", tag, "test" }
  if class then
    cmd[#cmd + 1] = class
    if method then cmd[#cmd] = cmd[#cmd] .. "#" .. method end
  end
  return cmd
end

function DockerBackend:get_status(proj)
  local proc = backend.ProcessManager:get(proj)
  return proc and proc.status or "stopped"
end

function DockerBackend:get_logs(proj)
  local proc = backend.ProcessManager:get(proj)
  return proc and proc.logs or {}
end

backend.register(DockerBackend)

return DockerBackend