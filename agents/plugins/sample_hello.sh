#!/bin/bash
echo "Hello from the sample plugin!"
if (($# > 0)); then
  printf 'Args:'
  printf ' %s' "$@"
  printf '\n'
else
  echo "Args: (none)"
fi
