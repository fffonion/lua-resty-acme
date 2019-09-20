local ffi = require "ffi"

local C = ffi.C
local ffi_gc = ffi.gc
local ffi_new = ffi.new

local _M = {}
local mt = {__index = _M}

require "resty.acme.crypto.openssl.ossl_typ"

ffi.cdef [[
  /** Enum for the point conversion form as defined in X9.62 (ECDSA)
  *  for the encoding of a elliptic curve point (x,y) */
  typedef enum {
    /** the point is encoded as z||x, where the octet z specifies
    *  which solution of the quadratic equation y is  */
    POINT_CONVERSION_COMPRESSED = 2,
      /** the point is encoded as z||x||y, where z is the octet 0x04  */
    POINT_CONVERSION_UNCOMPRESSED = 4,
      /** the point is encoded as z||x||y, where the octet z specifies
      *  which solution of the quadratic equation y is  */
    POINT_CONVERSION_HYBRID = 6
  } point_conversion_form_t;
    
  EC_KEY *EC_KEY_new(void);
  void EC_KEY_free(EC_KEY *key);

  typedef struct ec_group_st EC_GROUP;
  EC_GROUP *EC_GROUP_new_by_curve_name(int nid);
  void EC_GROUP_set_asn1_flag(EC_GROUP *group, int flag);
  void EC_GROUP_set_point_conversion_form(EC_GROUP *group,
    point_conversion_form_t form);
  
  int EC_KEY_set_group(EC_KEY *key, const EC_GROUP *group);
  void EC_GROUP_free(EC_GROUP *group);
  int EC_KEY_generate_key(EC_KEY *key);

  const BIGNUM *EC_KEY_get0_private_key(const EC_KEY *key);
]]
