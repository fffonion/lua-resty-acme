local http = require("resty.http")
local cjson = require("cjson")

local _M = {}
local mt = {__index = _M}

function _M.new(token)
  if token == nil then
    return nil, "api token is needed"
  end

  local self = setmetatable({
    endpoint = "https://api.cloudflare.com/client/v4",
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
  local url = self.endpoint .. "/zones"
  local resp, err = self.httpc:request_uri(url,
    {
      method = "GET",
      headers = self.headers
    }
  )
  if err then
    return nil, err
  end

  if resp and resp.status == 200 then
    -- expamle body:
    -- {
    --   "result":
    --     [{
    --       "id":"12345abcde",
    --       "name":"domain.com",
    --       ...
    --     }],
    --   "result_info":{"page":1,"per_page":20,"total_pages":1,"count":1,"total_count":1},
    --   "success":true,
    --   "errors":[],
    --   "messages":[]
    -- }
    local body = cjson.decode(resp.body)
    if not body then
      return nil, "json decode error"
    end

    for _, zone in ipairs(body.result) do
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
  local url = self.endpoint .. "/zones/" .. zone_id .. "/dns_records"
  local body = {
    ["type"] = "TXT",
    ["name"] = fqdn,
    ["content"] = content
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
  local url = self.endpoint .. "/zones/" .. zone_id .. "/dns_records"
  local resp, err = self.httpc:request_uri(url,
    {
      method = "GET",
      headers = self.headers
    }
  )
  if err then
    return nil, err
  end

  if resp and resp.status == 200 then
    -- expamle body:
    -- {
    --   "result":
    --     [{
    --       "id":"12345abcdefghti",
    --       "zone_id":"12345abcde",
    --       "zone_name":"domain.com",
    --       "name":"_acme-challenge.domain.com",
    --       "type":"TXT",
    --       "content":"record_content",
    --       ...
    --     }],
    --   "success":true,
    --   "errors":[],
    --   "messages":[],
    --   "result_info":{"page":1,"per_page":100,"count":1,"total_count":1,"total_pages":1}
    -- }
    local body = cjson.decode(resp.body)
    if not body then
      return nil, "json decode error"
    end

    for _, record in ipairs(body.result) do
      if fqdn == record.name then
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
  local url = self.endpoint .. "/zones/" .. zone_id .. "/dns_records/" .. record_id
  local resp, err = self.httpc:request_uri(url,
    {
      method = "DELETE",
      headers = self.headers
    }
  )
  if err then
    return nil, err
  end

  -- return 200 ok
  return resp.status
end

return _M
