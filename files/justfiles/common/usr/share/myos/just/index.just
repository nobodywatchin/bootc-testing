import '/usr/share/myos/just/default.just'
import '/usr/share/myos/just/update.just'

default:
  @if command -v fzf >/dev/null 2>&1; then \
    just --summary | tr ' ' '\n' | grep -v '^default$$' | fzf | xargs -r just; \
  else \
    just --list; \
  fi
