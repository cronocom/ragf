#!/bin/bash

# run_analysis.sh - Execute escalation analysis

set -e

cd "$(dirname "$0")"

echo "🔬 Running RAGF Escalation Analysis..."
echo ""

# Check if venv exists and activate it
if [ -d ".venv" ]; then
    echo "✅ Activating virtual environment..."
    source .venv/bin/activate
fi

# Install numpy if not present
python3 -c "import numpy" 2>/dev/null || {
    echo "📦 Installing numpy..."
    pip install numpy
}

# Run analysis
echo "📊 Generating metrics..."
python3 scripts/analyze_escalations.py

echo ""
echo "✨ Analysis complete!"
echo ""
echo "📁 Results saved in: results/escalation_analysis/"
echo ""
echo "Next: Review the metrics and update papers/RAGF_v2_5.tex"
