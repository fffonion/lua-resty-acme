local http = require("resty.http")
local cjson = require("cjson")

local _M = {}
local mt = {__index = _M}

function _M.new(token)
  if not token or token == "" then
    return nil, "api token is needed"
  end

  local self = setmetatable({
    endpoint = "https://api.dnspod.com/",
    httpc = nil,
    token = token,
    ttl = 600,
    headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "lua-resty-acme/0.0.0 (noreply@github.com)",
    }
  }, mt)

  self.httpc = http.new()
  return self
end

local function request(self, uri, body)
  body = body or {}
  body.login_token = self.token
  body.lang = "en"
  body.error_on_empty = "no"

  local url = self.endpoint .. "/" .. uri

  local resp, err = self.httpc:request_uri(url,
    {
      method = "POST",
      headers = self.headers,
      body = cjson.encode(body)
    }
  )
  if err then
    return nil, err
  end

  return resp
end

local function get_base_domain(domain)
  local parts = {}
  for part in domain:gmatch("([^.]+)") do
    table.insert(parts, part)
  end

  local num_parts = #parts
  if num_parts <= 2 then
    return "@", domain
  else
    local base_domain = parts[num_parts-1] .. "." .. parts[num_parts]
    table.remove(parts, num_parts)
    table.remove(parts, num_parts - 1)
    local subdomain = table.concat(parts, ".")
    return subdomain, base_domain
  end
end

function _M:post_txt_record(fqdn, content)
  local sub, base = get_base_domain(fqdn)

  ngx.log(ngx.DEBUG, "[dnspod-intl] base domain is ", base, " subdomain is ", sub)

  local resp, err = request(self, "Record.Create", {
    domain = base,
    sub_domain = sub,
    record_type = "TXT",
    record_line = "default",
    value = content,
    ttl = self.ttl
  })

  if err then
    return nil, "post_txt_record: " .. err
  end

  if resp.status ~= 200 then
    return nil, "post_txt_record: dnspod returned non 200 status: " .. resp.status .. " body: " .. resp.body
  end

  return true
end

local function get_record_id(self, fqdn)
  local sub, base = get_base_domain(fqdn)

  ngx.log(ngx.DEBUG, "[dnspod-intl] base domain is ", base, " subdomain is ", sub)

  local resp, err = request(self, "Record.List", {
    domain = base,
    sub_domain = sub,
  })

  if err then
    return nil, "get_record_id: " .. err
  end

  local body = cjson.decode(resp.body)

  local records = {}

  for _, record in ipairs(body.records) do
    if record.type == "TXT" then
      records[#records+1] = record.id
    end
  end

  return records 
end

function _M:delete_txt_record(fqdn)
  local record_ids, err = get_record_id(self, fqdn)
  if err then
    return nil, "get_record_id: " .. err
  end
  local _, base = get_base_domain(fqdn)
  for _, rec in ipairs(record_ids) do
    local resp, err = request(self, "Record.Remove", {
      domain = base,
      record_id = rec,
    })

    if err then
      return nil, err
    end

    if resp.status ~= 200 then
      return nil, "delete_txt_record: dnspod returned non 200 status: " .. resp.status .. " body: " .. resp.body
    end
  end

  return true
end

return _M
