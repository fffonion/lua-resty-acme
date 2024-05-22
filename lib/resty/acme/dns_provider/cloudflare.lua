local http = require("resty.http")
local cjson = require("cjson")

local _M = {}
local mt = {__index = _M}

function _M.new(token)
  if not token or token == "" then
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

local function get_zone_id(self, fqdn)
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

    ngx.log(ngx.DEBUG, "[cloudflare] find zone ", fqdn, " in ", resp.body)

    for _, zone in ipairs(body.result) do
      local start, _, err = fqdn:find(zone.name, 1, true)
      if err then
        return nil, err
      end
      if start then
        self.zone = zone.name
        ngx.log(ngx.DEBUG, "[cloudflare] zone id is ", zone.id, " for domain ", fqdn)
        return zone.id
      end
    end
  else
    return nil, "get_zone_id: cloudflare returned non 200 status: " .. resp.status .. " body: " .. resp.body
  end

  return nil, "no matched dns zone found"
end

function _M:post_txt_record(fqdn, content)
  local zone_id, err = get_zone_id(self, fqdn)
  if err then
    return nil, "post_txt_record: " .. err
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
      body = cjson.encode(body)
    }
  )
  if err then
    return nil, err
  end

  if resp.status == 400 then
    ngx.log(ngx.INFO, "[cloudflare] ignoring possibly fine error: ", resp.body)
    return true
  elseif resp.status ~= 200 then
    return false, "post_txt_record: cloudflare returned non 200 status: " .. resp.status .. " body: " .. resp.body
  end

  return true
end

local function get_record_ids(self, zone_id, fqdn)
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

    local ids = {}
    for _, record in ipairs(body.result) do
      if fqdn == record.name then
        ids[#ids+1] = record.id
      end
    end
    return ids
  end

  return nil, "no matched dns record found"
end

function _M:delete_txt_record(fqdn)
  local zone_id, err = get_zone_id(self, fqdn)
  if err then
    return nil, err
  end

  local record_ids, err = get_record_ids(self, zone_id, fqdn)
  if err then
    return nil, err
  end

  for _, record_id in ipairs(record_ids) do
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

      if resp.status ~= 200 then
        return nil, "delete_txt_record: cloudflare returned non 200 status: " .. resp.status .. " body: " .. resp.body
      end
  end

  return true
end

return _M
