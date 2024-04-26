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
    -- domain_auth_info = {
    --   ["*.domain.com"] = {
    --     provider = "cloudflare",
    --     content = "token"
    --   },
    --   ["www.domain.com"] = {
    --     provider = "dynv6",
    --     content = "token"
    --   }
    -- }
    domain_auth_info = nil
  }, mt)
  return self
end

local function calculate_txt_record(keyauthorization)
  local dgst = assert(digest.new("sha256"):final(keyauthorization))
  local txt_record = encode_base64url(dgst)
  log(ngx.DEBUG, "calculate txt record: ", txt_record)
  return txt_record
end

local function ch_key(challenge)
  return challenge .. "#dns-01"
end

local function choose_dnsapi(self, domain)
  local provider = self.domain_auth_info[domain].provider
  log(ngx.DEBUG, "use dnsapi provider: ", provider)
  if not provider then
    return nil, "dnsapi provider not found"
  end
  local content = self.domain_auth_info[domain].content
  if not content then
    return nil, "dnsapi auth info not found"
  end
  local ok, module = pcall(require, "resty.acme.dnsapi." .. provider)
  if ok then
    local handler, err = module.new(content)
    if not err then
      return handler
    end
  end
  return nil, "require dnsapi error: " .. provider
end

function _M:update_domain_auth_info(domain_auth_info)
  self.domain_auth_info = domain_auth_info
end

function _M:register_challenge(_, response, domains)
  local err
  for _, domain in ipairs(domains) do
    err = self.storage:set(ch_key(domain), response, 3600)
    if err then
      return err
    end
    local txt_record = calculate_txt_record(response)
    local dnsapi, err = choose_dnsapi(self, domain)
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
    local dnsapi, err = choose_dnsapi(self, domain)
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
