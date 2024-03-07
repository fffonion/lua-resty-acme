local util = require("resty.acme.util")
local digest = require("resty.openssl.digest")
local base64 = require("ngx.base64")
local gsub = string.gsub
local log = util.log
local encode_base64url = base64.encode_base64url

local _M = {}
local mt = {__index = _M}

function _M.new(storage)
  local self = setmetatable({
    storage = storage,
    domain_owner = nil,
    domain_registrar_token = {
      dynv6 = nil,
    },
  }, mt)
  return self
end

local function compute_txt_record(keyauthorization)
  local dgst = assert(digest.new("sha256"):final(keyauthorization))
  local txt_record = encode_base64url(dgst)
  log(ngx.DEBUG, "computed txt record: ", txt_record)
  return txt_record
end

local function ch_key(challenge)
  return challenge .. "#dns-01"
end

function _M:update_domain_info(domain_owner, domain_registrar_token)
  self.domain_owner = domain_owner
  self.domain_registrar_token = domain_registrar_token
end

function _M:update_dnsapi(domain)
  local owner = self.domain_owner[domain]
  log(ngx.DEBUG, "update_dnsapi returns: ", owner)
  if not owner then
    return nil, "no dns registrar"
  end
  local token = self.domain_registrar_token[owner]
  if not token then
    return nil, "no token for dns registrar"
  end
  local ok, module = pcall(require, "resty.acme.dnsapi." .. owner)
  if ok then
    local handler, err = module.new(token)
    if not err then
      return handler
    end
  end
  return nil, "require dnsapi error:" .. owner
end

function _M:register_challenge(_, response, domains)
  local err
  for _, domain in ipairs(domains) do
    err = self.storage:set(ch_key(domain), response, 3600)
    if err then
      return err
    end
    local txt_record = compute_txt_record(response)
    local dnsapi, err = self:update_dnsapi(domain)
    if err then
      return err
    end
    local trim_domain = gsub(domain, "*.", "")
    local result, err = dnsapi:post_txt_record("_acme-challenge." .. trim_domain, txt_record)
    if err then
      return err
    end
    log(ngx.DEBUG, "dnsapi returns: ", result)
  end
end

function _M:cleanup_challenge(_--[[challenge]], domains)
  local err
  for _, domain in ipairs(domains) do
    err = self.storage:delete(ch_key(domain))
    if err then
      return err
    end
    local dnsapi, err = self:update_dnsapi(domain)
    if err then
      return err
    end
    local trim_domain = gsub(domain, "*.", "")
    local result, err = dnsapi:delete_txt_record("_acme-challenge." .. trim_domain)
    if err then
      return err
    end
    log(ngx.DEBUG, "dnsapi returns: ", result)
  end
end

return _M
