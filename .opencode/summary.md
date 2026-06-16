## Goal
- Replace regex-based Java heuristic parsing with Tree-sitter AST queries for Spring Boot artifact detection (beans, endpoints, tests, config), fix performance/caching/ui issues, create responsive async-loading tab system, add Actuator endpoint browser within Endpoints tab, and build multi-project workspace support.

## Constraints & Preferences
- Must preserve existing data structures and caching mechanism so consumers (search, views, sidebar) work unchanged.
- Must keep `endpoints.extract_path` and `endpoints.determine_method` for backward compatibility with existing tests.
- Tree-sitter Java parser must be available (Neovim built-in, v0.10+).
- Multi-project workspace UI must degrade gracefully to single-project mode when only one project is detected — no visual change for monorepos, no need to redo screenshots/GIFs.
- Plugin must remain performant and stable with lazy scanning, persistent cache, deferred loading, and mtime validation.

## Progress
### Done
- Created feature branch `feat/tree-sitter-java-parsing`, merged to main.
- Created `lua/spring-tools/java_parser.lua` — core Tree-sitter query module with hybrid TS+regex approach.
- Updated all consumer modules to use `java_parser`: `beans.lua`, `endpoints.lua`, `tests.lua`, `project.lua`, `commands.lua`.
- All 18 relevant tests pass (annotation_spec, endpoint_spec, project_spec). 4 config_spec failures are pre-existing and unrelated.
- Updated README.md limitation from "regex heuristics" to "Tree-sitter AST queries".
- Fixed `utils.save_cache()` — added `vim.fn.mkdir` to ensure cache directory exists before writing.
- Fixed `project.remove_project()` (d key) — now clears ALL per-project cache entries plus build_completion and tests caches.
- Added progress notifications during Maven dynamic goal discovery.
- Fixed tests tab freeze — `header()` counts from `M.items` instead of re-scanning all Java files on every keystroke. Same fix applied to beans and endpoints headers.
- Added disk-persisted test methods cache with mtime validation (`test_index:` key stores `{tests, mtimes}`).
- Added `M._test_cache` for in-memory test method caching.
- Fixed config diff close — restores original file buffer in `win_a` and closes the split window `win_b`.
- Fixed curl response close — `main_win` and `orig_buf` captured synchronously in `_send_resolved` (at send-time, not asynchronously at response-time); removed `bufhidden = "wipe"` to prevent premature auto-deletion.
- Added async first-load to beans, endpoints, and tests views — shows "Indexing..." item and defers actual scan via `vim.defer_fn`.
- Updated annotation_spec and endpoint_spec tests to use temp project directories with pom.xml (fixes test isolation).
- Created and merged Actuator endpoint browser into Endpoints tab (`feat/actuator-browser` branch, merged to main):
  - `lua/spring-tools/actuator.lua` — static definitions for 13 actuator endpoint groups.
  - Endpoints view rewritten with two collapsible main sections: "REST Endpoints" and "Actuator Endpoints", each with independently collapsible sub-headers.
  - "Jump to definition" only shown for source-backed REST endpoints.
  - Path variable resolution via prompt for actuator endpoints.
  - Port detection from per-project running process or config.
  - Added `SpringToolsSectionHeader` highlight.
- Added Dotfyle shield badge to README.
- README updated with actuator preview section, updated feature description, and architecture tree entry for `actuator.lua`.
- Created and completed feature branch `feat/multi-project-workspace`, all commits made:
  - `utils.find_all_project_roots(dir)` — scans subdirectories for all build files.
  - `project.lua` rewritten with workspace detection, `is_multi_project()`, `get_workspace_projects()`, `find_project_for_file()`, per-project `get_backend_for_project()` with priority ordering.
  - `state.lua` updated with `workspace_root` concept.
  - Dashboard view shows workspace container when >1 project; projects nested underneath.
  - Endpoints view groups by project when multi-project (section keys scoped per project).
  - Beans view scans all projects when multi-project, groups beans per project with project headers.
  - Tests view discovers test classes per project, shows project headers and per-project "Run all tests".
  - Config view scans each project independently, groups properties per project with prefixed collapse keys for isolation.
  - Docker commands added to dashboard action menu (build, compose, ps, logs) for both stopped and running states.
  - All views degrade gracefully to single-project mode (identical UI).

### In Progress
- (none — all tasks on `feat/multi-project-workspace` are committed)

### Blocked
- (none)

## Key Decisions
- Used two-query approach for classes + annotations separately rather than one combined query.
- Hybrid: TS for structural tree walking, regex for extracting path/method from scoped annotation node text.
- Java `marker_annotation` (no `()`) and `annotation` (with `()`) are distinct TS node types; `java_parser.get_annotations` checks both.
- Temp buffer + `vim.treesitter.get_parser(bufnr, "java")` + `tree:root()` used for parsing.
- Captured `main_win`/`orig_buf` at send-time (synchronously in `_send_resolved`) rather than at response-time.
- Used `vim.defer_fn` for async loading in views instead of coroutines or jobstart.
- Removed `bufhidden = "wipe"` from curl response buffer — caused premature auto-deletion.
- Actuator endpoints merged into Endpoints tab (not separate tab).
- Multi-project workspace detection uses BFS-style scan of subdirectories.
- Single-project mode retains identical UI to before — no project headers, no grouping, no visual change.
- Section keys in views scoped per project root to prevent cross-project collapse state conflicts.

## Next Steps
1. Push and merge `feat/multi-project-workspace` branch to main.
2. Test multi-project workspace end-to-end with a real microservice setup.
3. Consider how to handle `Dockerfile` or `docker-compose.yml` auto-detection in future.

## Critical Context
- `iter_matches` in Neovim 0.12.2 fails with `attempt to call method 'range' (a nil value)`; `iter_captures` works reliably.
- Java `#match?` predicate only matches once per pattern — use `#eq?` or walk tree manually.
- All consumer modules keep their original cache keys (`bean_index:`, `endpoint_index:`) so cache invalidation works seamlessly.
- `vim.bo[buf].hidden` is NOT a valid buffer option — use `vim.api.nvim_buf_is_valid()` instead.
- Config_spec 4 existing failures are unrelated to this work.
- `find_all_project_roots` skips `.git`, `node_modules`, `target`, `build` during workspace scanning.

## Relevant Files
- `lua/spring-tools/java_parser.lua`: Core Tree-sitter module.
- `lua/spring-tools/actuator.lua`: Static actuator endpoint definitions (13 groups).
- `lua/spring-tools/beans.lua`: Updated to use `java_parser`; multi-project grouping.
- `lua/spring-tools/endpoints.lua`: Updated with REST + Actuator sections; multi-project grouping.
- `lua/spring-tools/tests.lua`: Updated with disk-cached `test_index:`; multi-project grouping.
- `lua/spring-tools/project.lua`: Workspace detection, multi-project support, per-project backends with priority.
- `lua/spring-tools/core/state.lua`: `workspace_root` in `set_projects`; `get_workspace_root()`.
- `lua/spring-tools/ui/views/dashboard.lua`: Workspace nesting; action menu with common cmds, Docker, auto-restart, config.
- `lua/spring-tools/ui/views/endpoints.lua`: Single/multi-project branching; per-project collapsible sections.
- `lua/spring-tools/ui/views/beans.lua`: Multi-project grouping with project headers.
- `lua/spring-tools/ui/views/tests.lua`: Multi-project grouping; per-project "Run all tests".
- `lua/spring-tools/ui/views/config.lua`: Multi-project grouping with prefixed collapse keys.
- `lua/spring-tools/utils.lua`: `find_all_project_roots` for workspace scanning; `save_cache` ensures dir exists.
- `lua/spring-tools/build_completion.lua`: Progress notifications during dynamic goal discovery.
- `lua/spring-tools/commands.lua`: Updated `run_current_test` with `java_parser`.
- `lua/spring-tools/config_diff.lua`: Close handler restores `orig_buf` to `win_a`, closes `win_b`.
- `lua/spring-tools/http_client.lua`: `_send_resolved` captures `main_win`/`orig_buf` at send-time.
- `lua/spring-tools/ui/components.lua`: Added `SpringToolsSectionHeader` highlight.
