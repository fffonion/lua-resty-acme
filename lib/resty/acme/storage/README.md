## resty.acme.storage

An storage can be easily plug-and-use as long as it implement the following interface:

```lua
local _M = {}
local mt = {__index = _M}

function _M.new(conf)
  local self = setmetatable({}, mt)
  return self, err
end

function _M:set(k, v)
  return err
end

function _M:delete(k)
  return err
end

function _M:get(k)
  -- if key not exist, return nil, nil
  return value, err
end

function _M:list(prefix)
  local keys = { "key1", "key2" }
  return keys, err
end

return _M
```
