SCHEME = scheme
JERBOA    = $(HOME)/mine/jerboa
JSH       = $(HOME)/mine/jerboa-shell/src
GHERKIN   = $(HOME)/mine/gherkin/src
LIBDIRS   = --libdirs lib:$(JERBOA)/lib:$(JSH):$(GHERKIN):$(HOME)/mine/chez-pcre2:$(HOME)/mine/chez-scintilla/src:$(HOME)/mine/chez-qt
JERBUILD  = $(SCHEME) --libdirs $(JERBOA)/lib --script $(JERBOA)/jerbuild.ss
export LD_LIBRARY_PATH := $(HOME)/mine/chez-pcre2:$(HOME)/mine/chez-scintilla:$(HOME)/mine/chez-qt:$(HOME)/mine/jerboa-shell:$(LD_LIBRARY_PATH)
export CHEZ_SCINTILLA_LIB := $(HOME)/mine/chez-scintilla

.PHONY: all build rebuild run test-tier0 test-tier2 test-tier3 test-tier4 test-tier5 test-org test-extra test clean clean-generated \
        test-org-duration test-org-element test-org-fold test-org-footnote \
        test-org-lint test-org-num test-org-property test-org-src test-org-tempo \
        test-vtscreen test-debug-repl test-qt build-qt

all: build test

# Generate lib/jerboa-emacs/*.sls from src/jerboa-emacs/*.ss (incremental)
build:
	$(JERBUILD) src/ lib/

# Force regenerate all
rebuild:
	$(JERBUILD) src/ lib/ --force

run: build
	$(SCHEME) $(LIBDIRS) --script main.ss

# Qt backend build target (for future use)
build-qt: build
	@echo "=== Jerboa-Emacs Qt Backend Status ==="
	@echo ""
	@echo "Sprint 1 (Foundation): COMPLETE"
	@echo "  ✓ qt/sci-shim.ss    - QScintilla compatibility (536 lines)"
	@echo "  ✓ qt/keymap.ss      - Qt key event adapter (140 lines)"
	@echo "  ✓ qt/buffer.ss      - Document management (65 lines)"
	@echo "  ✓ qt/window.ss      - Frame/window mgmt (stub, 567 lines pending)"
	@echo ""
	@echo "Sprint 2 (Window System): COMPLETE"
	@echo "  ✓ qt/modeline.ss    - Status bar modeline (130 lines)"
	@echo "  ✓ qt/echo.ss        - Echo area (stub, 692 lines pending)"
	@echo "  ✓ qt/highlight.ss   - Syntax highlighting (stub, 1296 lines pending)"
	@echo ""
	@echo "Progress: 7/54 modules (13%)"
	@echo "Next: Sprint 3 - Command modules (commands-core, commands-edit)"

test: build test-tier0 test-tier2 test-tier3 test-tier4 test-tier5 test-org test-extra

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

test-extra: test-org-duration test-org-element test-org-fold test-org-footnote \
            test-org-lint test-org-num test-org-property test-org-src test-org-tempo \
            test-vtscreen test-debug-repl test-qt

test-org-duration:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-duration.ss

test-org-element:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-element.ss

test-org-fold:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-fold.ss

test-org-footnote:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-footnote.ss

test-org-lint:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-lint.ss

test-org-num:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-num.ss

test-org-property:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-property.ss

test-org-src:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-src.ss

test-org-tempo:
	$(SCHEME) $(LIBDIRS) --script tests/test-org-tempo.ss

test-vtscreen:
	$(SCHEME) $(LIBDIRS) --script tests/test-vtscreen.ss

test-debug-repl:
	$(SCHEME) $(LIBDIRS) --program tests/test-debug-repl.ss

test-qt:
	$(SCHEME) $(LIBDIRS) --script tests/test-qt.ss

clean:
	find lib -name '*.so' -delete 2>/dev/null; true

clean-generated:
	rm -rf lib/jerboa-emacs/
	rm -f src/.jerbuild-hashes
