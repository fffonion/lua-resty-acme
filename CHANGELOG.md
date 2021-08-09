<a name="unreleased"></a>
## [Unreleased]


<a name="0.7.1"></a>
## [0.7.1] - 2021-07-22
### bug fixes
- ***:** popup errors from lower functions [a19e9c8](https://github.com/fffonion/lua-resty-acme/commit/a19e9c8af9179a81815c653d176aa0bfc27e532b)
- **autossl:** pass storage config to acme client ([#43](https://github.com/fffonion/lua-resty-acme/issues/43)) [ef1e541](https://github.com/fffonion/lua-resty-acme/commit/ef1e54112d1bdda187812a0e6c96d8b134fd4d04)

### features
- **autossl:** add challenge_start_delay [df4ba0b](https://github.com/fffonion/lua-resty-acme/commit/df4ba0b71a1f92b87d7f9f203475bc7115c56b9a)
- **autossl:** check if domain is whitelisted before cert renewal ([#35](https://github.com/fffonion/lua-resty-acme/issues/35)) [942c007](https://github.com/fffonion/lua-resty-acme/commit/942c007711ba1a0f04b8f30f81443a46ae0ed412)
- **client:** add challenge_start_callback [1c9b2d5](https://github.com/fffonion/lua-resty-acme/commit/1c9b2d5a03eb644cc0770ec54e4d711bc03cdd42)
- **client:** allow to read "alternate" link and select preferred chain ([#42](https://github.com/fffonion/lua-resty-acme/issues/42)) [ff17a74](https://github.com/fffonion/lua-resty-acme/commit/ff17a741d36f2058a21621c9191fda8513cb2c73)
- **storage/vault:** add support for kubernetes auth ([#37](https://github.com/fffonion/lua-resty-acme/issues/37)) [93c2121](https://github.com/fffonion/lua-resty-acme/commit/93c212132a5d28b93269675c63a88a4e452001dc)


<a name="0.6.2"></a>
## [0.6.2] - 2021-07-22
### bug fixes
- ***:** popup errors from lower functions [4e25b4d](https://github.com/fffonion/lua-resty-acme/commit/4e25b4dc4b10a77594546eaaceefe0418c91c3b7)
- **autossl:** pass storage config to acme client ([#43](https://github.com/fffonion/lua-resty-acme/issues/43)) [102312f](https://github.com/fffonion/lua-resty-acme/commit/102312f51711ad0a5d12a30909fbb76134f973bd)

### features
- **autossl:** add challenge_start_delay [abc2e2e](https://github.com/fffonion/lua-resty-acme/commit/abc2e2eab2eb1220096163f84fdeee09df193db4)
- **client:** add challenge_start_callback [2dc8df7](https://github.com/fffonion/lua-resty-acme/commit/2dc8df782b95d593dfbdea2186d2b8ab5d6af6be)


<a name="0.7.0"></a>
## [0.7.0] - 2021-06-25
### bug fixes
- ***:** popup errors from lower functions [a19e9c8](https://github.com/fffonion/lua-resty-acme/commit/a19e9c8af9179a81815c653d176aa0bfc27e532b)
- **autossl:** pass storage config to acme client ([#43](https://github.com/fffonion/lua-resty-acme/issues/43)) [ef1e541](https://github.com/fffonion/lua-resty-acme/commit/ef1e54112d1bdda187812a0e6c96d8b134fd4d04)

### features
- **autossl:** check if domain is whitelisted before cert renewal ([#35](https://github.com/fffonion/lua-resty-acme/issues/35)) [942c007](https://github.com/fffonion/lua-resty-acme/commit/942c007711ba1a0f04b8f30f81443a46ae0ed412)
- **client:** allow to read "alternate" link and select preferred chain ([#42](https://github.com/fffonion/lua-resty-acme/issues/42)) [ff17a74](https://github.com/fffonion/lua-resty-acme/commit/ff17a741d36f2058a21621c9191fda8513cb2c73)
- **storage/vault:** add support for kubernetes auth ([#37](https://github.com/fffonion/lua-resty-acme/issues/37)) [93c2121](https://github.com/fffonion/lua-resty-acme/commit/93c212132a5d28b93269675c63a88a4e452001dc)


<a name="0.6.1"></a>
## [0.6.1] - 2021-06-25
### bug fixes
- ***:** popup errors from lower functions [4e25b4d](https://github.com/fffonion/lua-resty-acme/commit/4e25b4dc4b10a77594546eaaceefe0418c91c3b7)
- **autossl:** pass storage config to acme client ([#43](https://github.com/fffonion/lua-resty-acme/issues/43)) [102312f](https://github.com/fffonion/lua-resty-acme/commit/102312f51711ad0a5d12a30909fbb76134f973bd)
- **autossl:** get_certkey always returning raw PEM text instead of cdata ([#33](https://github.com/fffonion/lua-resty-acme/issues/33)) [a1782c9](https://github.com/fffonion/lua-resty-acme/commit/a1782c994209450fc41deca8bf970d005fd17126)
- **client:** retry on bad nonce ([#34](https://github.com/fffonion/lua-resty-acme/issues/34)) [bed74d3](https://github.com/fffonion/lua-resty-acme/commit/bed74d367c23c430a73d0bcd0764417cbec7b40e)
- **client:** trigger only pending challenges ([#32](https://github.com/fffonion/lua-resty-acme/issues/32)) [3e3e940](https://github.com/fffonion/lua-resty-acme/commit/3e3e940a187e58dbb414fe543a11964454567c63)
- **tls-alpn-01:** delegate get_ssl_ctx to lua-resty-openssl [cd99b84](https://github.com/fffonion/lua-resty-acme/commit/cd99b8481a7b57adc344fbae4b0c66fa09f8086b)


<a name="0.6.0"></a>
## [0.6.0] - 2021-02-19
### bug fixes
- **autossl:** check if domain is set before trying to alter it ([#27](https://github.com/fffonion/lua-resty-acme/issues/27)) [fe36fc9](https://github.com/fffonion/lua-resty-acme/commit/fe36fc992b2d1c834eb8acbb8489f88f814653c4)
- **autossl:** returns error in update_cert_handler ([#25](https://github.com/fffonion/lua-resty-acme/issues/25)) [a7dff99](https://github.com/fffonion/lua-resty-acme/commit/a7dff99ef5dc30dcecbea534b124231c5b0aa9cf)
- **client:** BREAKING: do not force /directory at the end of api_url ([#31](https://github.com/fffonion/lua-resty-acme/issues/31)) [e4ea134](https://github.com/fffonion/lua-resty-acme/commit/e4ea134a0214f9df6f73fa8d31621cc96a382a6c)
- **client:** allow charset Content-Type header of ACME responses ([#30](https://github.com/fffonion/lua-resty-acme/issues/30)) [3a9ade6](https://github.com/fffonion/lua-resty-acme/commit/3a9ade62867d304835fb888f3dfbdc872afc133d)
- **openssl:** fix version import [6cb94be](https://github.com/fffonion/lua-resty-acme/commit/6cb94beb4b3911e28e55aa0b40ba547357e862e0)


<a name="0.5.11"></a>
## [0.5.11] - 2021-01-05
### bug fixes
- **storage/etcd:** fix etcd list, add and add tests [7ddc1b4](https://github.com/fffonion/lua-resty-acme/commit/7ddc1b4a5e0c40850fa7f3d62bc460398518a7aa)

### features
- **storage:** add etcd storage backend ([#13](https://github.com/fffonion/lua-resty-acme/issues/13)) [841e0c3](https://github.com/fffonion/lua-resty-acme/commit/841e0c3b527c442fdf0a7dc75c71d5cc8088b194)


<a name="0.5.10"></a>
## [0.5.10] - 2020-12-08
### features
- ***:** allow to set account key in client and use account key from storage in autossl [6ec9ef5](https://github.com/fffonion/lua-resty-acme/commit/6ec9ef5bbb54d2afb437dcc423c4f410ae8f15f0)
- **tls-alpn-01:** mark compatible with 1.19.3 [bec79ec](https://github.com/fffonion/lua-resty-acme/commit/bec79eca8b748f419e8b0f50b3393f6134331b4d)


<a name="0.5.9"></a>
## [0.5.9] - 2020-11-26
### bug fixes
- **autossl:** always use lower cased domain [7fb0c83](https://github.com/fffonion/lua-resty-acme/commit/7fb0c83439dd3e7841bbb192ff2b6ed599e06ed2)
- **tests:** correct asn1parse result in tests [99a8b01](https://github.com/fffonion/lua-resty-acme/commit/99a8b0121a7a75d0c233f9acd17b53f55739fe79)

### features
- ***:** external account binding (EAB) support ([#19](https://github.com/fffonion/lua-resty-acme/issues/19)) [91383ed](https://github.com/fffonion/lua-resty-acme/commit/91383ed114f8a81d09f1b91394c831376e3233bb)


<a name="0.5.8"></a>
## [0.5.8] - 2020-09-10
### bug fixes
- **autossl:** emit renewal success log correctly [63ee6ef](https://github.com/fffonion/lua-resty-acme/commit/63ee6ef7c3540b2d17ee546d5f005dd4df537c6e)
- **storage:** vault backend uses correct TTL [21c4044](https://github.com/fffonion/lua-resty-acme/commit/21c4044f0bb560c3269c38289975598d3793726b)

### features
- **autossl:** expose get_certkey function [#10](https://github.com/fffonion/lua-resty-acme/issues/10) [daaaf5f](https://github.com/fffonion/lua-resty-acme/commit/daaaf5fa7cc83166af6df6d60f1219664000b018)
- **autossl:** add domain_whitelist_callback for dynamic domain matching [#9](https://github.com/fffonion/lua-resty-acme/issues/9) [dfe6991](https://github.com/fffonion/lua-resty-acme/commit/dfe6991445b032fe257162f9f479f04d243c3f2a)


<a name="0.5.7"></a>
## [0.5.7] - 2020-08-31
### bug fixes
- **tls-alpn-01:** support openresty 1.17.8 [8e93d3b](https://github.com/fffonion/lua-resty-acme/commit/8e93d3ba8be84ae4bd688a84d8bb5109765258e5)


<a name="0.5.6"></a>
## [0.5.6] - 2020-08-12
### bug fixes
- **tests:** pin lua-nginx-module and lua-resty-core [6266c56](https://github.com/fffonion/lua-resty-acme/commit/6266c5651e54c56442cef2584303781d16f84d3a)


<a name="0.5.5"></a>
## [0.5.5] - 2020-06-29
### bug fixes
- **storage:** remove slash in consul and vault key path [5ddf210](https://github.com/fffonion/lua-resty-acme/commit/5ddf21071ce06a7e003a381440ff75df3faff78e)


<a name="0.5.4"></a>
## [0.5.4] - 2020-06-24
### features
- **vault:** allow overriding tls options in vault storage [fed57b9](https://github.com/fffonion/lua-resty-acme/commit/fed57b9cc2a1d080dd10af398aeb48b1b55874d7)


<a name="0.5.3"></a>
## [0.5.3] - 2020-05-18
### features
- **storage:** fully implement the file storage backend ([#6](https://github.com/fffonion/lua-resty-acme/issues/6)) [f1183e4](https://github.com/fffonion/lua-resty-acme/commit/f1183e4c4947dad6edd185631358f1d705a2d98e)


<a name="0.5.2"></a>
## [0.5.2] - 2020-04-27
### bug fixes
- ***:** allow API endpoint to include or exclude /directory part [c7feb94](https://github.com/fffonion/lua-resty-acme/commit/c7feb944db40dc7d8e571cc09594aebffc496bd7)


<a name="0.5.1"></a>
## [0.5.1] - 2020-04-25
### bug fixes
- ***:** fix domain key sanity check and http-01 challenge matching [687de21](https://github.com/fffonion/lua-resty-acme/commit/687de2134335278697220cf67ef0b26c4be34e07)
- **client:** better error handling on directory request [984bfad](https://github.com/fffonion/lua-resty-acme/commit/984bfad031cef1a6ee3554c8c736ace596ed10d3)


<a name="0.5.0"></a>
## [0.5.0] - 2020-02-09
### bug fixes
- **autossl:** add renewal success notice in error log [b1257de](https://github.com/fffonion/lua-resty-acme/commit/b1257de80bb0e55ff70694bba96bbcf9f9507ae8)
- **autossl:** renew uses unparsed pkey [796b6e3](https://github.com/fffonion/lua-resty-acme/commit/796b6e3005b4301371ca99b2573e56644a456f01)
- **client:** catch pkey new error in order_certificate [393a573](https://github.com/fffonion/lua-resty-acme/commit/393a573b3cb7d3c931f3860c4d99e1e5714edb67)
- **client:** refine error message [5aac0fa](https://github.com/fffonion/lua-resty-acme/commit/5aac0fa92b84ba1b483f6c8d6913e67c7722a7cb)

### features
- **client:** implement tls-alpn-01 challenge handler [25dc135](https://github.com/fffonion/lua-resty-acme/commit/25dc135eaf25c604d21b31664bb36e526a72ad2f)


<a name="0.4.2"></a>
## [0.4.2] - 2019-12-17
### bug fixes
- **autossl:** fix lock on different types of keys [09180a2](https://github.com/fffonion/lua-resty-acme/commit/09180a25ea7864e07ef3d94ebb3b8456f072f967)
- **client:** json decode on application/problem+json [2aabc1f](https://github.com/fffonion/lua-resty-acme/commit/2aabc1f5d535f273b97989f5874d45987fa0ebc9)


<a name="0.4.1"></a>
## [0.4.1] - 2019-12-11
### bug fixes
- **client:** log authz final result [52ac754](https://github.com/fffonion/lua-resty-acme/commit/52ac754d8f888ed2f2ffa7976a5c3d6d18e63a48)


<a name="0.4.0"></a>
## [0.4.0] - 2019-12-11
### bug fixes
- **client:** use POST-as-GET pattern [7198557](https://github.com/fffonion/lua-resty-acme/commit/7198557c616ef9f6d7b89809c4eef300a0e690bd)
- **client:** fix parsing challenges [a4a37b5](https://github.com/fffonion/lua-resty-acme/commit/a4a37b572041dc6a1ea2b24ae14b7dea9e30782f)

### features
- ***:** relying on storage to do cluster level sync [b513009](https://github.com/fffonion/lua-resty-acme/commit/b513009154cd8dbefdfe84f85c81c920d4104f9d)


<a name="0.3.0"></a>
## [0.3.0] - 2019-11-12
### bug fixes
- **autossl:** fix typo [7c41e36](https://github.com/fffonion/lua-resty-acme/commit/7c41e36415d13e364fd58b694c3b4066d60ef1f4)
- **renew:** api name in renew [9ecba64](https://github.com/fffonion/lua-resty-acme/commit/9ecba64ad928f4570f0f205459f042c06403efb8)
- **storage:** fix third party storage module test [ef3e110](https://github.com/fffonion/lua-resty-acme/commit/ef3e1107506bfccc843153766ebcae2eee6f82a2)
- **storage:** typo in redis storage, unified interface for file [2dd6cfa](https://github.com/fffonion/lua-resty-acme/commit/2dd6cfa2c77ab36d0254e1fedb832f2ecabcec99)

### features
- **storage:** introduce add/setnx api [895b041](https://github.com/fffonion/lua-resty-acme/commit/895b041750ef4e920c3ed8ec432353f8e7e8eced)
- **storage:** add consul and vault storage backend [028daa5](https://github.com/fffonion/lua-resty-acme/commit/028daa5bc965ab10621aa3f16d7ffabe619fd38a)


<a name="0.1.3"></a>
## [0.1.3] - 2019-10-18
### bug fixes
- ***:** compatibility to use in Kong [6cc5688](https://github.com/fffonion/lua-resty-acme/commit/6cc568813d03a5ab8311ebdccf77131c204094d9)
- **openssl:** follow up with upstream openssl library API [e791cb3](https://github.com/fffonion/lua-resty-acme/commit/e791cb302ce04665eaea722e9c0dc2f551f8c829)


<a name="0.1.2"></a>
## [0.1.2] - 2019-09-25
### bug fixes
- ***:** reduce test flickiness, fix 1-index [706041b](https://github.com/fffonion/lua-resty-acme/commit/706041bec1dd062d6d0114619688c8f289b73779)
- ***:** support openssl 1.0, cleanup error handling [1bb82ad](https://github.com/fffonion/lua-resty-acme/commit/1bb82ada64cab77468878654d324730bd06381e1)
- **openssl:** remove premature error [f1853ab](https://github.com/fffonion/lua-resty-acme/commit/f1853abbb7a0f19a1bf98de99b70fd5b7779985c)
- **openssl:** fix support for OpenSSL 1.0.2 [42c6e1c](https://github.com/fffonion/lua-resty-acme/commit/42c6e1c3de59a24da1b31b03ca517b858417e741)

### features
- **crypto:** ffi support setting subjectAlt [2d992e8](https://github.com/fffonion/lua-resty-acme/commit/2d992e8973e65617d41c2c49dd9cb259deeaf84f)


<a name="0.1.1"></a>
## [0.1.1] - 2019-09-20
### features
- **autossl:** whitelist domains [3dfc058](https://github.com/fffonion/lua-resty-acme/commit/3dfc05876d5947c869ab2f80cc9ae4e12cf601a8)


<a name="0.1.0"></a>
## 0.1.0 - 2019-09-20
### bug fixes
- ***:** cleanup [2e8f3ed](https://github.com/fffonion/lua-resty-acme/commit/2e8f3ed8ac95076537272311338c1256e2a31e67)

### features
- ***:** ffi-based openssl backend [ddbc37a](https://github.com/fffonion/lua-resty-acme/commit/ddbc37a227a5855a5a6caa60606d4534363f3204)
- **autossl:** use lrucache [a6999c7](https://github.com/fffonion/lua-resty-acme/commit/a6999c7e154d21ff0b71358735527408836f36a7)
- **autossl:** support ecc certs [6ed6a78](https://github.com/fffonion/lua-resty-acme/commit/6ed6a78e175ba4e6d6511d1c309d239e43b80ef9)
- **crypto:** ffi pkey.new supports DER and public key as well [a18837b](https://github.com/fffonion/lua-resty-acme/commit/a18837b340f612cc4863903d57e5c3f0225c5919)
- **crypto:** ffi openssl supports generating ec certificates [bc9d989](https://github.com/fffonion/lua-resty-acme/commit/bc9d989b4eb8bfa954f2f1ab08b0449957a27402)


[Unreleased]: https://github.com/fffonion/lua-resty-acme/compare/0.7.1...HEAD
[0.7.1]: https://github.com/fffonion/lua-resty-acme/compare/0.6.2...0.7.1
[0.6.2]: https://github.com/fffonion/lua-resty-acme/compare/0.7.0...0.6.2
[0.7.0]: https://github.com/fffonion/lua-resty-acme/compare/0.6.1...0.7.0
[0.6.1]: https://github.com/fffonion/lua-resty-acme/compare/0.6.0...0.6.1
[0.6.0]: https://github.com/fffonion/lua-resty-acme/compare/0.5.11...0.6.0
[0.5.11]: https://github.com/fffonion/lua-resty-acme/compare/0.5.10...0.5.11
[0.5.10]: https://github.com/fffonion/lua-resty-acme/compare/0.5.9...0.5.10
[0.5.9]: https://github.com/fffonion/lua-resty-acme/compare/0.5.8...0.5.9
[0.5.8]: https://github.com/fffonion/lua-resty-acme/compare/0.5.7...0.5.8
[0.5.7]: https://github.com/fffonion/lua-resty-acme/compare/0.5.6...0.5.7
[0.5.6]: https://github.com/fffonion/lua-resty-acme/compare/0.5.5...0.5.6
[0.5.5]: https://github.com/fffonion/lua-resty-acme/compare/0.5.4...0.5.5
[0.5.4]: https://github.com/fffonion/lua-resty-acme/compare/0.5.3...0.5.4
[0.5.3]: https://github.com/fffonion/lua-resty-acme/compare/0.5.2...0.5.3
[0.5.2]: https://github.com/fffonion/lua-resty-acme/compare/0.5.1...0.5.2
[0.5.1]: https://github.com/fffonion/lua-resty-acme/compare/0.5.0...0.5.1
[0.5.0]: https://github.com/fffonion/lua-resty-acme/compare/0.4.2...0.5.0
[0.4.2]: https://github.com/fffonion/lua-resty-acme/compare/0.4.1...0.4.2
[0.4.1]: https://github.com/fffonion/lua-resty-acme/compare/0.4.0...0.4.1
[0.4.0]: https://github.com/fffonion/lua-resty-acme/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/fffonion/lua-resty-acme/compare/0.1.3...0.3.0
[0.1.3]: https://github.com/fffonion/lua-resty-acme/compare/0.1.2...0.1.3
[0.1.2]: https://github.com/fffonion/lua-resty-acme/compare/0.1.1...0.1.2
[0.1.1]: https://github.com/fffonion/lua-resty-acme/compare/0.1.0...0.1.1
