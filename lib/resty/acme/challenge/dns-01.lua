local util = require("resty.acme.util")
local digest = require("resty.openssl.digest")
local resolver = require("resty.dns.resolver")
local base64 = require("ngx.base64")
local log = util.log
local encode_base64url = base64.encode_base64url

local _M = {}
local mt = {__index = _M}

function _M.new(storage)
  local self = setmetatable({
    storage = storage,
    -- dns_provider_accounts_mapping = {
    --   ["*.domain.com"] = {
    --     provider = "cloudflare",
    --     secret = "token"
    --   },
    --   ["www.domain.com"] = {
    --     provider = "dynv6",
    --     secret = "token"
    --   }
    -- }
    dns_provider_accounts_mapping = {},
    dns_provider_modules = {},
  }, mt)
  return self
end

local function calculate_txt_record(keyauthorization)
  local dgst = assert(digest.new("sha256"):final(keyauthorization))
  local txt_record = encode_base64url(dgst)
  return txt_record
end

local function ch_key(challenge)
  return challenge .. "#dns-01"
end

local function choose_dns_provider(self, domain)
  local prov = self.dns_provider_accounts_mapping[domain]
  if not prov then
    return nil, "no dns provider key configured for domain " .. domain
  end

  if not prov.provider or not prov.secret then
    return nil, "provider config malformed for domain " .. domain
  end

  local module = self.dns_provider_modules[prov.provider]
  if not module then
    return nil, "provider " .. prov.provider .. " is not loaded for domain " .. domain
  end

  local handler, err = module.new(prov.secret)
  if not err then
    return handler
  end
  return nil, "dns provider init error: " .. err  .. " for domain " .. domain
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
  local answers, err, _ = r:tcp_query(record_name, { qtype = r.TYPE_TXT }, {})
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

function _M:update_dns_provider_info(dns_provider_accounts)
  self.dns_provider_accounts_mapping = {}
  self.dns_provider_modules = {}

  for i, account in ipairs(dns_provider_accounts) do
    if not account.name then
      return nil, "#" .. i .. " element in dns_provider_accounts doesn't have a name"
    end
    if not account.secret then
      return nil, "dns provider account " .. account.name .." doesn't have a secret"
    end
    if not account.provider then
      return nil, "dns provider account " .. account.name .." doesn't have a provider"
    end

    if not self.dns_provider_modules[account.provider] then
      local ok, perr = pcall(require, "resty.acme.dns_provider." .. account.provider)
      if not ok then
        return nil, "dns provider " .. account.provider .. " failed to load: " .. perr
      end

      self.dns_provider_modules[account.provider] = perr
    end

    for _, domain in ipairs(account.domains) do
      self.dns_provider_accounts_mapping[domain] = account
    end
  end

  return true
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
    log(ngx.DEBUG, "calculated txt record: ", txt_record_content, " for domain: ", domain)

    local _, err = dnsapi:post_txt_record(txt_record_name, txt_record_content)
    if err then
      return err
    end

    log(ngx.INFO, "waiting up to 5 minutes for dns record propagation on ", txt_record_name)

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

    log(ngx.INFO, "txt record for ", txt_record_name, " verified, continue to next domain")
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
