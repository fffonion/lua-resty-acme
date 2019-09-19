local openssl = {
  pkey = require("openssl.pkey"),
  name = require("openssl.x509.name"),
  altname = require("openssl.x509.altname"),
  csr = require("openssl.x509.csr"),
  digest = require("openssl.digest")
}

-- https://tools.ietf.org/html/rfc8555 Page 10
-- Binary fields in the JSON objects used by _M are encoded using
-- base64url encoding described in Section 5 of [RFC4648] according to
-- the profile specified in JSON Web Signature in Section 2 of
-- [RFC7515].  This encoding uses a URL safe character set.  Trailing
-- '=' characters MUST be stripped.  Encoded values that include
-- trailing '=' characters MUST be rejected as improperly encoded.
local function base64_urlencode(s)
  return ngx.encode_base64(s):gsub("/", "_"):gsub("+", "-"):gsub("[= ]", "")
end

-- https://tools.ietf.org/html/rfc7638
local function thumbprint(pkey)
  local params = pkey:getParameters()
  if not params then
    return nil, "could not extract account key parameters."
  end

  local jwk_ordered =
    string.format(
    '{"e":"%s","kty":"%s","n":"%s"}',
    base64_urlencode(params.e:toBinary()),
    "RSA",
    base64_urlencode(params.n:toBinary())
  )
  local digest = openssl.digest.new("SHA256"):final(jwk_ordered)
  return base64_urlencode(digest), nil
end

local function create_csr(domain_pkey, ...)
  local domains = {...}

  local subject = openssl.name.new()
  subject:add("CN", domains[1])

  local alt = openssl.altname.new()

  for _, domain in pairs(domains) do
    alt:add("DNS", domain)
  end

  local csr = openssl.csr.new()
  csr:setSubject(subject)
  csr:setSubjectAlt(alt)

  csr:setPublicKey(domain_pkey)
  csr:sign(domain_pkey)

  return csr:tostring("DER")
end

local function create_pkey(bits, typ, curve)
  bits = bits or 4096
  typ = typ or 'RSA'
  local pkey = openssl.pkey.new({
    bits = bits,
    type = typ,
    curve = curve,
  })

  return pkey:toPEM('private')
end

return {
    base64_urlencode = base64_urlencode,
    thumbprint = thumbprint,
    create_csr = create_csr,
    create_pkey = create_pkey,
}