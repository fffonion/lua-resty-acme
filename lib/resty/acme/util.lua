local openssl = require("resty.acme.openssl")

-- https://tools.ietf.org/html/rfc8555 Page 10
-- Binary fields in the JSON objects used by acme are encoded using
-- base64url encoding described in Section 5 of [RFC4648] according to
-- the profile specified in JSON Web Signature in Section 2 of
-- [RFC7515].  This encoding uses a URL safe character set.  Trailing
-- '=' characters MUST be stripped.  Encoded values that include
-- trailing '=' characters MUST be rejected as improperly encoded.
local base64 = require("ngx.base64")
local encode_base64url = base64.encode_base64url
--   -- Fallback if resty.core is not available
--   encode_base64url = function (s)
--     return ngx.encode_base64(s):gsub("/", "_"):gsub("+", "-"):gsub("[= ]", "")
--   end

-- https://tools.ietf.org/html/rfc7638
local function thumbprint(pkey)
  local params = pkey:get_parameters()
  if not params then
    return nil, "could not extract account key parameters."
  end

  local jwk_ordered =
    string.format(
    '{"e":"%s","kty":"%s","n":"%s"}',
    encode_base64url(params.e:to_binary()),
    "RSA",
    encode_base64url(params.n:to_binary())
  )
  local digest = openssl.digest.new("SHA256"):final(jwk_ordered)
  return encode_base64url(digest), nil
end

local function create_csr(domain_pkey, ...)
  local domains = {...}


  local subject = openssl.name.new()
  local _, err = subject:add("CN", domains[1])
  if err then
    return nil, "failed to add subject name: " .. err
  end

  local alt, ok, err
  if #{...} > 1 then
    alt, err = openssl.altname.new()
    if err then
      return nil, err
    end

    for _, domain in pairs(domains) do
      _, err = alt:add("DNS", domain)
      if err then
        return nil, "failed to add altname: " .. err
      end
    end
  end

  local csr = openssl.csr.new()
  _, err = csr:set_subject_name(subject)
  if err then
    return nil, "failed to set_subject_name: " .. err
  end
  if alt then
    _, err = csr:set_subject_alt_name(alt)
    if err then
      return nil, "failed to set_subject_alt: " .. err
    end
  end

  _, err = csr:set_pubkey(domain_pkey)
  if err then
    return nil, "failed to set_pubkey: " .. err
  end

  _, err = csr:sign(domain_pkey)
  if err then
    return nil, "failed to sign: " .. err
  end

  return csr:tostring("DER"), nil
end

local function create_pkey(bits, typ, curve)
  bits = bits or 4096
  typ = typ or 'RSA'
  local pkey = openssl.pkey.new({
    bits = bits,
    type = typ,
    curve = curve,
  })

  return pkey:to_PEM('private')
end

return {
    encode_base64url = encode_base64url,
    thumbprint = thumbprint,
    create_csr = create_csr,
    create_pkey = create_pkey,
}
