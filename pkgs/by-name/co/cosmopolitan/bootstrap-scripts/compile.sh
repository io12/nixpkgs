#!/usr/bin/env bash

# Simple replacement for compile.com that ignores all flags and just runs the command

# Parse and ignore all compile.com flags
while getopts "hnstvwA:C:F:L:M:O:P:S:T:V:" opt; do
  case $opt in
  h) # help - just ignore
    ;;
  n) # do nothing - exit successfully
    exit 0
    ;;
  s | t | v | w) # simple flags - ignore
    ;;
  A | C | F | L | M | O | P | S | T | V) # flags with arguments - ignore
    ;;
  \?) # invalid option - ignore and continue
    ;;
  esac
done

# Shift past all the parsed options
shift $((OPTIND - 1))

# Check if we have a command to run
if [ $# -eq 0 ]; then
  echo "Error: No command specified" >&2
  exit 1
fi

# Execute the remaining arguments as the command
exec "$@"
