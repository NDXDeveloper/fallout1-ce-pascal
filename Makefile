# ============================================================================
# Fallout 1 Community Edition - Free Pascal Port
# ============================================================================
#
# Usage:
#   make            Build release (default)
#   make rebuild    Full release rebuild
#   make debug      Build with range checks and line info
#   make run        Build and run
#   make clean      Remove intermediate build artifacts
#   make clean-all  Remove all build artifacts including binary
#   make count      Count remaining 'external name' declarations
#   make loc        Count lines of Pascal source code
#
# ============================================================================

# -- Toolchain ---------------------------------------------------------------
FPC        := fpc
SRCDIR     := src
BUILDDIR   := lib
BINDIR     := bin
TARGET     := $(BINDIR)/fallout_ce
LPR        := fallout_ce.lpr

# -- Unit search paths -------------------------------------------------------
UNIT_DIRS  := \
  $(SRCDIR)/types           \
  $(SRCDIR)/plib/gnw        \
  $(SRCDIR)/plib/assoc      \
  $(SRCDIR)/plib/color      \
  $(SRCDIR)/plib/db         \
  $(SRCDIR)/platform        \
  $(SRCDIR)                 \
  $(SRCDIR)/game            \
  $(SRCDIR)/int             \
  $(SRCDIR)/thirdparty/fpattern \
  $(SRCDIR)/thirdparty/adecode  \
  $(BUILDDIR)

FU_FLAGS   := $(foreach d,$(UNIT_DIRS),-Fu$(d))

# -- Base flags --------------------------------------------------------------
FPCFLAGS   := -Mobjfpc $(FU_FLAGS) -FU$(BUILDDIR) -o$(TARGET)

# -- Release flags (default) -------------------------------------------------
RELEASE_FLAGS := -O2 -Xs

# -- Debug flags -------------------------------------------------------------
DEBUG_FLAGS := -Cr -gl

# -- Colors ------------------------------------------------------------------
GREEN      := \033[1;32m
CYAN       := \033[1;36m
YELLOW     := \033[1;33m
RED        := \033[1;31m
RESET      := \033[0m

# ============================================================================
# Targets
# ============================================================================

.PHONY: all build rebuild debug debug-rebuild run run-debug clean clean-all count loc help

all: build

# Ensure output directories exist
$(BUILDDIR) $(BINDIR):
	mkdir -p $@

# Incremental release build (recompiles only changed units)
build: | $(BUILDDIR) $(BINDIR)
	@printf "$(CYAN)--- Release build ---$(RESET)\n"
	@$(FPC) $(FPCFLAGS) $(RELEASE_FLAGS) $(LPR) && \
		printf "$(GREEN)OK$(RESET)  $(TARGET)\n" || \
		(printf "$(RED)BUILD FAILED$(RESET)\n"; exit 1)

# Full release rebuild (recompiles everything)
rebuild: | $(BUILDDIR) $(BINDIR)
	@printf "$(CYAN)--- Release rebuild ---$(RESET)\n"
	@$(FPC) $(FPCFLAGS) $(RELEASE_FLAGS) -B $(LPR) && \
		printf "$(GREEN)OK$(RESET)  $(TARGET)\n" || \
		(printf "$(RED)BUILD FAILED$(RESET)\n"; exit 1)

# Incremental debug build (range checks + line info for tracebacks)
debug: | $(BUILDDIR) $(BINDIR)
	@printf "$(CYAN)--- Debug build ---$(RESET)\n"
	@$(FPC) $(FPCFLAGS) $(DEBUG_FLAGS) $(LPR) && \
		printf "$(GREEN)OK$(RESET)  $(TARGET)\n" || \
		(printf "$(RED)BUILD FAILED$(RESET)\n"; exit 1)

# Full debug rebuild
debug-rebuild: | $(BUILDDIR) $(BINDIR)
	@printf "$(CYAN)--- Debug rebuild ---$(RESET)\n"
	@$(FPC) $(FPCFLAGS) $(DEBUG_FLAGS) -B $(LPR) && \
		printf "$(GREEN)OK$(RESET)  $(TARGET)\n" || \
		(printf "$(RED)BUILD FAILED$(RESET)\n"; exit 1)

# Build (release) then run
run: build
	@printf "$(CYAN)--- Running ---$(RESET)\n"
	cd $(BINDIR) && ./fallout_ce

# Build (debug) then run
run-debug: debug
	@printf "$(CYAN)--- Running (debug) ---$(RESET)\n"
	cd $(BINDIR) && ./fallout_ce

# Remove intermediate build artifacts (.o, .ppu, .s) but keep the binary
clean:
	@printf "$(YELLOW)Cleaning build artifacts...$(RESET)\n"
	@test -d $(BUILDDIR) && find $(BUILDDIR) -maxdepth 1 -type f \( -name "*.o" -o -name "*.ppu" -o -name "*.s" -o -name "ppas.sh" \) -delete || true
	@find $(SRCDIR) -type f \( -name "*.o" -o -name "*.ppu" -o -name "*.s" \) -delete
	@printf "$(GREEN)Clean.$(RESET)\n"

# Remove everything: intermediate artifacts + compiled binary
clean-all: clean
	@rm -f $(TARGET)
	@printf "$(GREEN)Binary removed.$(RESET)\n"

# Count remaining external name declarations (track porting progress)
count:
	@echo "Remaining 'external name' declarations:"
	@grep -rc "external name" $(SRCDIR)/ --include="*.pas" | grep -v ":0" | sort -t: -k2 -nr
	@echo "---"
	@echo -n "Total: "
	@grep -rc "external name" $(SRCDIR)/ --include="*.pas" | grep -v ":0" | cut -d: -f2 | paste -sd+ | bc

# Count lines of Pascal source code
loc:
	@echo "Lines of Pascal source:"
	@find $(SRCDIR) -name "*.pas" -exec cat {} + | wc -l
	@echo "---"
	@echo "Files:"
	@find $(SRCDIR) -name "*.pas" | wc -l

help:
	@echo "Fallout 1 CE - Pascal Port"
	@echo ""
	@echo "  make              Incremental release build (default)"
	@echo "  make rebuild      Full release rebuild"
	@echo "  make debug        Incremental debug build (range checks + tracebacks)"
	@echo "  make debug-rebuild Full debug rebuild"
	@echo "  make run          Build release and run"
	@echo "  make run-debug    Build debug and run"
	@echo "  make clean        Remove intermediate artifacts (.o, .ppu, .s)"
	@echo "  make clean-all    Remove all artifacts including binary"
	@echo "  make count        Count remaining external name stubs"
	@echo "  make loc          Count lines of Pascal source"
	@echo "  make help         Show this message"
