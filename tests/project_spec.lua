local path = "."
package.path = package.path .. ";" .. path .. "/lua/?.lua"

describe("Project detection", function()
  local project = require("spring-tools.project")
  local utils = require("spring-tools.utils")

  before_each(function()
    os.execute("rm -rf /tmp/test-spring-project")
    os.execute("mkdir -p /tmp/test-spring-project")
  end)

  after_each(function()
    os.execute("rm -rf /tmp/test-spring-project")
  end)

  it("detects Maven project by pom.xml", function()
    local f = io.open("/tmp/test-spring-project/pom.xml", "w")
    f:write('<project><groupId>com.test</groupId></project>')
    f:close()

    local root = utils.find_project_root("/tmp/test-spring-project")
    assert.are.equal("/tmp/test-spring-project", root)
  end)

  it("detects Gradle project by build.gradle", function()
    local f = io.open("/tmp/test-spring-project/build.gradle", "w")
    f:write('plugins { id "java" }')
    f:close()

    local root = utils.find_project_root("/tmp/test-spring-project")
    assert.are.equal("/tmp/test-spring-project", root)
  end)

  it("detects Gradle Kotlin DSL by build.gradle.kts", function()
    local f = io.open("/tmp/test-spring-project/build.gradle.kts", "w")
    f:write('plugins { java }')
    f:close()

    local root = utils.find_project_root("/tmp/test-spring-project")
    assert.are.equal("/tmp/test-spring-project", root)
  end)

  it("returns nil for non-project directory", function()
    os.execute("mkdir -p /tmp/test-empty-dir")
    local root = utils.find_project_root("/tmp/test-empty-dir")
    assert.is_nil(root)
    os.execute("rm -rf /tmp/test-empty-dir")
  end)

  it("detects @SpringBootApplication annotation", function()
    os.execute("mkdir -p /tmp/test-spring-project/src/main/java")
    local f = io.open("/tmp/test-spring-project/pom.xml", "w")
    f:write('<project></project>')
    f:close()

    local sf = io.open("/tmp/test-spring-project/src/main/java/Application.java", "w")
    sf:write([[
package com.test;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
]])
    sf:close()

    local has_boot = project.detect_spring_boot("/tmp/test-spring-project")
    assert.is_true(has_boot)
  end)

  it("identifies Maven build type", function()
    local f = io.open("/tmp/test-spring-project/pom.xml", "w")
    f:write('<project></project>')
    f:close()

    local bt = utils.build_type("/tmp/test-spring-project")
    assert.are.equal("maven", bt)
  end)

  it("identifies Gradle build type", function()
    local f = io.open("/tmp/test-spring-project/build.gradle", "w")
    f:write('plugins { id "java" }')
    f:close()

    local bt = utils.build_type("/tmp/test-spring-project")
    assert.are.equal("gradle", bt)
  end)
end)
