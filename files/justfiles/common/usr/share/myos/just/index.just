import '/usr/share/myos/just/default.just'
import '/usr/share/myos/just/update.just'

default:
  @recipe="$(just --summary | grep -v '^default$' | fzf)" && \
  [ -n "$recipe" ] && just "$$recipe" || true
