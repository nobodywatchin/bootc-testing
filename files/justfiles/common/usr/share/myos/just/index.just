import '/usr/share/myos/just/update.just'

default:
  @recipe="$(just --summary --justfile /usr/share/myos/just/index.just | fzf)" && \
  [ -n "$recipe" ] && just --justfile /usr/share/myos/just/index.just "$recipe" || true
