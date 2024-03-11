local util = require("resty.acme.util")
local digest = require("resty.openssl.digest")
local base64 = require("ngx.base64")
local log = util.log
local encode_base64url = base64.encode_base64url

local _M = {}
local mt = {__index = _M}

function _M.new(storage)
  local self = setmetatable({
    storage = storage,
    dnsapi_provider = nil,
    dnsapi_token = {
      cloudflare = nil,
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

function _M:update_domain_info(dnsapi_provider, dnsapi_token)
  self.dnsapi_provider = dnsapi_provider
  self.dnsapi_token = dnsapi_token
end

function _M:update_dnsapi(domain)
  local provider = self.dnsapi_provider[domain]
  log(ngx.DEBUG, "found dnsapi provider: ", provider)
  if not provider then
    return nil, "no dnsapi provider found"
  end
  local token = self.dnsapi_token[provider]
  if not token then
    return nil, "no api token for current dnsapi"
  end
  local ok, module = pcall(require, "resty.acme.dnsapi." .. provider)
  if ok then
    local handler, err = module.new(token)
    if not err then
      return handler
    end
  end
  return nil, "require dnsapi error: " .. provider
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
    local trim_domain = domain:gsub("*.", "")
    local result, err = dnsapi:post_txt_record("_acme-challenge." .. trim_domain, txt_record)
    log(ngx.DEBUG, "dnsapi post_txt_record returns: ", result)
    if err then
      return err
    end
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
    local trim_domain = domain:gsub("*.", "")
    local result, err = dnsapi:delete_txt_record("_acme-challenge." .. trim_domain)
    log(ngx.DEBUG, "dnsapi delete_txt_record returns: ", result)
    if err then
      return err
    end
  end
end

return _M
