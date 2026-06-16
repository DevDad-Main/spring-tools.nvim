## Goal
- Replace regex-based Java heuristic parsing with Tree-sitter AST queries for Spring Boot artifact detection (beans, endpoints, tests, config), fix performance/caching/ui issues, create responsive async-loading tab system, add Actuator endpoint browser within Endpoints tab, and build multi-project workspace support.

## Constraints & Preferences
- Must preserve existing data structures and caching mechanism so consumers (search, views, sidebar) work unchanged.
- Must keep `endpoints.extract_path` and `endpoints.determine_method` for backward compatibility with existing tests.
- Tree-sitter Java parser must be available (Neovim built-in, v0.10+).
- Multi-project workspace UI must degrade gracefully to single-project mode when only one project is detected — no visual change.
- Plugin must remain performant and stable with lazy scanning, persistent cache, deferred loading, and mtime validation.
- Highlight `SpringToolsSectionHeader` is used for project headers in all views; customizable via `:hi SpringToolsSectionHeader`.

## Progress
### Done
- Created feature branch `feat/tree-sitter-java-parsing`, merged to main.
- Created `lua/spring-tools/java_parser.lua` — core Tree-sitter query module with hybrid TS+regex approach.
- Updated all consumer modules to use `java_parser`: `beans.lua`, `endpoints.lua`, `tests.lua`, `project.lua`, `commands.lua`.
- All 18 relevant tests pass (annotation_spec, endpoint_spec, project_spec). 4 config_spec failures are pre-existing and unrelated.
- README.md updated with actuator preview section, Dotfyle badge.
- Performance fixes: async loading, mtime-validated caches, header counting from items not re-scanning.
- Created and merged Actuator endpoint browser into Endpoints tab (`feat/actuator-browser`).
- Created feature branch `feat/multi-project-workspace` (all commits on branch):
  - `utils.find_all_project_roots(dir)` — shallow BFS scan, stops at first project root then scans immediate children only. Skips `.git`, `node_modules`, `target`, `build`.
  - `utils.get_maven_child_modules(root)` and `utils.get_gradle_child_modules(root)` — read build files to find declared sub-modules.
  - `project.lua`: workspace detection, `is_multi_project()`, `get_workspace_projects()`, `find_project_for_file()`, per-project `get_backend_for_project()` with priority. Parent-child tree built from Maven `<module>` / Gradle `include` declarations (not path prefix).
  - `state.lua`: `workspace_root` concept.
  - `project.build_entry` accepts cached entry to skip expensive `detect_spring_boot` Tree-sitter scan on subsequent startups.
  - **Dashboard view**: virtual parent header when workspace root is not a detected project (e.g. container folder with Docker compose). Foldable ▸/▾ with indented children. 2-space indent per level, 2-space active_mark. Docker commands in action menu.
  - **All views** (beans, tests, config, endpoints): project headers are foldable ▸/▾ on Enter, use `SpringToolsSectionHeader` highlight. Children indented 2+ spaces in multi-project mode. Section collapse keys scoped per project.
  - Single-project mode unchanged in all views.

### In Progress
- (none)

### Blocked
- (none)

## Key Decisions
- Maven `<module>` / Gradle `include` declarations determine parent-child relationships — NOT path prefix. Prevents co-located non-module projects from being treated as children.
- `find_all_project_roots` stops at first project root, then scans only immediate children (1 level deep) to avoid CPU freeze on large directory trees.
- Spring Boot detection (`has_spring_boot`) cached across restarts via project cache file to eliminate startup freeze.
- `SpringToolsSectionHeader` highlight used for all project headers (folders). User-customizable.

## Next Steps
1. Push and merge `feat/multi-project-workspace` branch to main.
2. Test multi-project workspace end-to-end with a real microservice setup.
3. Consider `Dockerfile` / `docker-compose.yml` auto-detection for future Docker backend.

## Critical Context
- `iter_matches` in Neovim 0.12.2 fails; `iter_captures` works reliably.
- Java `#match?` predicate only matches once per pattern — use `#eq?` or walk tree manually.
- All consumer modules keep their original cache keys so cache invalidation works seamlessly.
- Config_spec 4 existing failures are unrelated.
- Virtual parent header created when workspace root is not a detected project but contains sub-projects.

## Relevant Files
- `lua/spring-tools/java_parser.lua`: Core Tree-sitter module.
- `lua/spring-tools/actuator.lua`: Static actuator endpoint definitions.
- `lua/spring-tools/project.lua`: Workspace/multi-project detection, module-based parent-child tree, cached spring boot detection.
- `lua/spring-tools/utils.lua`: `find_all_project_roots`, `get_child_modules`, `get_maven_child_modules`, `get_gradle_child_modules`.
- `lua/spring-tools/core/state.lua`: `workspace_root` in state.
- `lua/spring-tools/ui/views/dashboard.lua`: Virtual parent header, foldable project headers, indent, Docker commands.
- `lua/spring-tools/ui/views/beans.lua`: Multi-project with foldable project headers, per-project section keys, proper bean indent nesting.
- `lua/spring-tools/ui/views/tests.lua`: Multi-project with foldable project headers, per-project test classes.
- `lua/spring-tools/ui/views/config.lua`: Multi-project with foldable project headers, per-project config sections.
- `lua/spring-tools/ui/views/endpoints.lua`: Multi-project with foldable project headers, per-project REST/Actuator sections.
- `lua/spring-tools/ui/components.lua`: `SpringToolsSectionHeader` highlight.
