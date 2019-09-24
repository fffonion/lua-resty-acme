OPENRESTY_PREFIX=/usr/local/openresty

#LUA_VERSION := 5.1
PREFIX ?=          /usr/local
LUA_INCLUDE_DIR ?= $(PREFIX)/include
LUA_LIB_DIR ?=     $(PREFIX)/lib/lua/$(LUA_VERSION)
INSTALL ?= install

.PHONY: all test install

all: ;

DIRS = acme acme/storage acme/crypto/openssl acme/challenge

$(DIRS):
	$(INSTALL) -d $(DESTDIR)$(LUA_LIB_DIR)/resty/$@
	$(INSTALL) lib/resty/$@/*.lua $(DESTDIR)$(LUA_LIB_DIR)/resty/$@

install: all $(DIRS)
	
test: all
	PATH=$(OPENRESTY_PREFIX)/nginx/sbin:$$PATH prove -I../test-nginx/lib -r t


