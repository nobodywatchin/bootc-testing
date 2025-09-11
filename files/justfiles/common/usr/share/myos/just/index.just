# Import Justfiles
import '/usr/share/myos/just/update.just'

# Get all recipes, strip the column headers, feed into fzf, run the selection
default:
  recipe=$$(just --summary --justfile /usr/share/myos/just/index.just | awk '{print $$1}' | fzf) && \
    just --justfile /usr/share/myos/just/index.just "$$recipe"