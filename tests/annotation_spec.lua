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

describe("Bean annotation detection", function()
  local beans = require("spring-tools.beans")
  local tmpdir

  before_each(function()
    tmpdir = temp_project()
  end)

  after_each(function()
    cleanup(tmpdir)
  end)

  it("detects @Service annotation", function()
    local lines = {
      "@Service",
      "public class UserService {",
    }
    local content = table.concat(lines, "\n")
    local file = tmpdir .. "/UserService.java"
    local f = io.open(file, "w")
    f:write(content)
    f:close()

    beans.build_index(tmpdir)
    local found = false
    for _, bean in ipairs(beans.beans) do
      if bean.name == "UserService" and bean.type == "services" then
        found = true
        break
      end
    end
    assert.is_true(found)
  end)

  it("detects @Repository annotation", function()
    local lines = {
      "@Repository",
      "public class UserRepository {",
    }
    local content = table.concat(lines, "\n")
    local file = tmpdir .. "/UserRepository.java"
    local f = io.open(file, "w")
    f:write(content)
    f:close()

    beans.build_index(tmpdir)
    local found = false
    for _, bean in ipairs(beans.beans) do
      if bean.name == "UserRepository" and bean.type == "repositories" then
        found = true
        break
      end
    end
    assert.is_true(found)
  end)

  it("detects @RestController annotation", function()
    local lines = {
      "@RestController",
      "public class UserController {",
    }
    local content = table.concat(lines, "\n")
    local file = tmpdir .. "/UserController.java"
    local f = io.open(file, "w")
    f:write(content)
    f:close()

    beans.build_index(tmpdir)
    local found = false
    for _, bean in ipairs(beans.beans) do
      if bean.name == "UserController" and bean.type == "controllers" then
        found = true
        break
      end
    end
    assert.is_true(found)
  end)

  it("detects @Bean method annotation", function()
    local lines = {
      "@Configuration",
      "public class AppConfig {",
      "  @Bean",
      "  public DataSource dataSource() {",
      "    return null;",
      "  }",
      "}",
    }
    local content = table.concat(lines, "\n")
    local file = tmpdir .. "/AppConfig.java"
    local f = io.open(file, "w")
    f:write(content)
    f:close()

    beans.build_index(tmpdir)
    local found = false
    for _, bean in ipairs(beans.beans) do
      if bean.name == "dataSource" then
        found = true
        break
      end
    end
    assert.is_true(found)
  end)
end)
