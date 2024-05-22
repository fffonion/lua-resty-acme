local util = require("resty.acme.util")
local digest = require("resty.openssl.digest")
local resolver = require("resty.dns.resolver")
local base64 = require("ngx.base64")
local cjson = require("cjson")
local log = util.log
local encode_base64url = base64.encode_base64url

local _M = {}
local mt = {__index = _M}

function _M.new(storage)
  local self = setmetatable({
    storage = storage,
    -- dns_provider_keys_mapping = {
    --   ["*.domain.com"] = {
    --     provider = "cloudflare",
    --     content = "token"
    --   },
    --   ["www.domain.com"] = {
    --     provider = "dynv6",
    --     content = "token"
    --   }
    -- }
    dns_provider_keys_mapping = {}
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
  if not self.dns_provider_keys_mapping[domain] then
    return nil, "not dns provider key for domain"
  end
  local provider = self.dns_provider_keys_mapping[domain].provider
  if not provider then
    return nil, "dns provider not support"
  end
  log(ngx.INFO, "using dns provider: ", provider, " for domain: ", domain)
  local content = self.dns_provider_keys_mapping[domain].content
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

local function verify_txt_record(record_name, expected_record_content)
  local r, err = resolver:new{
    nameservers = {"8.8.8.8", "8.8.4.4"},
    retrans = 5,
    timeout = 2000,
    no_random = true,
  }
  if not r then
    return false, "failed to instantiate the resolver: " .. err
  end
  local answers, err, _ = r:query(record_name, { qtype = r.TYPE_TXT }, {})
  if not answers then
    return false, "failed to query the DNS server: " .. err
  end
  if answers.errcode then
    return false, "server returned error code: " .. answers.errcode .. ": " .. (answers.errstr or "nil")
  end
  for _, ans in ipairs(answers) do
    if ans.txt == expected_record_content then
      log(ngx.DEBUG, "verify txt record ok: ", ans.name, ", content: ", ans.txt)
      return true
    end
  end
  return false, "txt record mismatch"
end

function _M:update_dns_provider_info(dns_provider_keys_mapping)
  log(ngx.INFO, "update_dns_provider_info: " .. cjson.encode(dns_provider_keys_mapping))
  self.dns_provider_keys_mapping = dns_provider_keys_mapping
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
    local txt_record_name = "_acme-challenge." .. domain:gsub("*.", "")
    local txt_record_content = calculate_txt_record(response)
    local result, err = dnsapi:post_txt_record(txt_record_name, txt_record_content)
    if err then
      return err
    end
    log(ngx.INFO,
        "dns provider post_txt_record returns: ", result,
        ", now waiting for dns record propagation")
    local wait_verify_counts = 0
    while true do
      local ok, err = verify_txt_record(txt_record_name, txt_record_content)
      if ok then
        break
      end
      log(ngx.DEBUG, "unable to verify txt record, last error was: ", err, ", retrying in 5 seconds")
      ngx.sleep(5)
      wait_verify_counts = wait_verify_counts + 1
      if wait_verify_counts >= 60 then
        return "timeout (5m) exceeded to verify txt record, latest error was: " .. (err or "nil")
      end
    end
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
    log(ngx.DEBUG, "dns provider delete_txt_record returns: ", result)
  end
end

return _M
