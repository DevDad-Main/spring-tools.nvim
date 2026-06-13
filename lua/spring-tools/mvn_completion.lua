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

local function artifact_to_prefix(artifact_id)
  local prefix = artifact_id:match("^(.+)%-maven%-plugin$")
  if prefix then return prefix end
  prefix = artifact_id:match("^maven%-(.+)%-plugin$")
  if prefix then return prefix end
  prefix = artifact_id:match("^(.+)%-plugin$")
  if prefix then return prefix end
  return artifact_id
end

local function parse_pom(root)
  local pom_path = root .. "/pom.xml"
  local lines = vim.fn.readfile(pom_path)
  if not lines or #lines == 0 then return {} end
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
  local goals = {}
  for _, aid in ipairs(artifact_ids) do
    local known_goals = PLUGIN_GOALS[aid]
    local prefix = artifact_to_prefix(aid)
    if known_goals then
      for _, g in ipairs(known_goals) do
        goals[#goals + 1] = prefix .. ":" .. g
      end
    else
      goals[#goals + 1] = prefix .. ":"
    end
  end
  PLUGIN_CACHE[root] = goals
  return goals
end

function M.invalidate_cache(root)
  if root then
    PLUGIN_CACHE[root] = nil
  else
    PLUGIN_CACHE = {}
  end
end

return M
