local backend = require("spring-tools.core.backend")
local utils = require("spring-tools.utils")

local SpringBootBackend = backend.BaseBackend:new({
  name = "spring_boot",
  display_name = "Spring Boot (Maven/Gradle)",
})

function SpringBootBackend:can_run(proj)
  return proj and proj.has_spring_boot and proj.build_type
end

function SpringBootBackend:can_build(proj)
  return proj and proj.build_type ~= nil
end

function SpringBootBackend:detect(project_root)
  local bt = utils.build_type(project_root)
  if not bt then return false end
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

function SpringBootBackend:get_build_command(proj)
  if not proj or not proj.build_type then return nil end
  if proj.build_type == "maven" then
    local mvnw = (proj.root or ".") .. "/mvnw"
    return vim.fn.executable(mvnw) == 1 and { "./mvnw" } or { "mvn" }
  elseif proj.build_type == "gradle" then
    local gradlew = (proj.root or ".") .. "/gradlew"
    return vim.fn.executable(gradlew) == 1 and { "./gradlew" } or { "gradle" }
  end
  return nil
end

function SpringBootBackend:get_run_command(proj)
  local cmd = self:get_build_command(proj)
  if not cmd then return nil end
  local args = vim.deepcopy(cmd)
  if proj.build_type == "maven" then
    table.insert(args, "spring-boot:run")
  else
    table.insert(args, "bootRun")
  end
  return args
end

function SpringBootBackend:get_test_command(proj, class, method)
  local cmd = self:get_build_command(proj)
  if not cmd then return nil end
  local args = vim.deepcopy(cmd)
  if proj.build_type == "maven" then
    args[#args + 1] = "test"
    if class then
      args[#args + 1] = "-Dtest=" .. class
      if method then args[#args] = args[#args] .. "#" .. method end
    end
  else
    args[#args + 1] = "test"
    if class then
      args[#args + 1] = "--tests"
      local test_ref = class
      if method then test_ref = test_ref .. "." .. method end
      args[#args + 1] = test_ref
    end
  end
  return args
end

function SpringBootBackend:get_status(proj)
  local proc = backend.ProcessManager:get(proj)
  if not proc then return "stopped" end
  if proc.exit_code and proc.exit_code ~= 0 then return "failed" end
  if proc.status == "failed" and not proc.exit_code then
    -- stale entry with no exit code recorded — clear it
    backend.ProcessManager.processes[proj.root] = nil
    return "stopped"
  end
  return proc.status
end

function SpringBootBackend:get_logs(proj)
  local proc = backend.ProcessManager:get(proj)
  return proc and proc.logs or {}
end

function SpringBootBackend:get_port(proj)
  local proc = backend.ProcessManager:get(proj)
  return proc and proc.port
end

function SpringBootBackend:get_profile(proj)
  local proc = backend.ProcessManager:get(proj)
  return proc and proc.profile
end

function SpringBootBackend:get_uptime(proj)
  local proc = backend.ProcessManager:get(proj)
  if not proc or not proc.start_time then return "--" end
  local elapsed = os.difftime(os.time(), proc.start_time)
  if elapsed < 60 then return math.floor(elapsed) .. "s"
  elseif elapsed < 3600 then return math.floor(elapsed / 60) .. "m"
  else return math.floor(elapsed / 3600) .. "h " .. math.floor((elapsed % 3600) / 60) .. "m" end
end

backend.register(SpringBootBackend)

return SpringBootBackend