import '/usr/share/myos/just/default.just'
import '/usr/share/myos/just/update.just'

default:
  @choice="$$(just --summary | tr ' ' '\n' | grep -v '^default$$' | fzf)"; \
  [ -n "$$choice" ] && exec just "$$choice" || true
