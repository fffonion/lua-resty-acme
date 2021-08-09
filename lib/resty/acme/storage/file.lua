local ok, lfs = pcall(require, 'lfs_ffi')
if not ok then
  local _
  _, lfs = pcall(require, 'lfs')
end

local _M = {}
local mt = {__index = _M}

local TTL_SEPERATOR = '::'
local TTL_PATTERN = "(%d+)" .. TTL_SEPERATOR .. "(.+)"

function _M.new(conf)
  local dir = conf and conf.dir
  dir = dir or os.getenv("TMPDIR") or '/tmp'

  local self =
    setmetatable(
    {
      dir = dir
    },
    mt
  )
  return self
end

local function regulate_filename(dir, s)
  -- TODO: not windows friendly
  return dir .. "/" .. ngx.encode_base64(s)
end

local function exists(f)
  -- TODO: check for existence, not just able to open or not
  local f, err = io.open(f, "rb")
  if f then
    f:close()
  end
  return err == nil
end

local function split_ttl(s)
  local _, _, ttl, value = string.find(s, TTL_PATTERN)

  return tonumber(ttl), value
end

local function check_expiration(f)
  if not exists(f) then
    return
  end

  local file, err = io.open(f, "rb")
  if err then
    return nil, err
  end

  local output, err = file:read("*a")
  file:close()

  if err then
    return nil, err
  end

  local ttl, value = split_ttl(output)

  -- ttl is nil meaning the file is corrupted or in legacy format
  -- ttl = 0 means the key never expires
  if not ttl or (ttl > 0 and ngx.time() - ttl >= 0) then
    os.remove(f)
  else
    return value
  end
end

function _M:add(k, v, ttl)
  local f = regulate_filename(self.dir, k)

  local check = check_expiration(f)
  if check then
    return "exists"
  end

  return self:set(k, v, ttl)
end

function _M:set(k, v, ttl)
  local f = regulate_filename(self.dir, k)

  -- remove old keys if it's expired
  check_expiration(f)

  if ttl then
    ttl = math.floor(ttl + ngx.time())
  else
    ttl = 0
  end

  local file, err = io.open(f, "wb")
  if err then
    return err
  end
  local _, err = file:write(ttl .. TTL_SEPERATOR .. v)
  if err then
    return err
  end
  file:close()
end

function _M:delete(k)
  local f = regulate_filename(self.dir, k)
  if not exists(f) then
    return nil, nil
  end
  local _, err = os.remove(f)
  if err then
    return err
  end
end

function _M:get(k)
  local f = regulate_filename(self.dir, k)

  local value, err = check_expiration(f)
  if err then
    return nil, err
  elseif value then
    return value, nil
  else
    return nil
  end
end

function _M:list(prefix)
  if not lfs then
    return {}, "lfs_ffi needed for file:list"
  end

  local files = {}

  local prefix_len = prefix and #prefix or 0

  for file in lfs.dir(self.dir) do
    file = ngx.decode_base64(file)
    if not file then
      goto nextfile
    end
    if prefix_len == 0 or string.sub(file, 1, prefix_len) == prefix then
      table.insert(files, file)
    end
::nextfile::
  end
  return files
end

return _M
