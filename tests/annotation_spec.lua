local path = "."
package.path = package.path .. ";" .. path .. "/lua/?.lua"

describe("Bean annotation detection", function()
  local beans = require("spring-tools.beans")

  it("detects @Service annotation", function()
    local lines = {
      "@Service",
      "public class UserService {",
    }
    local content = table.concat(lines, "\n")
    local file = "/tmp/test_UserService.java"
    local f = io.open(file, "w")
    f:write(content)
    f:close()

    beans.build_index("/tmp")
    local found = false
    for _, bean in ipairs(beans.beans) do
      if bean.name == "UserService" and bean.type == "services" then
        found = true
        break
      end
    end
    assert.is_true(found)
    os.remove(file)
  end)

  it("detects @Repository annotation", function()
    local lines = {
      "@Repository",
      "public class UserRepository {",
    }
    local content = table.concat(lines, "\n")
    local file = "/tmp/test_UserRepository.java"
    local f = io.open(file, "w")
    f:write(content)
    f:close()

    beans.build_index("/tmp")
    local found = false
    for _, bean in ipairs(beans.beans) do
      if bean.name == "UserRepository" and bean.type == "repositories" then
        found = true
        break
      end
    end
    assert.is_true(found)
    os.remove(file)
  end)

  it("detects @RestController annotation", function()
    local lines = {
      "@RestController",
      "public class UserController {",
    }
    local content = table.concat(lines, "\n")
    local file = "/tmp/test_UserController.java"
    local f = io.open(file, "w")
    f:write(content)
    f:close()

    beans.build_index("/tmp")
    local found = false
    for _, bean in ipairs(beans.beans) do
      if bean.name == "UserController" and bean.type == "controllers" then
        found = true
        break
      end
    end
    assert.is_true(found)
    os.remove(file)
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
    local file = "/tmp/test_AppConfig.java"
    local f = io.open(file, "w")
    f:write(content)
    f:close()

    beans.build_index("/tmp")
    local found = false
    for _, bean in ipairs(beans.beans) do
      if bean.name == "dataSource" then
        found = true
        break
      end
    end
    assert.is_true(found)
    os.remove(file)
  end)
end)
