SCHEME = scheme
JERBOA    = $(HOME)/mine/jerboa
JSH       = $(HOME)/mine/jerboa-shell/src
GHERKIN   = $(HOME)/mine/gherkin/src
LIBDIRS   = --libdirs lib:$(JERBOA)/lib:$(JSH):$(GHERKIN):$(HOME)/mine/chez-pcre2:$(HOME)/mine/chez-scintilla/src
JERBUILD  = $(SCHEME) --libdirs $(JERBOA)/lib --script $(JERBOA)/jerbuild.ss
export LD_LIBRARY_PATH := $(HOME)/mine/chez-pcre2:$(HOME)/mine/chez-scintilla:$(HOME)/mine/jerboa-shell:$(LD_LIBRARY_PATH)
export CHEZ_SCINTILLA_LIB := $(HOME)/mine/chez-scintilla

.PHONY: all build rebuild run test-tier0 test-tier2 test-tier3 test-tier4 test-tier5 test-org test clean clean-generated

all: build test

# Generate lib/jerboa-emacs/*.sls from src/jerboa-emacs/*.ss (incremental)
build:
	$(JERBUILD) src/ lib/

# Force regenerate all
rebuild:
	$(JERBUILD) src/ lib/ --force

run: build
	$(SCHEME) $(LIBDIRS) --script main.ss

test: build test-tier0 test-tier2 test-tier3 test-tier4 test-tier5 test-org

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

test-org: test-org-parse test-org-clock test-org-table test-org-agenda \
          test-org-babel test-org-capture test-org-export test-org-list \
          test-persist

test-org-parse:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-parse.ss

test-org-clock:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-clock.ss

test-org-table:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-table.ss

test-org-agenda:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-agenda.ss

test-org-babel:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-babel.ss

test-org-capture:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-capture.ss

test-org-export:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-export.ss

test-org-list:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-list.ss

test-persist:
	$(SCHEME) $(LIBDIRS) --script tests/test-persist.ss

clean:
	find lib -name '*.so' -delete 2>/dev/null; true

clean-generated:
	rm -rf lib/jerboa-emacs/
	rm -f src/.jerbuild-hashes
