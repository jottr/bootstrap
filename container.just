# Devcontainer lifecycle and in-container tooling.

set shell := ["bash", "-euc"]

[private]
default:
    @just --list container

# Every plain `devcontainer` invocation targets this workspace; wrap it once.
[private]
_dc verb *args:
    devcontainer {{ verb }} --workspace-folder . {{ args }}

# Run a command in the container with secrets.env resolved at runtime. The
# Claude token reaches the container via devcontainer remoteEnv and never
# touches disk, argv, or container config.
[private]
_authed +cmd: up
    #!/usr/bin/env bash
    set -euo pipefail
    command -v op >/dev/null 2>&1 || {
      echo "error: 1Password CLI 'op' not found (brew install --cask 1password-cli@beta)." >&2; exit 1; }
    op run --env-file=secrets.env --no-masking -- \
      devcontainer exec --workspace-folder . {{ cmd }}

[doc('Build and start the devcontainer')]
up: (_dc "up")

[doc('Recreate the devcontainer (after config changes or a colima restart)')]
rebuild: (_dc "up" "--remove-existing-container")

[doc('Interactive shell inside the devcontainer (Claude token available)')]
shell: (_authed "bash")

[doc('Run a command inside the devcontainer, e.g. `just container run git status`')]
run +args: (_dc "exec" args)

[doc('Run Claude Code inside the devcontainer, authenticated from 1Password')]
claude *args: (_authed ("claude " + args))

[doc('Stop the devcontainer')]
down:
    docker ps --quiet --filter "label=devcontainer.local_folder=$(pwd)" \
      | xargs --no-run-if-empty docker stop
