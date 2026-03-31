#!/bin/bash
# jemacs-rc.sh — Helper functions for Claude to interact with jemacs-qt
#
# Usage:
#   source scripts/jemacs-rc.sh
#   jemacs-start          # launch headless jemacs-qt with REPL
#   jemacs-eval '(+ 1 2)' # evaluate Scheme expression
#   jemacs-keys C-x 2     # send key sequence
#   jemacs-screenshot      # capture screenshot to /tmp/jemacs.png
#   jemacs-state           # query app state
#   jemacs-stop            # kill headless jemacs-qt

JEMACS_REPL_PORT_FILE="$HOME/.jerboa-repl-port"
JEMACS_SCREENSHOT="/tmp/jemacs.png"
_JEMACS_EVAL_ID=0
_JEMACS_PID=""

jemacs-port() {
  if [ -f "$JEMACS_REPL_PORT_FILE" ]; then
    grep -oP '\d+' "$JEMACS_REPL_PORT_FILE"
  else
    echo "ERROR: no REPL port file" >&2
    return 1
  fi
}

jemacs-eval() {
  local port
  port=$(jemacs-port) || return 1
  _JEMACS_EVAL_ID=$((_JEMACS_EVAL_ID + 1))
  echo "($_JEMACS_EVAL_ID eval \"$1\")" | nc -q1 127.0.0.1 "$port" 2>/dev/null
}

jemacs-keys() {
  local args=""
  for key in "$@"; do
    args="$args \"$key\""
  done
  jemacs-eval "(send-keys!$args)"
}

# Async key send — for commands that open a minibuffer (M-x, C-x C-f, etc.)
jemacs-keys-async() {
  local args=""
  for key in "$@"; do
    args="$args \"$key\""
  done
  jemacs-eval "(send-keys-async!$args)"
}

jemacs-screenshot() {
  local path="${1:-$JEMACS_SCREENSHOT}"
  jemacs-eval "(screenshot! \"$path\")"
  echo "$path"
}

jemacs-state() {
  jemacs-eval "(app-state)"
}

jemacs-start() {
  # Check if already running
  if [ -f "$JEMACS_REPL_PORT_FILE" ]; then
    local port
    port=$(jemacs-port)
    if echo "(99 eval \"#t\")" | nc -q1 127.0.0.1 "$port" >/dev/null 2>&1; then
      echo "jemacs-qt already running on port $port"
      return 0
    fi
  fi
  rm -f "$JEMACS_REPL_PORT_FILE"

  # Static binary can't use QT_QPA_PLATFORM=offscreen (only xcb is compiled in).
  # Use xvfb-run to create a virtual X11 display instead.
  if [ -x ./jemacs-qt ]; then
    xvfb-run -a ./jemacs-qt --repl 0 &
    _JEMACS_PID=$!
  else
    # Interpreted mode: use offscreen platform (dynamically loaded)
    QT_QPA_PLATFORM=offscreen LD_PRELOAD=./qt_chez_shim.so \
      scheme --libdirs "lib:$HOME/mine/jerboa/lib:$HOME/mine/jerboa-shell/src:$HOME/mine/chez-gherkin:$HOME/mine/chez-pcre2:$HOME/mine/chez-scintilla/src:$HOME/mine/chez-qt" \
      --script qt-main.ss --repl 0 &
    _JEMACS_PID=$!
  fi

  # Wait for REPL port file to appear (up to 10s)
  for i in $(seq 1 30); do
    [ -f "$JEMACS_REPL_PORT_FILE" ] && break
    sleep 0.3
  done
  if [ -f "$JEMACS_REPL_PORT_FILE" ]; then
    echo "jemacs-qt running (PID $_JEMACS_PID). REPL port: $(jemacs-port)"
  else
    echo "ERROR: jemacs-qt failed to start within 10s" >&2
    [ -n "$_JEMACS_PID" ] && kill "$_JEMACS_PID" 2>/dev/null
    return 1
  fi
}

jemacs-stop() {
  # Try tracked PID first, then port-based lookup
  if [ -n "$_JEMACS_PID" ] && kill -0 "$_JEMACS_PID" 2>/dev/null; then
    kill "$_JEMACS_PID" 2>/dev/null
    wait "$_JEMACS_PID" 2>/dev/null
    echo "Killed jemacs-qt (PID $_JEMACS_PID)"
    _JEMACS_PID=""
  else
    local port
    port=$(jemacs-port 2>/dev/null)
    if [ -n "$port" ]; then
      local pid
      pid=$(lsof -ti :"$port" 2>/dev/null | head -1)
      if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null
        echo "Killed jemacs-qt (PID $pid)"
      else
        echo "No running jemacs-qt found"
      fi
    else
      echo "No running jemacs-qt found"
    fi
  fi
  rm -f "$JEMACS_REPL_PORT_FILE"
}
