#!/usr/bin/env bash
# assert-epic-gate.sh — Verify epic capsule completion before release
#
# Usage: assert-epic-gate.sh <release|merge|discard>
#
# Checks:
#   - specs/AUDIT_LATEST.md exists and contains PASS verdict
#   - specs/verifications/ contains per-story verification evidence
#   - specs/epics/archive/ contains completed epic capsules
#
# Exit 0 on pass, exit 1 on fail.

set -euo pipefail

MODE="${1:-release}"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
SPECS_DIR="$PROJECT_DIR/specs"

echo "=== assert-epic-gate.sh: mode=$MODE ==="

FAILURES=0

# 1. Check AUDIT_LATEST.md exists and passes
AUDIT_FILE="$SPECS_DIR/AUDIT_LATEST.md"
if [ ! -f "$AUDIT_FILE" ]; then
    # Check for alternative audit artifacts
    if [ -f "$SPECS_DIR/verifications/AUDIT_LATEST.md" ]; then
        AUDIT_FILE="$SPECS_DIR/verifications/AUDIT_LATEST.md"
    elif [ -f "$SPECS_DIR/verifications/AUDIT-*.md" ]; then
        AUDIT_FILE=$(ls "$SPECS_DIR/verifications/AUDIT-"*.md | head -1)
    fi
fi

if [ -f "$AUDIT_FILE" ]; then
    if grep -qi "PASS" "$AUDIT_FILE" && ! grep -qi "FAIL" "$AUDIT_FILE"; then
        echo "PASS: Audit artifact found: $AUDIT_FILE"
    else
        echo "FAIL: Audit artifact $AUDIT_FILE does not contain PASS verdict"
        FAILURES=$((FAILURES + 1))
    fi
else
    echo "FAIL: No audit artifact found (checked AUDIT_LATEST.md, verifications/AUDIT_LATEST.md, verifications/AUDIT-*.md)"
    FAILURES=$((FAILURES + 1))
fi

# 2. Check verification evidence exists
VERIFICATIONS_DIR="$SPECS_DIR/verifications"
if [ -d "$VERIFICATIONS_DIR" ]; then
    VERIF_COUNT=$(find "$VERIFICATIONS_DIR" -name "*-verify.yaml" 2>/dev/null | wc -l)
    if [ "$VERIF_COUNT" -gt 0 ]; then
        echo "PASS: Verification evidence found: $VERIF_COUNT task verifications"
    else
        echo "FAIL: No per-task verification files found in $VERIFICATIONS_DIR"
        FAILURES=$((FAILURES + 1))
    fi
else
    echo "FAIL: Verifications directory not found: $VERIFICATIONS_DIR"
    FAILURES=$((FAILURES + 1))
fi

# 3. Check epic capsule archive exists
EPICS_ARCHIVE="$SPECS_DIR/epics/archive"
if [ -d "$EPICS_ARCHIVE" ]; then
    ARCHIVED_EPICS=$(find "$EPICS_ARCHIVE" -maxdepth 1 -type d 2>/dev/null | tail -n +2 | wc -l)
    if [ "$ARCHIVED_EPICS" -gt 0 ]; then
        echo "PASS: Archived epics found: $ARCHIVED_EPICS"
    else
        echo "WARN: No archived epics in $EPICS_ARCHIVE"
    fi
else
    echo "WARN: Epics archive directory not found: $EPICS_ARCHIVE"
fi

# 4. Check state.yaml workflow_mode
STATE_FILE="$SPECS_DIR/state.yaml"
if [ -f "$STATE_FILE" ]; then
    WORKFLOW_MODE=$(grep 'workflow_mode:' "$STATE_FILE" | head -1 | sed 's/.*workflow_mode:[[:space:]]*//' | tr -d '"')
    echo "INFO: workflow_mode = $WORKFLOW_MODE"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "=== assert-epic-gate.sh: PASS ==="
    exit 0
else
    echo "=== assert-epic-gate.sh: FAIL ($FAILURES failures) ==="
    exit 1
fi