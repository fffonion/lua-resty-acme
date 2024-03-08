local http = require("resty.http")
local cjson = require("cjson")
local json = cjson.new()

local _M = {}
local mt = {__index = _M}

function _M.new(token)
  if token == nil then
    return nil, "web token is needed"
  end

  local self = setmetatable({
    httpc = nil,
    token = token,
    zone = nil,
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. token,
    }
  }, mt)

  self.httpc = http.new()
  return self
end

function _M:get_zone_id(fqdn)
  local url = "https://dynv6.com/api/v2/zones"
  local resp, err = self.httpc:request_uri(url,
    {
      method = "GET",
      headers = self.headers
    }
  )
  if err then
    return nil, err
  end

  if resp and resp.status == 200 and #resp.body >= 1 then
    -- expamle body:
    -- [{
    --  "name":"domain.dynv6.net",
    --  "ipv4address":"",
    --  "ipv6prefix":"",
    --  "id":1,
    --  "createdAt":"2022-08-14T17:32:57+02:00",
    --  "updatedAt":"2022-08-14T17:32:57+02:00"
    -- }]
    local body = json.decode(resp.body)
    for _, zone in ipairs(body) do
      local start, _, err = fqdn:find(zone.name, 1, true)
      if err then
        return nil, err
      end
      if start then
        self.zone = zone.name
        return zone.id
      end
    end
  end

  return nil, "no matched dns zone found"
end

function _M:post_txt_record(fqdn, content)
  local zone_id, err = self:get_zone_id(fqdn)
  if err then
    return nil, err
  end
  local url = "https://dynv6.com/api/v2/zones/" .. zone_id .. "/records"
  local body = {
    ["type"] = "TXT",
    ["name"] = gsub(fqdn, "." .. self.zone, ""),
    ["data"] = content
  }
  local resp, err = self.httpc:request_uri(url,
    {
      method = "POST",
      headers = self.headers,
      body = json.encode(body)
    }
  )
  if err then
    return nil, err
  end

  return resp.status
end

function _M:get_record_id(zone_id, fqdn)
  local url = "https://dynv6.com/api/v2/zones/" .. zone_id .. "/records"
  local resp, err = self.httpc:request_uri(url,
    {
      method = "GET",
      headers = self.headers
    }
  )
  if err then
    return nil, err
  end

  if resp and resp.status == 200 and #resp.body >= 1 then
    -- expamle body:
    -- [{
    --   "type":"TXT",
    --   "name":"_acme-challenge",
    --   "data":"record_content",
    --   "priority":null,
    --   "flags":null,
    --   "tag":null,
    --   "weight":null,
    --   "port":null,
    --   "id":1,
    --   "zoneID":1
    -- }]
    local body = json.decode(resp.body)
    for _, record in ipairs(body) do
      local start, theend, err = fqdn:find(record.name, 1, true)
      if err then
        return nil, err
      end
      if start then
        return record.id
      end
    end
  end

  return nil, "no matched dns record found"
end

function _M:delete_txt_record(fqdn)
  local zone_id, err = self:get_zone_id(fqdn)
  if err then
    return nil, err
  end
  local record_id, err = self:get_record_id(zone_id, fqdn)
  local url = "https://dynv6.com/api/v2/zones/" .. zone_id .. "/records/" .. record_id
  local resp, err = self.httpc:request_uri(url,
    {
      method = "DELETE",
      headers = self.headers
    }
  )
  if err then
    return nil, err
  end
  -- return 204 not content
  return resp.status
end

return _M
