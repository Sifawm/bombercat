#!/bin/sh
# Runs the rules-layer tests headless. Exits non-zero on a failed check or a script error.
cd "$(dirname "$0")" || exit 1
godot --headless --import >/dev/null 2>&1  # refreshes the class_name cache
output=$(godot --headless -s tests/run_tests.gd 2>&1)
status=$?
echo "$output" | grep -E "^(FAIL|     |[0-9]+ tests)|ERROR|at: |Parse Error" | head -40
if echo "$output" | grep -q "ERROR"; then exit 1; fi
exit $status
