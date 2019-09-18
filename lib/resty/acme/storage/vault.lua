local _M = {}
local mt = {__index = _M}

function _M.new(conf)
  local self =
    setmetatable(
    {
      
    },
    mt
  )
  return self
end

function _M:set(k, v)

end

function _M:delete(k)

end

function _M:get(k)

end

function _M:list(prefix)

end

return _M
