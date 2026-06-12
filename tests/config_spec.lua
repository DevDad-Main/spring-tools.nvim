local path = "."
package.path = package.path .. ";" .. path .. "/lua/?.lua"

describe("Configuration parsing", function()
  local config_explorer = require("spring-tools.config_explorer")

  it("parses .properties file", function()
    local content = [[
server.port=8080
spring.datasource.url=jdbc:mysql://localhost/db
spring.profiles.active=dev
]]
    local props = config_explorer.parse_properties(content, "application.properties")
    assert.are.equal(#props, 3)

    local port_found = false
    local url_found = false
    for _, p in ipairs(props) do
      if p.key == "server.port" and p.value == "8080" then
        port_found = true
      end
      if p.key == "spring.datasource.url" and p.value == "jdbc:mysql://localhost/db" then
        url_found = true
      end
    end
    assert.is_true(port_found)
    assert.is_true(url_found)
  end)

  it("parses .yml file", function()
    local content = [[
server:
  port: 8080
spring:
  datasource:
    url: jdbc:mysql://localhost/db
  profiles:
    active: dev
]]
    local tmpfile = "/tmp/test-application.yml"
    local f = io.open(tmpfile, "w")
    f:write(content)
    f:close()

    local props = config_explorer.parse_yaml(content, tmpfile)
    assert.is_true(#props > 0)

    local port_found = false
    local url_found = false
    local profile_found = false
    for _, p in ipairs(props) do
      if p.key == "server.port" and p.value == "8080" then
        port_found = true
      end
      if p.key == "spring.datasource.url" and p.value:find("jdbc:mysql") then
        url_found = true
      end
      if p.key == "spring.profiles.active" and p.value == "dev" then
        profile_found = true
      end
    end
    assert.is_true(port_found)
    assert.is_true(url_found)
    assert.is_true(profile_found)
    os.remove(tmpfile)
  end)

  it("handles comments in .properties file", function()
    local content = [[
# This is a comment
server.port=9090
# another comment
spring.app.name=test
]]
    local props = config_explorer.parse_properties(content, "application.properties")
    assert.are.equal(#props, 2)
    assert.are.equal("server.port", props[1].key)
    assert.are.equal("9090", props[1].value)
  end)

  it("handles YAML with multiple levels", function()
    local content = [[
app:
  name: my-service
  version: 1.0.0
  database:
    host: localhost
    port: 5432
]]
    local tmpfile = "/tmp/test-multi.yml"
    local f = io.open(tmpfile, "w")
    f:write(content)
    f:close()

    local props = config_explorer.parse_yaml(content, tmpfile)
    assert.is_true(#props >= 3)

    local version_found = false
    for _, p in ipairs(props) do
      if p.key == "app.version" and p.value == "1.0.0" then
        version_found = true
      end
    end
    assert.is_true(version_found)
    os.remove(tmpfile)
  end)

  it("finds config files in standard locations", function()
    os.execute("mkdir -p /tmp/test-config-project/src/main/resources")
    local f = io.open("/tmp/test-config-project/src/main/resources/application.properties", "w")
    f:write("key=value")
    f:close()

    local files = config_explorer.find_config_files("/tmp/test-config-project")
    assert.is_true(#files > 0)
    local found = false
    for _, fp in ipairs(files) do
      if fp:match("application%.properties$") then
        found = true
        break
      end
    end
    assert.is_true(found)
    os.execute("rm -rf /tmp/test-config-project")
  end)
end)
