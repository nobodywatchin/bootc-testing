REGISTRY := env("REGISTRY", "ghcr.io")
OWNER    := env("OWNER", "nobodywatchin")

set shell := ["bash", "-euo", "pipefail", "-c"]

# Hardcoded list of images
IMAGES = """
alma10-testing-server:latest
alma10-testing-server-nvidia:latest
alma10-testing-workstation:latest
alma10-testing-workstation-nvidia:latest
alma9-testing-server:latest
alma9-testing-server-nvidia:latest
alma9-testing-workstation:latest
alma9-testing-workstation-nvidia:latest
"""

rebase:
    @command -v fzf >/dev/null || { echo "Missing 'fzf'."; exit 1; }

    # Pick an image:tag from the hardcoded list
    @sel="$$(printf '%s\n' {{IMAGES}} | fzf --prompt='Select image: ')"
    @test -n "$$sel" || { echo "No image selected"; exit 1; }

    @ref="{{REGISTRY}}/{{OWNER}}/$$sel"
    @echo "Selected: $$ref"
    @echo "Executing: sudo bootc switch $$ref"
    @sudo bootc switch "$$ref"
    @echo "Done. Reboot when ready."
