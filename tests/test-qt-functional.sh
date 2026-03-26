#!/bin/bash
# test-qt-functional.sh — End-to-end Qt functional tests
#
# Launches jemacs-qt on a virtual X display (Xvfb), sends real keyboard
# events via xdotool, and queries buffer state via the IPC REPL.
#
# Requirements: xvfb, xdotool, nc (netcat)
# Usage: ./tests/test-qt-functional.sh [path-to-jemacs-qt-binary]

set -u

BINARY="${1:-./jemacs-qt}"
REPL_PORT=7779
XVFB_DISPLAY=:98
PASS=0
FAIL=0
TOTAL=0

# --- Helpers ---

repl() {
  echo "$1" | nc -w 2 -q 1 localhost $REPL_PORT 2>/dev/null | sed -n '2s/^jerboa> //p'
}

get_text() {
  repl '(qt-plain-text-edit-text (qt-current-editor (app-state-frame *app*)))'
}

get_cursor() {
  repl '(qt-plain-text-edit-cursor-position (qt-current-editor (app-state-frame *app*)))'
}

get_buffer() {
  repl '(qt-current-buffer (app-state-frame *app*))'
}

send_key() {
  DISPLAY=$XVFB_DISPLAY xdotool key --window $WID "$@"
}

send_type() {
  DISPLAY=$XVFB_DISPLAY xdotool type --window $WID --delay 80 "$1"
}

go_scratch() {
  # Keep pressing previous-buffer until we're in scratch
  for i in $(seq 1 10); do
    local buf=$(get_buffer)
    echo "$buf" | grep -q "scratch" && return 0
    repl '(execute-command! *app* (quote previous-buffer))' >/dev/null 2>&1
    sleep 0.2
  done
  echo "  WARNING: could not get back to scratch"
}

assert_eq() {
  TOTAL=$((TOTAL + 1))
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "        expected: $expected"
    echo "        actual:   $actual"
  fi
}

assert_contains() {
  TOTAL=$((TOTAL + 1))
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "        expected to contain: $needle"
    echo "        actual: $haystack"
  fi
}

assert_not_contains() {
  TOTAL=$((TOTAL + 1))
  local desc="$1" needle="$2" haystack="$3"
  if ! echo "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "        expected NOT to contain: $needle"
    echo "        actual: $haystack"
  fi
}

# --- Setup ---

echo "=== Qt Functional Tests ==="
echo ""

# Check prerequisites
for cmd in xvfb-run xdotool nc; do
  command -v $cmd >/dev/null 2>&1 || { echo "ERROR: $cmd not installed"; exit 1; }
done
[ -x "$BINARY" ] || { echo "ERROR: $BINARY not found or not executable"; exit 1; }

# Kill any old instances
pkill -f "Xvfb $XVFB_DISPLAY" 2>/dev/null || true
pkill -f "jemacs-qt.*$REPL_PORT" 2>/dev/null || true
sleep 1

# Start Xvfb
Xvfb $XVFB_DISPLAY -screen 0 1280x1024x24 &>/dev/null &
XVFB_PID=$!
sleep 1

# Start jemacs-qt
DISPLAY=$XVFB_DISPLAY GEMACS_REPL_PORT=$REPL_PORT "$BINARY" &>/tmp/jemacs-qt-test.log &
JEMACS_PID=$!

# Wait for window
WID=""
for i in $(seq 1 30); do
  WID=$(DISPLAY=$XVFB_DISPLAY xdotool search --name "jemacs" 2>/dev/null | head -1)
  [ -n "$WID" ] && break
  sleep 0.5
done

if [ -z "$WID" ]; then
  echo "ERROR: jemacs window not found after 15s"
  kill $JEMACS_PID $XVFB_PID 2>/dev/null
  exit 1
fi

# Wait for REPL
for i in $(seq 1 20); do
  nc -z localhost $REPL_PORT 2>/dev/null && break
  sleep 0.5
done

if ! nc -z localhost $REPL_PORT 2>/dev/null; then
  echo "ERROR: REPL not ready on port $REPL_PORT"
  kill $JEMACS_PID $XVFB_PID 2>/dev/null
  exit 1
fi

echo "Setup: Xvfb=$XVFB_PID jemacs=$JEMACS_PID WID=$WID REPL=$REPL_PORT"
echo ""

# Focus the window
DISPLAY=$XVFB_DISPLAY xdotool windowfocus --sync $WID
sleep 0.5

# Navigate to scratch buffer
go_scratch
sleep 0.3

# --- Tests ---

echo "--- Text insertion ---"
# Use chars that are NOT chord-start characters to avoid chord pending delay
# Chord-start chars cover: A B C E F G I J K L M N O R S T V W X Z
# Safe chars: d h p q u y
send_type "dhp"
sleep 0.5
AFTER_TEXT=$(get_text)
assert_contains "typing 'dhp' inserts text" "dhp" "$AFTER_TEXT"

echo ""
echo "--- Backspace ---"
POS_BEFORE=$(get_cursor)
send_key BackSpace
sleep 0.3
POS_AFTER=$(get_cursor)
TEXT_AFTER=$(get_text)
assert_eq "backspace moves cursor back 1" "$((POS_BEFORE - 1))" "$POS_AFTER"
assert_not_contains "backspace removes last typed char" "dhp" "$TEXT_AFTER"

# Delete remaining 'dh'
send_key BackSpace
sleep 0.1
send_key BackSpace
sleep 0.3
POS_CLEAN=$(get_cursor)
assert_eq "3 backspaces return cursor to 0" "0" "$POS_CLEAN"

echo ""
echo "--- C-a (beginning of line) ---"
send_type "hpd"
sleep 0.5
send_key ctrl+a
sleep 0.3
POS=$(get_cursor)
assert_eq "C-a moves to beginning of line" "0" "$POS"
# Clean up
send_key ctrl+shift+k
sleep 0.2

echo ""
echo "--- C-e (end of line) ---"
# Type some text first so there's content to move to end of
send_type "quy"
sleep 0.3
send_key ctrl+a
sleep 0.2
POS_START=$(get_cursor)
send_key ctrl+e
sleep 0.3
POS_END=$(get_cursor)
TOTAL=$((TOTAL + 1))
if [ "$POS_END" -gt "$POS_START" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: C-e moves to end of line (pos=$POS_START -> $POS_END)"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: C-e should move cursor forward (pos=$POS_START -> $POS_END)"
fi
# Clean up typed text
send_key ctrl+a
sleep 0.1
send_key ctrl+shift+k
sleep 0.2

echo ""
echo "--- Key chord TM → vterm ---"
go_scratch
sleep 0.3
send_key --delay 20 t m
sleep 0.8
BUF=$(get_buffer)
assert_contains "chord TM triggers vterm (switches to terminal)" "terminal" "$BUF"

echo ""
echo "--- Chord reliability (5 trials) ---"
CHORD_PASS=0
for i in $(seq 1 5); do
  go_scratch
  sleep 0.3
  send_key --delay 30 t m
  sleep 0.5
  BUF=$(get_buffer)
  if echo "$BUF" | grep -q "terminal"; then
    CHORD_PASS=$((CHORD_PASS + 1))
  fi
done
TOTAL=$((TOTAL + 1))
if [ "$CHORD_PASS" -eq 5 ]; then
  PASS=$((PASS + 1))
  echo "  PASS: chord TM triggered $CHORD_PASS/5 times"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: chord TM triggered $CHORD_PASS/5 times (expected 5/5)"
fi

echo ""
echo "--- C-x 2 (split window) ---"
go_scratch
sleep 0.3
send_key ctrl+x
sleep 0.1
send_key 2
sleep 0.5
# Verify via REPL that split happened
RESULT=$(repl '(execute-command! *app* (quote delete-other-windows))')
# If delete-other-windows succeeded without error, split was there
TOTAL=$((TOTAL + 1))
if [ "$RESULT" = "#<void>" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: C-x 2 splits window (delete-other-windows succeeds)"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: C-x 2 split window (result: $RESULT)"
fi

echo ""
echo "--- Backspace in shell-script file buffer ---"
# Create a temp shell script and open it — shell-buffer? returns #t for these,
# which previously caused backspace to silently fail (no shell state = no delete)
TMPFILE=$(mktemp /tmp/test-jemacs-XXXXXX.sh)
echo '#!/bin/bash' > "$TMPFILE"
echo 'echo hello' >> "$TMPFILE"
repl "(qt-open-file! *app* \"$TMPFILE\")" >/dev/null 2>&1
sleep 1
# Move cursor to position 5 and backspace
repl '(let ((ed (qt-current-editor (app-state-frame *app*)))) (sci-send ed 2025 5 0))' >/dev/null 2>&1
sleep 0.2
POS_BEFORE=$(get_cursor)
repl '(execute-command! *app* (quote backward-delete-char))' >/dev/null 2>&1
sleep 0.3
POS_AFTER=$(get_cursor)
assert_eq "backspace works in shell script file" "$((POS_BEFORE - 1))" "$POS_AFTER"
rm -f "$TMPFILE"
# Go back to scratch
go_scratch
sleep 0.3

echo ""
echo "--- IPC REPL error handling ---"
ERR_RESULT=$(repl 'nonexistent-var')
assert_contains "REPL handles unbound var" "not bound" "$ERR_RESULT"

ERR_RESULT2=$(repl '(/ 1 0)')
assert_contains "REPL handles division by zero" "undefined for 0" "$ERR_RESULT2"

OK_RESULT=$(repl '(+ 40 2)')
assert_eq "REPL evaluates expressions" "42" "$OK_RESULT"

# --- Cleanup ---

echo ""
echo "=========================================="
echo "TEST RESULTS: $PASS passed, $FAIL failed (of $TOTAL)"
echo "=========================================="

kill $JEMACS_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Log: /tmp/jemacs-qt-test.log"
  exit 1
fi
exit 0
