# Dev workflow: the devcontainer (see .devcontainer/) is the dev
# environment; these recipes wrap its lifecycle.

set shell := ["bash", "-euc"]

default:
    @just --list

# ---- Devcontainer ----------------------------------------------------------

[doc('Build and start the devcontainer')]
up:
    devcontainer up --workspace-folder .

[doc('Recreate the devcontainer (after config changes or a colima restart)')]
rebuild:
    devcontainer up --workspace-folder . --remove-existing-container

[doc('Interactive shell inside the devcontainer')]
shell:
    devcontainer exec --workspace-folder . bash

[doc('Run a command inside the devcontainer, e.g. `just run git status`')]
run +args:
    devcontainer exec --workspace-folder . {{ args }}

[doc('Run Claude Code inside the devcontainer (first run: `claude login`)')]
claude *args:
    devcontainer exec --workspace-folder . claude {{ args }}

[doc('Stop the devcontainer')]
down:
    docker ps --quiet --filter "label=devcontainer.local_folder=$(pwd)" \
      | xargs --no-run-if-empty docker stop
