local utils = require("spring-tools.utils")

local M = {}

M.phases = {
  "clean", "validate", "initialize", "generate-sources", "process-sources",
  "generate-resources", "process-resources", "compile", "process-classes",
  "generate-test-sources", "process-test-sources", "generate-test-resources",
  "process-test-resources", "test-compile", "process-test-classes", "test",
  "prepare-package", "package", "pre-integration-test", "integration-test",
  "post-integration-test", "verify", "install", "deploy", "site", "site-deploy",
}

local PLUGIN_GOALS = {
  ["maven-compiler-plugin"] = { "compile", "testCompile" },
  ["maven-surefire-plugin"] = { "test" },
  ["maven-failsafe-plugin"] = { "integration-test", "verify" },
  ["maven-jar-plugin"] = { "jar", "test-jar" },
  ["maven-war-plugin"] = { "war", "exploded" },
  ["maven-install-plugin"] = { "install", "install-file" },
  ["maven-deploy-plugin"] = { "deploy", "deploy-file" },
  ["maven-resources-plugin"] = { "resources", "testResources" },
  ["maven-surefire-report-plugin"] = { "report", "check" },
  ["maven-site-plugin"] = { "site", "deploy", "stage", "stage-deploy", "jar" },
  ["maven-clean-plugin"] = { "clean" },
  ["maven-javadoc-plugin"] = { "javadoc", "jar", "test-javadoc", "test-jar", "aggregate" },
  ["maven-source-plugin"] = { "jar", "test-jar", "aggregate" },
  ["maven-shade-plugin"] = { "shade" },
  ["maven-assembly-plugin"] = { "single" },
  ["maven-antrun-plugin"] = { "run" },
  ["maven-dependency-plugin"] = { "tree", "resolve", "sources", "analyze", "purge-local-repository", "copy-dependencies", "unpack-dependencies", "properties", "list" },
  ["maven-help-plugin"] = { "active-profiles", "effective-pom", "effective-settings", "describe", "system" },
  ["maven-enforcer-plugin"] = { "enforce", "display-info" },
  ["maven-release-plugin"] = { "prepare", "perform", "stage", "rollback", "clean" },
  ["maven-gpg-plugin"] = { "sign" },
  ["maven-pmd-plugin"] = { "check", "pmd", "cpd-check", "cpd" },
  ["maven-checkstyle-plugin"] = { "check", "checkstyle" },
  ["maven-spotbugs-plugin"] = { "check", "gui" },
  ["maven-jxr-plugin"] = { "jxr", "test-jxr" },
  ["maven-project-info-reports-plugin"] = { "info-reports", "dependencies", "summary" },
  ["maven-scm-plugin"] = { "checkout", "update", "status", "diff", "tag" },
  ["maven-eclipse-plugin"] = { "eclipse", "clean" },
  ["maven-idea-plugin"] = { "idea", "clean" },
  ["spring-boot-maven-plugin"] = { "run", "build-image", "repackage", "start", "stop" },
  ["jacoco-maven-plugin"] = { "prepare-agent", "report", "check" },
  ["spotbugs-maven-plugin"] = { "check", "spotbugs", "gui" },
  ["flyway-maven-plugin"] = { "migrate", "clean", "info", "validate", "baseline", "repair", "undo" },
  ["liquibase-maven-plugin"] = { "update", "rollback", "status", "diff", "tag", "dropAll" },
  ["exec-maven-plugin"] = { "java", "exec" },
  ["jetty-maven-plugin"] = { "run", "start", "stop", "run-exploded", "run-war" },
  ["tomcat7-maven-plugin"] = { "run", "deploy", "deploy-only", "undeploy" },
  ["tomcat9-maven-plugin"] = { "run", "deploy", "deploy-only", "undeploy" },
  ["cargo-maven2-plugin"] = { "run", "start", "stop", "deploy", "undeploy" },
  ["versions-maven-plugin"] = { "display-dependency-updates", "display-plugin-updates", "display-property-updates", "use-latest-releases", "use-next-releases", "set", "lock-snapshots", "unlock-snapshots" },
  ["sonar-maven-plugin"] = { "sonar" },
  ["nexus-staging-maven-plugin"] = { "deploy", "release", "close", "drop", "promote" },
  ["native-maven-plugin"] = { "compile", "compile-no-fork", "test-compile" },
  ["protobuf-maven-plugin"] = { "compile", "test-compile", "compile-custom" },
  ["os-maven-plugin"] = { "detect" },
  ["build-helper-maven-plugin"] = { "add-source", "add-test-source", "reserve-network-port", "timestamp-property" },
  ["properties-maven-plugin"] = { "read-project-properties", "write-project-properties", "set-system-properties" },
  ["cobertura-maven-plugin"] = { "cobertura", "check" },
  ["findbugs-maven-plugin"] = { "check", "findbugs", "gui" },
  ["liqibase-maven-plugin"] = { "update", "rollback", "status", "diff" },
  ["hibernate3-maven-plugin"] = { "ddl" },
  ["hibernate4-maven-plugin"] = { "ddl" },
  ["hibernate5-maven-plugin"] = { "ddl" },
  ["android-maven-plugin"] = { "aar", "apk", "apklib", "clean", "deploy", "dex", "emulator-start", "emulator-stop", "generate-sources", "instrument", "lint" },
  ["docker-maven-plugin"] = { "build", "start", "stop", "push", "remove" },
  ["dockerfile-maven-plugin"] = { "build", "tag", "push" },
  ["jib-maven-plugin"] = { "build", "buildTar", "dockerBuild", "exportDockerContext" },
  ["swagger-codegen-maven-plugin"] = { "generate" },
  ["openapi-generator-maven-plugin"] = { "generate", "help" },
  ["asciidoctor-maven-plugin"] = { "process-asciidoc" },
  ["frontend-maven-plugin"] = { "install-node-and-npm", "npm", "yarn", "gulp", "grunt", "bower" },
}

M.default_plugin_goals = {
  "spring-boot:run", "spring-boot:build-image", "spring-boot:repackage",
  "spring-boot:start", "spring-boot:stop",
  "dependency:tree", "dependency:resolve", "dependency:sources",
  "dependency:analyze", "dependency:purge-local-repository",
  "dependency:copy-dependencies", "dependency:unpack-dependencies",
  "surefire:test", "surefire-report:report", "surefire-report:check",
  "failsafe:integration-test", "failsafe:verify",
  "jacoco:report", "jacoco:prepare-agent", "jacoco:check",
  "checkstyle:check", "checkstyle:checkstyle",
  "pmd:check", "pmd:pmd", "pmd:cpd-check",
  "spotbugs:check", "spotbugs:spotbugs",
  "flyway:migrate", "flyway:clean", "flyway:info", "flyway:validate",
  "compiler:compile", "compiler:testCompile",
  "resources:resources", "resources:testResources",
  "war:war", "war:exploded", "jar:jar", "jar:test-jar",
  "install:install", "install:install-file",
  "deploy:deploy", "deploy:deploy-file",
  "exec:java", "exec:exec",
  "jetty:run", "jetty:start", "jetty:stop",
  "tomcat7:run", "tomcat7:deploy",
  "tomcat9:run", "tomcat9:deploy",
  "cargo:run", "cargo:start", "cargo:deploy",
  "help:active-profiles", "help:effective-pom", "help:effective-settings",
  "help:describe", "help:system",
  "enforcer:enforce", "enforcer:display-info",
  "versions:display-dependency-updates", "versions:display-plugin-updates",
  "versions:display-property-updates", "versions:use-latest-releases",
  "sonar:sonar",
  "nexus-staging:deploy", "nexus-staging:release",
  "liqibase:update", "liqibase:rollback", "liqibase:status",
  "native:compile", "native:compile-no-fork",
  "protobuf:compile", "protobuf:test-compile",
}

M.d_properties = {
  "-DskipTests", "-Dmaven.test.skip=true", "-Dmaven.test.failure.ignore=true",
  "-Dspring-boot.run.profiles=", "-Dspring-boot.run.arguments=",
  "-Dspring-boot.run.jvmArguments=", "-Dspring-boot.run.main-class=",
  "-Dcheckstyle.skip=true", "-Dpmd.skip=true", "-Dcpd.skip=true",
  "-Dspotbugs.skip=true", "-Djacoco.skip=true", "-Dcobertura.skip=true",
  "-Dfindbugs.skip=true", "-Denforcer.skip=true", "-Dlicense.skip=true",
  "-Dmaven.javadoc.skip=true", "-Dmaven.source.skip=true",
  "-Dproject.build.sourceEncoding=UTF-8", "-Dskip.it=true",
  "-Dit.test=", "-Dtest=", "-DfailIfNoTests=false",
  "-Dmaven.repo.local=", "-DoutputDirectory=", "-DfinalName=",
  "-Djar.finalName=", "-Dmaven.compiler.source=", "-Dmaven.compiler.target=",
  "-Dmaven.compiler.release=", "-Dmaven.compiler.showWarnings=",
}

M.gradle_tasks = {
  "build", "check", "clean", "compileJava", "compileTestJava",
  "jar", "javadoc", "test", "classes", "testClasses",
  "bootRun", "bootJar", "bootWar", "bootBuildImage",
  "dependencies", "dependencyInsight", "properties", "tasks", "help",
  "assemble", "buildHealth", "format", "verify", "lint",
  "spotlessApply", "spotlessCheck",
  "jacocoTestReport", "jacocoTestCoverageVerification",
  "checkstyleMain", "checkstyleTest", "pmdMain", "pmdTest",
  "cpdCheck", "testReport", "testCoverage",
  "findbugsMain", "findbugsTest", "sonarqube",
  "buildDependents", "buildNeeded", "cleanEclipse", "cleanIdea",
  "eclipse", "idea", "wrapper",
}

M.gradle_d_properties = {
  "-Dtest=", "-Dtests=", "-Dorg.gradle.daemon=true",
  "-Dorg.gradle.jvmargs=", "-Dorg.gradle.parallel=true",
  "-Dorg.gradle.caching=true", "-Dorg.gradle.configureondemand=true",
  "-Dorg.gradle.debug=true", "-Dorg.gradle.warning.mode=",
}

local PLUGIN_CACHE = {}
local DYNAMIC_CACHE = {}
local PENDING = {}

local function find_mvn_cmd(root)
  local mvnw = root .. "/mvnw"
  if vim.fn.executable(mvnw) == 1 then
    return { mvnw }
  end
  return { "mvn" }
end

local function parse_effective_pom(text)
  local plugins = {}
  for plugin_block in text:gmatch("<plugin>(.-)</plugin>") do
    local aid = plugin_block:match("<artifactId>(.-)</artifactId>")
    if aid then
      plugins[#plugins + 1] = aid
    end
  end
  return plugins
end

local function parse_describe_output(lines)
  local goals = {}
  local capturing = false
  for _, line in ipairs(lines) do
    local stripped = line:match("^%[INFO%]%s*(.*)$") or line
    if capturing then
      if stripped:find("For more information", 1, true) then
        capturing = false
      else
        local goal = stripped:match("^%s*([%w][%w%.%-_]*:[%w][%w%.%-_]*)%s*$")
        if goal and not goal:match(":.*:") then
          goals[#goals + 1] = goal
        end
      end
    elseif stripped:find("has %d+ goal") then
      capturing = true
    end
  end
  return goals
end

local function artifact_to_prefix(artifact_id)
  local prefix = artifact_id:match("^(.+)%-maven%-plugin$")
  if prefix then return prefix end
  prefix = artifact_id:match("^maven%-(.+)%-plugin$")
  if prefix then return prefix end
  prefix = artifact_id:match("^(.+)%-plugin$")
  if prefix then return prefix end
  prefix = artifact_id:match("^(.+)%-maven$")
  if prefix then return prefix end
  return artifact_id
end

local function fetch_async(root)
  if PENDING[root] then return end
  PENDING[root] = true

  local name = vim.fn.fnamemodify(root, ":t")
  vim.schedule(function()
    vim.notify("[spring-tools] Discovering Maven goals for " .. name .. " (async)", vim.log.levels.INFO)
  end)

  local mvn = find_mvn_cmd(root)
  local stdout = {}

  vim.fn.jobstart(vim.list_extend(vim.deepcopy(mvn), { "help:effective-pom" }), {
    cwd = root,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        stdout[#stdout + 1] = line
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        stdout[#stdout + 1] = line
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 or #stdout == 0 then
        vim.schedule(function()
          vim.notify("[spring-tools] Maven effective-pom failed for " .. name .. " (exit " .. code .. ")", vim.log.levels.WARN)
        end)
        PENDING[root] = nil
        return
      end

      local text = table.concat(stdout, "\n")
      local plugins = parse_effective_pom(text)

      local unknown = {}
      for _, aid in ipairs(plugins) do
        if not PLUGIN_GOALS[aid] then
          unknown[#unknown + 1] = { aid = aid, prefix = artifact_to_prefix(aid) }
        end
      end

      vim.schedule(function()
        vim.notify("[spring-tools] " .. name .. ": " .. #plugins .. " plugins found, " .. #unknown .. " not in hardcoded table", vim.log.levels.INFO)
      end)

      if #unknown == 0 then
        -- Persist empty result so we don't re-fetch
        local cache_key = "mvn_dynamic_goals:" .. root
        if not utils.cache.data then utils.cache.data = {} end
        utils.cache.data[cache_key] = { goals = {}, pom_mtime = vim.fn.getftime(root .. "/pom.xml") }
        utils.mark_dirty()
        utils.save_cache()
        DYNAMIC_CACHE[root] = {}
        PENDING[root] = nil
        return
      end

      local dynamic = {}
      local completed = 0
      local cmd_base = find_mvn_cmd(root)

      for _, plugin in ipairs(unknown) do
        local out = {}
        vim.fn.jobstart(vim.list_extend(vim.deepcopy(cmd_base), { "help:describe", "-Dplugin=" .. plugin.prefix }), {
          cwd = root,
          stdout_buffered = true,
          stderr_buffered = true,
          on_stdout = function(_, data)
            for _, line in ipairs(data) do
              out[#out + 1] = line
            end
          end,
          on_stderr = function(_, data)
            for _, line in ipairs(data) do
              out[#out + 1] = line
            end
          end,
          on_exit = function(_, exit_code)
            completed = completed + 1
            if exit_code == 0 then
              local goals = parse_describe_output(out)
              for _, g in ipairs(goals) do
                dynamic[#dynamic + 1] = g
              end
            end
            if completed == #unknown then
              vim.schedule(function()
                vim.notify("[spring-tools] " .. name .. ": discovered " .. #dynamic .. " dynamic goals from " .. #unknown .. " plugins", vim.log.levels.INFO)
              end)
              DYNAMIC_CACHE[root] = dynamic
              local cache_key = "mvn_dynamic_goals:" .. root
              if not utils.cache.data then utils.cache.data = {} end
              utils.cache.data[cache_key] = { goals = dynamic, pom_mtime = vim.fn.getftime(root .. "/pom.xml") }
              utils.mark_dirty()
              utils.save_cache()
              PLUGIN_CACHE[root] = nil
              PENDING[root] = nil
            end
          end,
        })
      end
    end,
  })
end

local function parse_pom(root)
  local pom_path = root .. "/pom.xml"
  local ok, lines = pcall(vim.fn.readfile, pom_path)
  if not ok or not lines or #lines == 0 then return {} end
  local text = table.concat(lines, "\n")
  local artifact_ids = {}
  for plugin_block in text:gmatch("<plugin>(.-)</plugin>") do
    local aid = plugin_block:match("<artifactId>(.-)</artifactId>")
    if aid then
      artifact_ids[#artifact_ids + 1] = aid
    end
  end
  return artifact_ids
end

function M.get_plugin_goals(root)
  if PLUGIN_CACHE[root] then return PLUGIN_CACHE[root] end
  local artifact_ids = parse_pom(root)
  local seen = {}
  local goals = {}
  for _, g in ipairs(M.default_plugin_goals) do
    goals[#goals + 1] = g
    seen[g] = true
  end
  -- Load dynamic cache early so we can skip placeholders for resolved plugins
  local dynamic = DYNAMIC_CACHE[root]
  if not dynamic then
    local cache_key = "mvn_dynamic_goals:" .. root
    local entry = utils.cache.data and utils.cache.data[cache_key]
    if entry then
      dynamic = type(entry) == "table" and entry.goals or entry
      DYNAMIC_CACHE[root] = dynamic
    end
  end
  for _, aid in ipairs(artifact_ids) do
    local known_goals = PLUGIN_GOALS[aid]
    local prefix = artifact_to_prefix(aid)
    if known_goals then
      for _, g in ipairs(known_goals) do
        local prefixed = prefix .. ":" .. g
        if not seen[prefixed] then
          goals[#goals + 1] = prefixed
          seen[prefixed] = true
        end
      end
    else
      local has_dynamic = false
      if dynamic then
        for _, dg in ipairs(dynamic) do
          if dg:find(prefix .. ":", 1, true) then
            has_dynamic = true
            break
          end
        end
      end
      if not has_dynamic then
        local prefixed = prefix .. ":"
        if not seen[prefixed] then
          goals[#goals + 1] = prefixed
          seen[prefixed] = true
        end
      end
    end
  end
  -- Merge dynamically discovered goals from cache
  if dynamic then
    for _, g in ipairs(dynamic) do
      if not seen[g] then
        goals[#goals + 1] = g
        seen[g] = true
      end
    end
  end
  PLUGIN_CACHE[root] = goals
  return goals
end

function M.fetch_dynamic_goals(roots)
  if type(roots) == "string" then roots = { roots } end
  for _, root in ipairs(roots) do
    if DYNAMIC_CACHE[root] then
      -- Already loaded in memory, skip
    else
      local cache_key = "mvn_dynamic_goals:" .. root
      local entry = utils.cache.data and utils.cache.data[cache_key]
      if entry then
        local goals, stored_mtime
        if type(entry) == "table" and entry.goals then
          goals = entry.goals
          stored_mtime = entry.pom_mtime
        else
          goals = entry
          stored_mtime = nil
        end
        local current_mtime = vim.fn.getftime(root .. "/pom.xml")
        if stored_mtime ~= nil and current_mtime ~= -1 and stored_mtime ~= current_mtime then
          -- POM changed, invalidate and re-fetch
          utils.cache.data[cache_key] = nil
          DYNAMIC_CACHE[root] = nil
          fetch_async(root)
        else
          DYNAMIC_CACHE[root] = goals
        end
      else
        fetch_async(root)
      end
    end
  end
end

function M.invalidate_cache(root)
  if root then
    PLUGIN_CACHE[root] = nil
    DYNAMIC_CACHE[root] = nil
  else
    PLUGIN_CACHE = {}
    DYNAMIC_CACHE = {}
  end
end

return M
