local utils = require("spring-tools.utils")

local M = {}

local BASE_URL = "https://start.spring.io"
local API_ACCEPT = "application/vnd.initializr.v2.3+json"

local function ensure_cache()
  if not utils.cache.data then
    utils.load_cache()
  end
  if not utils.cache.data.initializer then
    utils.cache.data.initializer = {}
  end
end

local function cache_get(key)
  ensure_cache()
  return utils.cache.data.initializer[key]
end

local function cache_set(key, value)
  ensure_cache()
  utils.cache.data.initializer[key] = value
  utils.mark_dirty()
end

local function curl_get(url, on_done)
  local header_arg = "-H"
  local header_val = "Accept: " .. API_ACCEPT
  local chunks = {}
  local stderr_chunks = {}
  local job_id = utils.job_start(
    { "curl", "-s", "-L", "-S", header_arg, header_val, "-A", "spring-tools.nvim/1.0", url },
    {
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line and line ~= "" then
              table.insert(chunks, line)
            end
          end
        end
      end,
      on_stderr = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line and line ~= "" then
              table.insert(stderr_chunks, line)
            end
          end
        end
      end,
      on_exit = function(_, code)
        local text = table.concat(chunks, "\n")
        if code ~= 0 then
          local err = "curl exited with code " .. tostring(code)
          if #stderr_chunks > 0 then
            err = err .. ": " .. table.concat(stderr_chunks, " ")
          end
          on_done(nil, err)
          return
        end
        if text == "" then
          local err = "empty response from " .. url
          if #stderr_chunks > 0 then
            err = err .. " — stderr: " .. table.concat(stderr_chunks, " ")
          end
          on_done(nil, err)
          return
        end
        local ok, decoded = pcall(vim.json.decode, text)
        if not ok then
          local snippet = text:sub(1, 200)
          on_done(nil, "Failed to parse JSON from " .. url .. ": " .. tostring(decoded) .. " — body: " .. snippet)
          return
        end
        on_done(decoded, nil)
      end,
    }
  )
  return job_id
end

-- Fetch full metadata (project types, languages, boot versions, java versions)
function M.fetch_metadata(on_done)
  local cached = cache_get("metadata")
  if cached then
    on_done(cached, nil)
    return
  end
  curl_get(BASE_URL, function(result, err)
    if err then
      on_done(nil, err)
      return
    end
    cache_set("metadata", result)
    on_done(result, nil)
  end)
end

-- Fetch dependencies for a specific boot version
function M.fetch_dependencies(boot_version, on_done)
  local cache_key = "deps:" .. boot_version
  local cached = cache_get(cache_key)
  if cached then
    on_done(cached, nil)
    return
  end
  local url = BASE_URL .. "/dependencies?bootVersion=" .. url_encode(boot_version)
  curl_get(url, function(result, err)
    if err then
      on_done(nil, err)
      return
    end
    cache_set(cache_key, result)
    on_done(result, nil)
  end)
end

-- URL-encode a single value (encodes special chars but not URL structure)
local function url_encode(str)
  if not str then return "" end
  return (str:gsub("([^%w%._%-%~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

-- Build the starter.zip generation URL
function M.generate_url(params)
  local parts = {}
  local function append(key, value)
    if value and value ~= "" then
      table.insert(parts, key .. "=" .. url_encode(tostring(value)))
    end
  end
  append("type", params.type)
  append("groupId", params.groupId)
  append("artifactId", params.artifactId)
  append("name", params.name or params.artifactId)
  append("description", params.description)
  append("packageName", params.packageName)
  append("packaging", params.packaging)
  append("javaVersion", params.javaVersion)
  append("language", params.language)
  append("bootVersion", params.bootVersion)
  if params.dependencies and #params.dependencies > 0 then
    append("dependencies", table.concat(params.dependencies, ","))
  end
  return BASE_URL .. "/starter.zip?" .. table.concat(parts, "&")
end

-- Download zip to a temp file, then extract to target_dir
function M.generate_project(params, target_dir, on_done)
  local url = M.generate_url(params)
  local tmp_zip = vim.fn.tempname() .. ".zip"

  utils.notify("Downloading project from start.spring.io ...")

  local job_id = utils.job_start(
    { "curl", "-s", "-L", "-A", "spring-tools.nvim/1.0", "-o", tmp_zip, url },
    {
      on_exit = function(_, code)
        if code ~= 0 then
          on_done("download failed (curl exit " .. tostring(code) .. ")")
          return
        end
        -- Verify the zip file exists and has content
        local f = io.open(tmp_zip, "rb")
        if not f then
          on_done("download failed: could not read temp file")
          return
        end
        local size = f:seek("end")
        f:close()
        if size < 100 then
          os.remove(tmp_zip)
          on_done("download failed: file too small (" .. size .. " bytes) — check network/proxy")
          return
        end
        utils.notify("Extracting project (" .. size .. " bytes) ...")
        -- Extract to a temp dir, then move to target_dir.
        -- Using a temp dir ensures a clean result even if target_dir already has files.
        local extract_dir = vim.fn.tempname() .. "_extract"
        vim.fn.mkdir(extract_dir, "p")
        utils.job_start(
          { "unzip", "-q", "-o", tmp_zip, "-d", extract_dir },
          {
            on_exit = function(_, ucode)
              os.remove(tmp_zip)
              if ucode ~= 0 then
                vim.fn.delete(extract_dir, "rf")
                on_done("unzip failed (exit " .. tostring(ucode) .. ")")
                return
              end
              -- Flatten single top-level directory if present
              local scan = vim.fn.readdir(extract_dir)
              if not scan or #scan == 0 then
                vim.fn.delete(extract_dir, "rf")
                on_done("zip extracted but produced no files")
                return
              end
              local src_dir = extract_dir
              if #scan == 1 and vim.fn.isdirectory(extract_dir .. "/" .. scan[1]) == 1 then
                src_dir = extract_dir .. "/" .. scan[1]
              end
              -- Remove existing target_dir if present, then move extracted content in place
              if vim.fn.isdirectory(target_dir) == 1 then
                vim.fn.delete(target_dir, "rf")
              end
              vim.fn.mkdir(target_dir, "p")
              -- Copy all extracted items into target_dir
              local items = vim.fn.readdir(src_dir) or {}
              for _, item in ipairs(items) do
                local src = src_dir .. "/" .. item
                vim.fn.system({ "cp", "-a", "-f", src, target_dir .. "/" })
              end
              vim.fn.delete(extract_dir, "rf")
              on_done(nil)
            end,
          }
        )
      end,
    }
  )
  return job_id
end

return M
