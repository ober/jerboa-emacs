SCHEME = scheme
LIBDIRS = --libdirs lib:$(HOME)/mine/jerboa/lib:$(HOME)/mine/chez-pcre2:$(HOME)/mine/chez-scintilla/src
export LD_LIBRARY_PATH := $(HOME)/mine/chez-pcre2:$(HOME)/mine/chez-scintilla:$(LD_LIBRARY_PATH)
export CHEZ_SCINTILLA_LIB := $(HOME)/mine/chez-scintilla

.PHONY: all test-tier0 test-tier2 test-tier3 test-tier4 test-tier5 test clean

all: test

test: test-tier0 test-tier2 test-tier3 test-tier4 test-tier5

test-tier0:
	$(SCHEME) $(LIBDIRS) --script tests/test-tier0.ss

test-tier2:
	$(SCHEME) $(LIBDIRS) --script tests/test-tier2.ss

test-tier3:
	$(SCHEME) $(LIBDIRS) --script tests/test-tier3.ss

test-tier4:
	$(SCHEME) $(LIBDIRS) --program tests/test-tier4.ss

test-tier5:
	$(SCHEME) $(LIBDIRS) --program tests/test-tier5.ss

clean:
	find lib -name '*.so' -delete 2>/dev/null; true
