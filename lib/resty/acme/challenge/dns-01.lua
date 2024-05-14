local util = require("resty.acme.util")
local digest = require("resty.openssl.digest")
local base64 = require("ngx.base64")
local cjson = require("cjson")
local log = util.log
local encode_base64url = base64.encode_base64url

local _M = {}
local mt = {__index = _M}

function _M.new(storage)
  local self = setmetatable({
    storage = storage,
    -- domain_used_dns_provider_key_detail = {
    --   ["*.domain.com"] = {
    --     provider = "cloudflare",
    --     content = "token"
    --   },
    --   ["www.domain.com"] = {
    --     provider = "dynv6",
    --     content = "token"
    --   }
    -- }
    domain_used_dns_provider_key_detail = {}
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

local function choose_dns_provider(self, domain)
  if not self.domain_used_dns_provider_key_detail[domain] then
    return nil, "not dns provider key for domain"
  end
  local provider = self.domain_used_dns_provider_key_detail[domain].provider
  if not provider then
    return nil, "dns provider not support"
  end
  log(ngx.INFO, "used dns provider: ", provider)
  local content = self.domain_used_dns_provider_key_detail[domain].content
  if not content or content == "" then
    return nil, "dns provider key content is empty"
  end
  local ok, module = pcall(require, "resty.acme.dns_provider." .. provider)
  if ok then
    local handler, err = module.new(content)
    if not err then
      return handler
    end
  end
  return nil, "require dns provider error: " .. provider
end

function _M:update_dns_provider_info(domain_used_dns_provider_key_detail)
  log(ngx.INFO, "update_dns_provider_info: " .. cjson.encode(domain_used_dns_provider_key_detail))
  self.domain_used_dns_provider_key_detail = domain_used_dns_provider_key_detail
end

function _M:register_challenge(_, response, domains)
  local dnsapi, err
  for _, domain in ipairs(domains) do
    err = self.storage:set(ch_key(domain), response, 3600)
    if err then
      return err
    end
    dnsapi, err = choose_dns_provider(self, domain)
    if err then
      return err
    end
    local trim_domain = domain:gsub("*.", "")
    local txt_record = calculate_txt_record(response)
    local result, err = dnsapi:post_txt_record("_acme-challenge." .. trim_domain, txt_record)
    if err then
      return err
    end
    log(ngx.INFO, "dns provider post_txt_record returns: ", result)
  end
end

function _M:cleanup_challenge(_--[[challenge]], domains)
  local dnsapi, err
  for _, domain in ipairs(domains) do
    err = self.storage:delete(ch_key(domain))
    if err then
      return err
    end
    dnsapi, err = choose_dns_provider(self, domain)
    if err then
      return err
    end
    local trim_domain = domain:gsub("*.", "")
    local result, err = dnsapi:delete_txt_record("_acme-challenge." .. trim_domain)
    if err then
      return err
    end
    log(ngx.INFO, "dns provider delete_txt_record returns: ", result)
  end
end

return _M
