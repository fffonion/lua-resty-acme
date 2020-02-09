<a name="unreleased"></a>
## [Unreleased]


<a name="0.5.0"></a>
## [0.5.0] - 2020-02-09
### feat
- **client:** implement tls-alpn-01 challenge handler [25dc135](https://github.com/fffonion/lua-resty-openssl/commit/25dc135eaf25c604d21b31664bb36e526a72ad2f)

### fix
- **autossl:** add renewal success notice in error log [b1257de](https://github.com/fffonion/lua-resty-openssl/commit/b1257de80bb0e55ff70694bba96bbcf9f9507ae8)
- **autossl:** renew uses unparsed pkey [796b6e3](https://github.com/fffonion/lua-resty-openssl/commit/796b6e3005b4301371ca99b2573e56644a456f01)
- **client:** catch pkey new error in order_certificate [393a573](https://github.com/fffonion/lua-resty-openssl/commit/393a573b3cb7d3c931f3860c4d99e1e5714edb67)
- **client:** refine error message [5aac0fa](https://github.com/fffonion/lua-resty-openssl/commit/5aac0fa92b84ba1b483f6c8d6913e67c7722a7cb)


<a name="0.4.2"></a>
## [0.4.2] - 2019-12-17
### fix
- **autossl:** fix lock on different types of keys [09180a2](https://github.com/fffonion/lua-resty-openssl/commit/09180a25ea7864e07ef3d94ebb3b8456f072f967)
- **client:** json decode on application/problem+json [2aabc1f](https://github.com/fffonion/lua-resty-openssl/commit/2aabc1f5d535f273b97989f5874d45987fa0ebc9)


<a name="0.4.1"></a>
## [0.4.1] - 2019-12-11
### fix
- **client:** log authz final result [52ac754](https://github.com/fffonion/lua-resty-openssl/commit/52ac754d8f888ed2f2ffa7976a5c3d6d18e63a48)


<a name="0.4.0"></a>
## [0.4.0] - 2019-12-11
### feat
- ***:** relying on storage to do cluster level sync [b513009](https://github.com/fffonion/lua-resty-openssl/commit/b513009154cd8dbefdfe84f85c81c920d4104f9d)

### fix
- **client:** use POST-as-GET pattern [7198557](https://github.com/fffonion/lua-resty-openssl/commit/7198557c616ef9f6d7b89809c4eef300a0e690bd)
- **client:** fix parsing challenges [a4a37b5](https://github.com/fffonion/lua-resty-openssl/commit/a4a37b572041dc6a1ea2b24ae14b7dea9e30782f)


<a name="0.3.0"></a>
## [0.3.0] - 2019-11-12
### feat
- **storage:** introduce add/setnx api [895b041](https://github.com/fffonion/lua-resty-openssl/commit/895b041750ef4e920c3ed8ec432353f8e7e8eced)
- **storage:** add consul and vault storage backend [028daa5](https://github.com/fffonion/lua-resty-openssl/commit/028daa5bc965ab10621aa3f16d7ffabe619fd38a)

### fix
- **autossl:** fix typo [7c41e36](https://github.com/fffonion/lua-resty-openssl/commit/7c41e36415d13e364fd58b694c3b4066d60ef1f4)
- **renew:** api name in renew [9ecba64](https://github.com/fffonion/lua-resty-openssl/commit/9ecba64ad928f4570f0f205459f042c06403efb8)
- **storage:** fix third party storage module test [ef3e110](https://github.com/fffonion/lua-resty-openssl/commit/ef3e1107506bfccc843153766ebcae2eee6f82a2)
- **storage:** typo in redis storage, unified interface for file [2dd6cfa](https://github.com/fffonion/lua-resty-openssl/commit/2dd6cfa2c77ab36d0254e1fedb832f2ecabcec99)


<a name="0.1.3"></a>
## [0.1.3] - 2019-10-18
### fix
- ***:** compatibility to use in Kong [6cc5688](https://github.com/fffonion/lua-resty-openssl/commit/6cc568813d03a5ab8311ebdccf77131c204094d9)
- **openssl:** follow up with upstream openssl library API [e791cb3](https://github.com/fffonion/lua-resty-openssl/commit/e791cb302ce04665eaea722e9c0dc2f551f8c829)


<a name="0.1.2"></a>
## [0.1.2] - 2019-09-25
### feat
- **crypto:** ffi support setting subjectAlt [2d992e8](https://github.com/fffonion/lua-resty-openssl/commit/2d992e8973e65617d41c2c49dd9cb259deeaf84f)

### fix
- ***:** reduce test flickiness, fix 1-index [706041b](https://github.com/fffonion/lua-resty-openssl/commit/706041bec1dd062d6d0114619688c8f289b73779)
- ***:** support openssl 1.0, cleanup error handling [1bb82ad](https://github.com/fffonion/lua-resty-openssl/commit/1bb82ada64cab77468878654d324730bd06381e1)
- **openssl:** remove premature error [f1853ab](https://github.com/fffonion/lua-resty-openssl/commit/f1853abbb7a0f19a1bf98de99b70fd5b7779985c)
- **openssl:** fix support for OpenSSL 1.0.2 [42c6e1c](https://github.com/fffonion/lua-resty-openssl/commit/42c6e1c3de59a24da1b31b03ca517b858417e741)


<a name="0.1.1"></a>
## [0.1.1] - 2019-09-20
### feat
- **autossl:** whitelist domains [3dfc058](https://github.com/fffonion/lua-resty-openssl/commit/3dfc05876d5947c869ab2f80cc9ae4e12cf601a8)


<a name="0.1.0"></a>
## 0.1.0 - 2019-09-20
### feat
- ***:** ffi-based openssl backend [ddbc37a](https://github.com/fffonion/lua-resty-openssl/commit/ddbc37a227a5855a5a6caa60606d4534363f3204)
- **autossl:** use lrucache [a6999c7](https://github.com/fffonion/lua-resty-openssl/commit/a6999c7e154d21ff0b71358735527408836f36a7)
- **autossl:** support ecc certs [6ed6a78](https://github.com/fffonion/lua-resty-openssl/commit/6ed6a78e175ba4e6d6511d1c309d239e43b80ef9)
- **crypto:** ffi pkey.new supports DER and public key as well [a18837b](https://github.com/fffonion/lua-resty-openssl/commit/a18837b340f612cc4863903d57e5c3f0225c5919)
- **crypto:** ffi openssl supports generating ec certificates [bc9d989](https://github.com/fffonion/lua-resty-openssl/commit/bc9d989b4eb8bfa954f2f1ab08b0449957a27402)

### fix
- ***:** cleanup [2e8f3ed](https://github.com/fffonion/lua-resty-openssl/commit/2e8f3ed8ac95076537272311338c1256e2a31e67)


[Unreleased]: https://github.com/fffonion/lua-resty-openssl/compare/0.5.0...HEAD
[0.5.0]: https://github.com/fffonion/lua-resty-openssl/compare/0.4.2...0.5.0
[0.4.2]: https://github.com/fffonion/lua-resty-openssl/compare/0.4.1...0.4.2
[0.4.1]: https://github.com/fffonion/lua-resty-openssl/compare/0.4.0...0.4.1
[0.4.0]: https://github.com/fffonion/lua-resty-openssl/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/fffonion/lua-resty-openssl/compare/0.1.3...0.3.0
[0.1.3]: https://github.com/fffonion/lua-resty-openssl/compare/0.1.2...0.1.3
[0.1.2]: https://github.com/fffonion/lua-resty-openssl/compare/0.1.1...0.1.2
[0.1.1]: https://github.com/fffonion/lua-resty-openssl/compare/0.1.0...0.1.1
