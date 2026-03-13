SCHEME = scheme
LIBDIRS = --libdirs lib:$(HOME)/mine/jerboa/lib:$(HOME)/mine/chez-pcre2
export LD_LIBRARY_PATH := $(HOME)/mine/chez-pcre2:$(LD_LIBRARY_PATH)

.PHONY: all test-tier0 clean

all: test-tier0

test-tier0:
	$(SCHEME) $(LIBDIRS) --script tests/test-tier0.ss

clean:
	find lib -name '*.so' -delete 2>/dev/null; true
