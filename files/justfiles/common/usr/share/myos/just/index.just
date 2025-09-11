import '/usr/share/myos/just/default.just'
import '/usr/share/myos/just/update.just'

default:
  @recipe="$(just --summary --justfile /usr/share/myos/just/index.just \
              | grep -v '^default$' \
              | fzf)" && \
  [ -n "$recipe" ] && just --justfile /usr/share/myos/just/index.just "$recipe" || true
