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

function _M:add(k, v, ttl)
  local f = regulate_filename(self.dir, k)
  if exists(f) then
    return "exists"
  end
  return self:set(k, v, ttl)
end

function _M:set(k, v, ttl)
  if ttl then
    return "nyi"
  end
  local f = regulate_filename(self.dir, k)
  local file, err = io.open(f, "wb")
  if err then
    return err
  end
  local _, err = file:write(v)
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
  local file, err = io.open(f, "rb")
  if err then
    ngx.log(ngx.INFO, "can't read file: ", err)
    -- TODO: return nil, nil if not found
    return nil, nil
  end
  local output, err = file:read("*a")
  if err then
    return nil, err
  end
  file:close()
  return output, nil
end

function _M:list(prefix)
  return {}, "nyi"
end

return _M
