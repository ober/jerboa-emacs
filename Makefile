SCHEME = scheme
JERBOA    = $(HOME)/mine/jerboa
JSH       = $(HOME)/mine/jerboa-shell/src
LIBDIRS   = --libdirs lib:$(JERBOA)/lib:$(JSH):$(HOME)/mine/chez-pcre2:$(HOME)/mine/chez-scintilla/src
JERBUILD  = $(SCHEME) --libdirs $(JERBOA)/lib --script $(JERBOA)/jerbuild.ss
export LD_LIBRARY_PATH := $(HOME)/mine/chez-pcre2:$(HOME)/mine/chez-scintilla:$(LD_LIBRARY_PATH)
export CHEZ_SCINTILLA_LIB := $(HOME)/mine/chez-scintilla

.PHONY: all build rebuild test-tier0 test-tier2 test-tier3 test-tier4 test-tier5 test clean clean-generated

all: build test

# Generate lib/jemacs/*.sls from src/jemacs/*.ss (incremental)
build:
	$(JERBUILD) src/ lib/

# Force regenerate all
rebuild:
	$(JERBUILD) src/ lib/ --force

test: build test-tier0 test-tier2 test-tier3 test-tier4 test-tier5

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

clean-generated:
	rm -rf lib/jemacs/
	rm -f src/.jerbuild-hashes
