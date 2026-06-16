local path = "."
package.path = package.path .. ";" .. path .. "/lua/?.lua"

local function temp_project()
  local dir = "/tmp/spring-test-" .. math.floor(os.clock() * 10000)
  vim.fn.mkdir(dir, "p")
  local f = io.open(dir .. "/pom.xml", "w")
  f:write("<project></project>")
  f:close()
  return dir
end

local function cleanup(dir)
  vim.fn.delete(dir, "rf")
end

describe("REST endpoint detection", function()
  local endpoints = require("spring-tools.endpoints")
  local tmpdir

  before_each(function()
    tmpdir = temp_project()
  end)

  after_each(function()
    cleanup(tmpdir)
  end)

  it("detects @GetMapping", function()
    local lines = {
      "@RestController",
      "@RequestMapping(\"/users\")",
      "public class UserController {",
      "  @GetMapping(\"/{id}\")",
      "  public User getUser(@PathVariable String id) {",
      "    return null;",
      "  }",
      "}",
    }
    local content = table.concat(lines, "\n")
    local file = tmpdir .. "/EndpointController.java"
    local f = io.open(file, "w")
    f:write(content)
    f:close()

    endpoints.scan_endpoints(tmpdir)
    local found = false
    for _, ep in ipairs(endpoints.endpoints) do
      if ep.method == "GET" and ep.path == "/users/{id}" then
        found = true
        break
      end
    end
    assert.is_true(found)
  end)

  it("detects @PostMapping", function()
    local lines = {
      "@RestController",
      "public class UserController {",
      "  @PostMapping",
      "  public User createUser(@RequestBody User user) {",
      "    return null;",
      "  }",
      "}",
    }
    local content = table.concat(lines, "\n")
    local file = tmpdir .. "/PostController.java"
    local f = io.open(file, "w")
    f:write(content)
    f:close()

    endpoints.scan_endpoints(tmpdir)
    local found = false
    for _, ep in ipairs(endpoints.endpoints) do
      if ep.method == "POST" then
        found = true
        break
      end
    end
    assert.is_true(found)
  end)

  it("detects @DeleteMapping with path", function()
    local lines = {
      "@RestController",
      "@RequestMapping(\"/api\")",
      "public class AdminController {",
      "  @DeleteMapping(\"/users/{id}\")",
      "  public void deleteUser(@PathVariable Long id) {}",
      "}",
    }
    local content = table.concat(lines, "\n")
    local file = tmpdir .. "/DeleteController.java"
    local f = io.open(file, "w")
    f:write(content)
    f:close()

    endpoints.scan_endpoints(tmpdir)
    local found = false
    for _, ep in ipairs(endpoints.endpoints) do
      if ep.method == "DELETE" and ep.path == "/api/users/{id}" then
        found = true
        break
      end
    end
    assert.is_true(found)
  end)

  it("extracts path from annotation", function()
    local path = endpoints.extract_path('@GetMapping("/hello")')
    assert.are.equal("/hello", path)
  end)

  it("extracts path from value attribute", function()
    local path = endpoints.extract_path('@RequestMapping(value = "/api")')
    assert.are.equal("/api", path)
  end)

  it("determines HTTP method for GetMapping", function()
    local method = endpoints.determine_method("GetMapping", '@GetMapping("/test")')
    assert.are.equal("GET", method)
  end)

  it("determines HTTP method for RequestMapping", function()
    local method = endpoints.determine_method("RequestMapping", '@RequestMapping(method = RequestMethod.POST)')
    assert.are.equal("POST", method)
  end)
end)
