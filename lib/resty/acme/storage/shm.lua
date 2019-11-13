local _M = {}
local mt = {__index = _M}

local table_remove = table.remove

function _M.new(conf)
  if not conf or not conf.shm_name then
    return nil, "conf.shm_name must be provided"
  end

  if not ngx.shared[conf.shm_name] then
    return nil, "shm " .. conf.shm_name .. " is not defined"
  end

  local self =
    setmetatable(
    {
      shm = ngx.shared[conf.shm_name]
    },
    mt
  )
  return self
end

function _M:add(k, v, ttl)
  local _, err = self.shm:add(k, v, ttl)
  return err
end

function _M:set(k, v, ttl)
  local _, err = self.shm:set(k, v, ttl)
  return err
end

function _M:delete(k)
  local _, err = self.shm:delete(k)
  return err
end

function _M:get(k)
  return self.shm:get(k)
end

function _M:list(prefix)
  local keys = self.shm:get_keys(0)
  if prefix then
    local prefix_length = #prefix
    for i=#keys, 1, -1 do
      if keys[i]:sub(1, prefix_length) ~= prefix then
        table_remove(keys, i)
      end
    end
  end
  return keys
end

return _M
