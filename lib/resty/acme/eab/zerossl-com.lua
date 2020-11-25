local http = require("resty.http")
local json = require("cjson")

local api_uri = "https://api.zerossl.com/acme/eab-credentials-email"

local function handle(account_email)
  local httpc = http.new()
  local resp, err = httpc:request_uri(api_uri,
    {
      method = "POST",
      body = "email=" .. ngx.escape_uri(account_email),
      headers = {
        ['Content-Type'] = "application/x-www-form-urlencoded",
      }
    }
  )
  if err then
    return nil, nil, err
  end

  local body = json.decode(resp.body)

  if not body['success'] then
    return nil, nil, "zerossl.com API error: " .. body
  end

  if not body['eab_kid'] or not body['eab_hmac_key'] then
    return nil, nil, "zerossl.com API response missing eab_kid or eab_hmac_key: " .. body
  end

  return body['eab_kid'], body['eab_hmac_key']
end

return {
  handle = handle,
}