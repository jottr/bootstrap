#!/usr/bin/env bash
set -euo pipefail

# The claude-code-home volume is created root-owned; claude needs to write
# credentials and settings there. Shared across all bootstrapped projects so
# login happens once.
sudo chown "$(id -u):$(id -g)" "${HOME}/.claude"

readonly GIT_NAME="jottr"
readonly GIT_EMAIL="jottr@users.noreply.github.com"
readonly SIGNING_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFglxwz2ynsETQlG4A3MKDUpM4D91JKvjDqAmiO1bQow"

git config --global user.name "${GIT_NAME}"
git config --global user.email "${GIT_EMAIL}"
git config --global user.signingkey "${SIGNING_KEY}"
git config --global gpg.format ssh
# The host config points gpg.ssh.program at 1Password's op-ssh-sign (macOS
# binary); inside the container signing must go through ssh-keygen + the
# forwarded agent instead.
git config --global gpg.ssh.program ssh-keygen
git config --global commit.gpgsign true
git config --global tag.forcesignannotated true
git config --global init.defaultbranch main

# Allowed signers file so signature verification works in-container too.
mkdir -p ~/.config/git
echo "${GIT_EMAIL} ${SIGNING_KEY}" > ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers

# The colima virtiofs mount presents workspace files with a different owner
# than the container user; without this git refuses to operate on the repo.
git config --global --add safe.directory '*'

# Repos are cloned via HTTPS on the host; inside the container all GitHub
# access goes over SSH through the forwarded agent.
git config --global url."git@github.com:".insteadOf "https://github.com/"

# Same session-start directive as the host's global CLAUDE.md; the learnings
# file itself is bind-mounted read-only from the host dotfiles repo.
cat > "${HOME}/.claude/CLAUDE.md" <<'EOF'
# Global Claude Instructions

Read `@~/.dotfiles/docs/general-learnings.md` at the start of every session. It contains cross-project preferences, recurring mistakes to avoid, and general working strategies. Apply them throughout the session.
EOF

# Pre-complete Claude Code's first-run gates so an interactive `claude` (e.g.
# `just claude`) starts straight in, authenticating from CLAUDE_CODE_OAUTH_TOKEN
# (devcontainer remoteEnv) instead of dropping to the onboarding/trust screen.
# These flags live in ~/.claude.json, which sits on the container layer — NOT the
# mounted ~/.claude volume — so they must be re-seeded on every create. Both the
# global onboarding flag AND the per-project trust flags are required; a
# non-interactive token login sets neither. Merge-safe and idempotent.
node -e '
  const fs = require("fs");
  const path = process.env.HOME + "/.claude.json";
  let data = {};
  try { data = JSON.parse(fs.readFileSync(path, "utf8")); } catch {}
  data.hasCompletedOnboarding = true;
  const ws = process.cwd();
  data.projects = data.projects || {};
  data.projects[ws] = data.projects[ws] || {};
  data.projects[ws].hasTrustDialogAccepted = true;
  data.projects[ws].hasCompletedProjectOnboarding = true;
  fs.writeFileSync(path, JSON.stringify(data, null, 2));
'

# Trust GitHub host keys for SSH remotes.
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
