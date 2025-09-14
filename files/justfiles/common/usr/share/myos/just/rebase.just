# ===== Config =====
OWNER    := env("OWNER", "nobodywatchin")
REPO     := env("REPO", "bootc-testing")
REGISTRY := env("REGISTRY", "ghcr.io")

set shell := ["bash", "-euo", "pipefail", "-c"]

# Interactive rebase with bootc (no gh login required; public images)
rebase:
    @command -v curl >/dev/null || { echo "Missing 'curl'."; exit 1; }
    @command -v jq   >/dev/null || { echo "Missing 'jq'."; exit 1; }
    @command -v fzf  >/dev/null || { echo "Missing 'fzf'."; exit 1; }

    # 1) Discover image names by scraping the repo's Packages page
    @echo "Discovering images from https://github.com/{{OWNER}}?tab=packages&repo_name={{REPO}} ..."
    @html="$$(curl -fsSL "https://github.com/{{OWNER}}?tab=packages&repo_name={{REPO}}")" || { echo "Failed to fetch packages page"; exit 1; }
    @mapfile -t images < <(printf "%s" "$$html" \
        | grep -oE "/{{OWNER}}/{{REPO}}/pkgs/container/[^\"?]+" \
        | sed -E 's#.*/pkgs/container/##' \
        | sort -u)
    @if [[ $${#images[@]} -eq 0 ]]; then \
        echo "No images found on the packages page (are they public and under {{OWNER}}/{{REPO}}?)"; \
        exit 1; \
      fi

    # 2) Pick image
    @sel_image="$$(printf "%s\n" "$${images[@]}" | fzf --prompt="Select image: ")"
    @test -n "$$sel_image" || { echo "No image selected"; exit 1; }

    # 3) Fetch tags from GHCR v2 (anonymous works for public images)
    @echo "Fetching tags for $$sel_image from {{REGISTRY}} ..."
    @tags_json="$$(curl -fsSL "https://{{REGISTRY}}/v2/{{OWNER}}/$$sel_image/tags/list")" || { echo "Failed to query tags (private package?)"; exit 1; }
    @mapfile -t tags < <(printf "%s" "$$tags_json" | jq -r '.tags[]?' | sort -u)
    @if [[ $${#tags[@]} -eq 0 ]]; then echo "No tags found for $$sel_image"; exit 1; fi

    # 4) Pick tag
    @sel_tag="$$(printf "%s\n" "$${tags[@]}" | fzf --prompt="Select tag: ")"
    @test -n "$$sel_tag" || { echo "No tag selected"; exit 1; }

    # 5) Switch with bootc
    @ref="{{REGISTRY}}/{{OWNER}}/$$sel_image:$$sel_tag"
    @echo "Selected: $$ref"
    @echo "Executing: sudo bootc switch $$ref"
    @sudo bootc switch "$$ref"
    @echo "Done. Reboot when ready."
