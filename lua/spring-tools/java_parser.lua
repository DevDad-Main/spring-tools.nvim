local M = {}

M.bean_annotations = {
  Component = "components",
  Service = "services",
  Repository = "repositories",
  Controller = "controllers",
  RestController = "controllers",
  Configuration = "configurations",
}

M.http_methods = {
  GetMapping = "GET",
  PostMapping = "POST",
  PutMapping = "PUT",
  DeleteMapping = "DELETE",
  PatchMapping = "PATCH",
}

-- predicate for bean-stereotype annotation names
local function is_bean_anno(name)
  return M.bean_annotations[name] ~= nil
end

local function is_mapping_anno(name)
  return M.http_methods[name] ~= nil or name == "RequestMapping"
end

-- Compile queries once
local function make_q(pattern)
  local ok, q = pcall(vim.treesitter.query.parse, "java", pattern)
  return ok and q or nil
end

local QUERIES = {}

-- Capture all class_declaration nodes
QUERIES.classes = make_q([[(class_declaration) @class]])

-- Capture all interface_declaration nodes
QUERIES.interfaces = make_q([[(interface_declaration) @iface]])

-- Capture all method_declaration nodes
QUERIES.methods = make_q([[(method_declaration) @method]])

-- Capture all enum_declaration nodes (can also have annotations)
QUERIES.enums = make_q([[(enum_declaration) @enum]])

-- Shared helper: create a temp buffer and parse Java with TS
function M.parse_file(file_path)
  local ok, lines = pcall(vim.fn.readfile, file_path)
  if not ok or not lines or #lines == 0 then return nil end
  return M.parse_lines(lines)
end

function M.parse_lines(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "java"
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "java")
  if not ok or not parser then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    return nil
  end
  local tree = parser:parse()[1]
  local root = tree:root()
  return {
    bufnr = bufnr,
    root = root,
    lines = lines,
    cleanup = function()
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end,
  }
end

-- Safely get node text
function M.node_text(node, bufnr)
  if not node then return "" end
  local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
  return ok and text or ""
end

-- Get the parent class/interface declaration that contains a node
function M.get_parent_type_decl(node)
  local n = node:parent()
  while n do
    local t = n:type()
    if t == "class_declaration" or t == "interface_declaration" or t == "enum_declaration" then
      return n, t
    end
    n = n:parent()
  end
  return nil, nil
end

-- Get the name identifier from a type declaration node
function M.get_type_name(type_node, bufnr)
  if not type_node then return nil end
  for i = 0, type_node:child_count() - 1 do
    local child = type_node:child(i)
    if child and child:type() == "identifier" then
      return M.node_text(child, bufnr)
    end
  end
  return nil
end

-- Extract all annotation names from a modifiers node
function M.get_annotations(modifiers_node, bufnr)
  local annos = {}
  if not modifiers_node then return annos end
  for i = 0, modifiers_node:child_count() - 1 do
    local child = modifiers_node:child(i)
    if not child then goto continue end
    local t = child:type()
    if t == "marker_annotation" then
      for j = 0, child:child_count() - 1 do
        local gc = child:child(j)
        if gc and gc:type() == "identifier" then
          table.insert(annos, { name = M.node_text(gc, bufnr), node = child })
        end
      end
    elseif t == "annotation" then
      for j = 0, child:child_count() - 1 do
        local gc = child:child(j)
        if gc and gc:type() == "identifier" then
          table.insert(annos, { name = M.node_text(gc, bufnr), node = child })
        end
      end
    end
    ::continue::
  end
  return annos
end

-- Get the modifiers child of a type or method declaration
function M.get_modifiers(node)
  for i = 0, node:child_count() - 1 do
    local child = node:child(i)
    if child and child:type() == "modifiers" then
      return child
    end
  end
  return nil
end

-- Extract the path string from an annotation that has annotation_argument_list
-- Handles: @GetMapping("/path"), @RequestMapping(value = "/path"), etc.
function M.extract_annotation_path(anno_node, bufnr)
  if not anno_node then return "" end
  local text = M.node_text(anno_node, bufnr)
  -- Simple regex on the annotation text (which is just 1 line)
  local path = text:match("%((.*)%)")
  if not path then return "" end
  path = path:gsub('"', ""):gsub("'", "")
  path = path:match("^%s*(.-)%s*$")
  local parts = vim.split(path, ",")
  for _, part in ipairs(parts) do
    part = part:gsub("^%s*(.-)%s*$", "%1")
    if not part:match("=") then
      return part
    end
    local val = part:match("value%s*=%s*(.*)")
    if val then
      return val:gsub('"', ""):gsub("'", "")
    end
  end
  return ""
end

-- Extract the HTTP method from a mapping annotation
function M.extract_annotation_method(anno_node, mapping_name, bufnr)
  if not anno_node then return "GET" end
  if mapping_name ~= "RequestMapping" then
    return M.http_methods[mapping_name] or "GET"
  end
  -- For @RequestMapping, extract method attribute
  local text = M.node_text(anno_node, bufnr)
  local method_str = text:match("method%s*=%s*RequestMethod%.(%w+)")
  if not method_str then
    method_str = text:match("method%s*=%s*(%w+)")
  end
  return method_str or "GET"
end

-- Collect all type declarations (class, interface, enum) from a parsed file
function M.collect_types(parsed)
  if not parsed then return {} end
  local types = {}
  local bufnr = parsed.bufnr

  local function add_type(type_node)
    local mods = M.get_modifiers(type_node)
    local annos = mods and M.get_annotations(mods, bufnr) or {}
    local name = M.get_type_name(type_node, bufnr)
    local sr, sc, er, ec = type_node:range()
    table.insert(types, {
      node = type_node,
      name = name,
      line = sr + 1,
      annotations = annos,
      kind = type_node:type(),
      start_line = sr,
      end_line = er,
    })
  end

  for id, node in QUERIES.classes:iter_captures(parsed.root, bufnr, 0, -1) do
    add_type(node)
  end
  for id, node in QUERIES.interfaces:iter_captures(parsed.root, bufnr, 0, -1) do
    add_type(node)
  end
  for id, node in QUERIES.enums:iter_captures(parsed.root, bufnr, 0, -1) do
    add_type(node)
  end

  return types
end

-- Collect all method declarations from a parsed file
function M.collect_methods(parsed, parent_type)
  if not parsed then return {} end
  local bufnr = parsed.bufnr
  local methods = {}

  if not parent_type then
    for id, node in QUERIES.methods:iter_captures(parsed.root, bufnr, 0, -1) do
      local mods = M.get_modifiers(node)
      local annos = mods and M.get_annotations(mods, bufnr) or {}
      local name = nil
      for i = 0, node:child_count() - 1 do
        local child = node:child(i)
        if child and child:type() == "identifier" then
          name = M.node_text(child, bufnr)
          break
        end
      end
      local sr, sc, er, ec = node:range()
      local parent, parent_kind = M.get_parent_type_decl(node)
      local parent_name = parent and M.get_type_name(parent, bufnr) or ""
      table.insert(methods, {
        node = node,
        name = name,
        line = sr + 1,
        annotations = annos,
        parent_name = parent_name,
        parent_kind = parent_kind,
      })
    end
  else
    -- Only collect methods within the specified type
    local class_body = nil
    for i = 0, parent_type.node:child_count() - 1 do
      local child = parent_type.node:child(i)
      if child and child:type() == "class_body" then
        class_body = child
        break
      end
    end
    if not class_body then return {} end
    for id, node in QUERIES.methods:iter_captures(class_body, bufnr, 0, -1) do
      local mods = M.get_modifiers(node)
      local annos = mods and M.get_annotations(mods, bufnr) or {}
      local name = nil
      for i = 0, node:child_count() - 1 do
        local child = node:child(i)
        if child and child:type() == "identifier" then
          name = M.node_text(child, bufnr)
          break
        end
      end
      local sr, sc, er, ec = node:range()
      table.insert(methods, {
        node = node,
        name = name,
        line = sr + 1,
        annotations = annos,
        parent_name = parent_type.name,
        parent_kind = parent_type.kind,
      })
    end
  end

  return methods
end

-- Check if a parsed Java file contains @SpringBootApplication
function M.has_spring_boot_application(parsed)
  if not parsed then return false end
  local types = M.collect_types(parsed)
  for _, t in ipairs(types) do
    for _, ann in ipairs(t.annotations) do
      if ann.name == "SpringBootApplication" then
        return true
      end
    end
  end
  return false
end

-- Find Spring bean classes in parsed file
-- Returns: list of { name, type (category), line, file, annotations }
function M.find_beans(parsed, file_path)
  if not parsed then return {} end
  local beans = {}
  local types = M.collect_types(parsed)
  for _, t in ipairs(types) do
    for _, ann in ipairs(t.annotations) do
      local cat = M.bean_annotations[ann.name]
      if cat then
        table.insert(beans, {
          name = t.name,
          type = cat,
          file = file_path,
          line = t.line,
          annotations = t.annotations,
        })
      end
    end
  end
  return beans
end

-- Find @Bean methods in parsed file  
-- Returns: list of { name, parent (class name), line, file }
function M.find_bean_methods(parsed, file_path)
  if not parsed then return {} end
  local bean_methods = {}
  local methods = M.collect_methods(parsed)
  for _, m in ipairs(methods) do
    for _, ann in ipairs(m.annotations) do
      if ann.name == "Bean" then
        table.insert(bean_methods, {
          name = m.name,
          parent = m.parent_name,
          file = file_path,
          line = m.line,
        })
      end
    end
  end
  return bean_methods
end

-- Find REST endpoints in parsed file
-- Returns: list of { method (HTTP), path, file, line, method_name }
function M.find_endpoints(parsed, file_path)
  if not parsed then return {} end
  local bufnr = parsed.bufnr
  local endpoints = {}

  -- First, collect all controller classes and their class-level @RequestMapping
  local types = M.collect_types(parsed)
  for _, t in ipairs(types) do
    local is_controller = false
    local class_base_path = ""

    for _, ann in ipairs(t.annotations) do
      if ann.name == "RestController" or ann.name == "Controller" then
        is_controller = true
      end
      if ann.name == "RequestMapping" then
        class_base_path = M.extract_annotation_path(ann.node, bufnr)
      end
    end

    if not is_controller then goto continue end

    -- Now find methods within this controller
    local methods = M.collect_methods(parsed, t)
    for _, m in ipairs(methods) do
      for _, ann in ipairs(m.annotations) do
        local http_method = M.http_methods[ann.name]
        if http_method or ann.name == "RequestMapping" then
          local method_path = M.extract_annotation_path(ann.node, bufnr)
          local full_path = class_base_path .. method_path
          if full_path == "" then full_path = "/" end
          local ep_method = M.extract_annotation_method(ann.node, ann.name, bufnr)
          table.insert(endpoints, {
            method = ep_method,
            path = full_path,
            file = file_path,
            line = m.line,
            method_name = m.name,
          })
        end
      end
    end
    ::continue::
  end

  return endpoints
end

-- Find test methods in parsed file
-- Returns: list of { name, line }
function M.find_test_methods_in_file(parsed)
  if not parsed then return {} end
  local test_methods = {}
  local methods = M.collect_methods(parsed)

  -- First check if the file has at least one @Test
  local has_test = false
  for _, m in ipairs(methods) do
    for _, ann in ipairs(m.annotations) do
      if ann.name == "Test" then
        has_test = true
        break
      end
    end
    if has_test then break end
  end
  if not has_test then return {} end

  for _, m in ipairs(methods) do
    for _, ann in ipairs(m.annotations) do
      if ann.name == "Test" then
        table.insert(test_methods, {
          name = m.name,
          line = m.line,
        })
      end
    end
  end

  return test_methods
end

-- Extract class name from parsed file
function M.find_class_name(parsed)
  if not parsed then return nil end
  local types = M.collect_types(parsed)
  if #types > 0 then return types[1].name end
  return nil
end

-- Extract package name from parsed file
function M.find_package_name(parsed)
  if not parsed then return nil end
  local bufnr = parsed.bufnr
  local q = vim.treesitter.query.parse("java", [[
  (package_declaration (scoped_identifier) @pkg)
  ]])
  for id, node in q:iter_captures(parsed.root, bufnr, 0, -1) do
    return M.node_text(node, bufnr)
  end
  return nil
end

-- Find the @Test method at a specific line (for run_current_test)
function M.find_test_method_at_line(parsed, line)
  if not parsed then return nil end
  local methods = M.collect_methods(parsed)
  for _, m in ipairs(methods) do
    local sr, sc, er, ec = m.node:range()
    if line >= sr + 1 and line <= er + 1 then
      for _, ann in ipairs(m.annotations) do
        if ann.name == "Test" then
          return m
        end
      end
    end
  end
  -- Fallback: return any method at or before the cursor line
  local nearest = nil
  for _, m in ipairs(methods) do
    if m.line <= line then
      nearest = m
    end
  end
  return nearest
end

-- Get the method name that's at or immediately following a @Test annotation at a given line
function M.get_test_method_at_or_after(parsed, line)
  if not parsed then return nil end
  local methods = M.collect_methods(parsed)
  local found = nil
  for _, m in ipairs(methods) do
    if m.line >= line then
      for _, ann in ipairs(m.annotations) do
        if ann.name == "Test" then
          found = m
        end
      end
    end
    if m.line >= line and found then break end
  end
  return found
end

return M
