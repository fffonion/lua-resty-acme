local _M = {}
local mt = {__index = _M}

function _M.extend()
  return setmetatable({}, { __index = _M })
end

function _M:set_storage(storage)
  self.storage = storage
end

function _M:register_challenge(challenge, response)
  return self.storage:set(challenge, response)
end

function _M:cleanup_challenge(challenge, response)
  return self.storage:delete(challenge, response)
end

function _M:serve_challenge(challenge, response)
  ngx.log(ngx.ERR, "serve_challenge is not implemented")
  ngx.exit(500)
end

return _M
