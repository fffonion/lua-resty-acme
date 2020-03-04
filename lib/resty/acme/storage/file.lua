local lfs = require('lfs_ffi')

local _M = {}
local mt = {__index = _M}

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

local function startswith(s, p)
  return string.sub(s or "", 1, string.len(p)) == p
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
  local _, _, ttl, value = string.find(s, "(%d+):(.+)")

  return tonumber(ttl), value
end

local function stat(f)
  local attrs, err = lfs.attributes(f)
  if err then
    return 0
  else
    return attrs["modification"]
  end
  -- return tonumber(last_modified) or 0
end

local function check_expiration(f)
  local file, err = io.open(f, "rb")
  if err then
    return
  end

  local output, err = file:read("*a")
  file:close()

  if err then
    return
  end

  local ttl, value = split_ttl(output)

  if ttl == 0 then
    return value
  else
    if os.difftime(os.time(), stat(f) + ttl) >= 0 then
      os.remove(f)
    else
      return value
    end
  end
end

function _M:add(k, v, ttl)
  local f = regulate_filename(self.dir, k)

  check_expiration(f)

  if exists(f) then
    return "exists"
  end
  return self:set(k, v, ttl)
end

function _M:set(k, v, ttl)
  local f = regulate_filename(self.dir, k)

  check_expiration(f)

  if ttl then
    if ttl > 0 and ttl < 1 then
      ttl = 1
    end
  else
    ttl = 0
  end

  local file, err = io.open(f, "wb")
  if err then
    return err
  end
  local _, err = file:write(ttl .. ":" .. v)
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
  local ok, err = os.remove(f)
  if err then
    return err
  end
end

function _M:get(k)
  local f = regulate_filename(self.dir, k)

  local value = check_expiration(f)
  if value then
    return value, nil
  else
    return nil, nil
  end
end

function _M:list(prefix)
  local files = {}

  for file in lfs.dir(self.dir) do
    file = ngx.decode_base64(file)
    if startswith(file, prefix) then
      table.insert(files, file)
    end
  end
  return files
end

return _M
