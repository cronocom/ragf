# papers/Makefile
# Flexible LaTeX compilation with automatic versioning
# Author: Yamil Rodriguez Montana

# ============================================================================
# CONFIGURATION
# ============================================================================

# Main paper filename (without .tex extension)
PAPER = RAGF_v2_5

# Output version (change this when you want a new version)

# Output filename (constructed automatically)
OUTPUT = $(PAPER).pdf

# LaTeX compiler options
LATEX = pdflatex
LATEX_FLAGS = -interaction=nonstopmode -file-line-error
BIBTEX = bibtex

# ============================================================================
# TARGETS
# ============================================================================

.PHONY: all clean cleanall view help watch draft final

# Default target
all: $(OUTPUT)
	@echo ""
	@echo "✅ Compilation successful!"
	@echo "📄 Output: $(OUTPUT)"
	@echo ""

# Main compilation (4-pass for complete bibliography and references)
$(OUTPUT): $(PAPER).tex
	@echo "📝 Starting compilation of $(PAPER).tex → $(OUTPUT)"
	@echo ""
	@echo "Pass 1/4: Initial compilation..."
	@$(LATEX) $(LATEX_FLAGS) $(PAPER).tex | grep -i "error" || true
	@echo ""
	@echo "Pass 2/4: Processing bibliography..."
	@$(BIBTEX) $(PAPER) | grep -i "error" || true
	@echo ""
	@echo "Pass 3/4: Resolving citations..."
	@$(LATEX) $(LATEX_FLAGS) $(PAPER).tex | grep -i "error" || true
	@echo ""
	@echo "Pass 4/4: Final compilation..."
	@$(LATEX) $(LATEX_FLAGS) $(PAPER).tex | grep -i "error" || true
	@echo ""
	@if [ -f $(PAPER).pdf ]; then \
		mv $(PAPER).pdf $(OUTPUT); \
		echo "✅ Successfully created: $(OUTPUT)"; \
	else \
		echo "❌ Compilation failed. Check $(PAPER).log for errors."; \
		exit 1; \
	fi

# Quick draft (single pass, faster for iterating)
draft:
	@echo "📝 Quick draft compilation..."
	@$(LATEX) $(LATEX_FLAGS) $(PAPER).tex
	@if [ -f $(PAPER).pdf ]; then \
		mv $(PAPER).pdf $(PAPER)_draft.pdf; \
		echo "✅ Draft created: $(PAPER)_draft.pdf"; \
	fi

# Full compilation without moving (keeps PAPER.pdf)
final:
	@echo "📝 Final compilation (keeping original filename)..."
	@$(LATEX) $(LATEX_FLAGS) $(PAPER).tex
	@$(BIBTEX) $(PAPER)
	@$(LATEX) $(LATEX_FLAGS) $(PAPER).tex
	@$(LATEX) $(LATEX_FLAGS) $(PAPER).tex
	@echo "✅ Final PDF: $(PAPER).pdf"

# Clean temporary files
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -f *.aux *.log *.bbl *.blg *.out *.toc *.lof *.lot *.fls *.fdb_latexmk *.synctex.gz
	@echo "✅ Cleaned"

# Clean everything including PDFs
cleanall: clean
	@echo "🗑️  Removing all generated PDFs..."
	@rm -f $(PAPER)*.pdf
	@echo "✅ All clean"

# Compile and open
view: all
	@echo "👀 Opening $(OUTPUT)..."
	@open $(OUTPUT)

# Watch for changes and recompile (requires fswatch)
watch:
	@if command -v fswatch >/dev/null 2>&1; then \
		echo "👀 Watching $(PAPER).tex for changes..."; \
		echo "Press Ctrl+C to stop"; \
		fswatch -o $(PAPER).tex | while read; do \
			clear; \
			echo "🔄 File changed, recompiling..."; \
			make draft; \
		done; \
	else \
		echo "❌ fswatch not installed. Install with: brew install fswatch"; \
	fi

# Show help
help:
	@echo ""
	@echo "📚 RAGF Paper Compilation Makefile"
	@echo "=================================="
	@echo ""
	@echo "Configuration:"
	@echo "  PAPER   = $(PAPER)"
	@echo "  OUTPUT  = $(OUTPUT)"
	@echo ""
	@echo "Available targets:"
	@echo "  make          - Full 4-pass compilation → $(OUTPUT)"
	@echo "  make draft    - Quick single-pass → $(PAPER)_draft.pdf"
	@echo "  make final    - Full compilation keeping $(PAPER).pdf"
	@echo "  make view     - Compile and open PDF"
	@echo "  make clean    - Remove temporary build files"
	@echo "  make cleanall - Remove all generated files (including PDFs)"
	@echo "  make watch    - Auto-recompile on file changes (requires fswatch)"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make          → Creates $(OUTPUT) (RAGF_v2_5.pdf)"
	@echo ""
