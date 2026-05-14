#!/usr/bin/env sh
# shiprocket-api-skill installer for macOS and Linux.
#
# Two ways to run:
#
#   1. Inside a cloned checkout:
#        ./install.sh
#
#   2. One-liner (replace REPO_URL with the published repo before publishing):
#        curl -fsSL https://raw.githubusercontent.com/aditya-m-bharadwaj/shiprocket-api-skill/main/install.sh | sh
#
# Flags (env vars):
#   SHIPROCKET_CTL_PREFIX   target dir for the symlink     (default: ~/.local/bin)
#   SHIPROCKET_CTL_HOME     where to clone the repo        (default: ~/.local/share/shiprocket-api-skill)
#   SHIPROCKET_CTL_REPO     git URL to clone               (default: REPO_URL placeholder)
#   SHIPROCKET_CTL_REF      branch/tag/SHA to check out    (default: main)
#   INSTALL_SKILL           1 = also install Claude skill  (default: 0; prompts if interactive)
#   RUN_SETUP               1 = run `shiprocket-api-skill setup` after install (default: prompts if interactive)
#   NO_SETUP                1 = never prompt to run setup
#
# This script:
#   * verifies Python 3.8+,
#   * clones the repo (or uses the current checkout),
#   * symlinks `bin/shiprocket-api-skill` into the prefix dir,
#   * optionally installs the Claude skill into ~/.claude/skills/shiprocket-api-skill/,
#   * optionally runs `shiprocket-api-skill setup` so you can paste credentials now.
#
# Credentials are read by Python's getpass (input hidden, never echoed). They
# are never seen by this shell script, never appear in argv or environment,
# and never written to disk in cleartext (the JWT goes to the OS keystore, or
# to a mode-0600 file as fallback; the email/password are discarded).

set -eu

REPO_URL_DEFAULT="https://github.com/aditya-m-bharadwaj/shiprocket-api-skill.git"
REF_DEFAULT="main"

PREFIX="${SHIPROCKET_CTL_PREFIX:-$HOME/.local/bin}"
HOME_DIR="${SHIPROCKET_CTL_HOME:-$HOME/.local/share/shiprocket-api-skill}"
REPO_URL="${SHIPROCKET_CTL_REPO:-$REPO_URL_DEFAULT}"
REF="${SHIPROCKET_CTL_REF:-$REF_DEFAULT}"
INSTALL_SKILL="${INSTALL_SKILL:-}"
RUN_SETUP="${RUN_SETUP:-}"
NO_SETUP="${NO_SETUP:-}"

say()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# 1. Locate or clone the repo --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/bin/shiprocket-api-skill" ]; then
    SRC="$SCRIPT_DIR"
    say "Using current checkout: $SRC"
else
    command -v git >/dev/null 2>&1 || die "git is required but not installed."
    if [ -d "$HOME_DIR/.git" ]; then
        say "Updating existing checkout at $HOME_DIR"
        git -C "$HOME_DIR" fetch --quiet --tags
        git -C "$HOME_DIR" checkout --quiet "$REF"
        git -C "$HOME_DIR" pull --quiet --ff-only || warn "could not fast-forward; continuing on $REF"
    else
        say "Cloning $REPO_URL -> $HOME_DIR (ref=$REF)"
        mkdir -p "$(dirname "$HOME_DIR")"
        git clone --quiet --branch "$REF" "$REPO_URL" "$HOME_DIR" \
          || die "git clone failed. Set SHIPROCKET_CTL_REPO if you forked, or run from a checkout."
    fi
    SRC="$HOME_DIR"
fi

[ -f "$SRC/bin/shiprocket-api-skill" ] || die "bin/shiprocket-api-skill not found in $SRC"

# 2. Verify Python 3.8+ --------------------------------------------------------
PY=""
for cand in python3 python; do
    if command -v "$cand" >/dev/null 2>&1; then
        v="$("$cand" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || echo "")"
        case "$v" in
            3.[89]|3.1[0-9]|3.[2-9][0-9]) PY="$cand"; break ;;
            *) ;;
        esac
    fi
done
[ -n "$PY" ] || die "Python 3.8+ is required. Install it (e.g. \`brew install python\` on macOS, \`apt install python3\` on Debian/Ubuntu) and re-run."
say "Python: $PY ($($PY --version 2>&1))"

# 3. chmod +x + symlink --------------------------------------------------------
chmod +x "$SRC/bin/shiprocket-api-skill"
mkdir -p "$PREFIX"
LINK="$PREFIX/shiprocket-api-skill"
ln -sfn "$SRC/bin/shiprocket-api-skill" "$LINK"
say "Symlinked: $LINK -> $SRC/bin/shiprocket-api-skill"

# 4. PATH check ---------------------------------------------------------------
case ":$PATH:" in
    *":$PREFIX:"*) ;;
    *) warn "$PREFIX is not on your PATH."
       warn "Add to your shell rc (~/.bashrc or ~/.zshrc):"
       warn "    export PATH=\"\$HOME/.local/bin:\$PATH\""
       ;;
esac

# 5. Optional: Claude skill ---------------------------------------------------
SKILL_SRC="$SRC/.claude/skills/shiprocket-api-skill/SKILL.md"
SKILL_DST_DIR="$HOME/.claude/skills/shiprocket-api-skill"
if [ -f "$SKILL_SRC" ]; then
    install_skill=0
    if [ "$INSTALL_SKILL" = "1" ]; then
        install_skill=1
    elif [ -t 0 ]; then
        printf "Install the Claude skill to %s ? [y/N] " "$SKILL_DST_DIR"
        read -r ans
        case "$ans" in y|Y|yes|YES) install_skill=1 ;; esac
    fi
    if [ "$install_skill" = "1" ]; then
        mkdir -p "$SKILL_DST_DIR"
        cp "$SKILL_SRC" "$SKILL_DST_DIR/SKILL.md"
        say "Skill installed: $SKILL_DST_DIR/SKILL.md"
    fi
fi

# 6. Optional: run `shiprocket-api-skill setup` so the user can enter credentials now ---
#
# If the script's stdin is not a TTY (e.g. `curl … | sh`), we re-attach to the
# user's terminal via /dev/tty. That way getpass can hide the password even
# when the install pipeline isn't interactive. The credentials still go only
# into the Python process — this shell script never sees them.
run_setup=0
if [ "$NO_SETUP" = "1" ]; then
    run_setup=0
elif [ "$RUN_SETUP" = "1" ]; then
    run_setup=1
elif [ -t 0 ] || [ -r /dev/tty ]; then
    if [ -t 0 ]; then
        printf "Run \`shiprocket-api-skill setup\` now to add your API-user credentials? [Y/n] "
        read -r ans
    else
        printf "Run \`shiprocket-api-skill setup\` now to add your API-user credentials? [Y/n] " > /dev/tty
        read -r ans < /dev/tty || ans=""
    fi
    case "$ans" in
        ""|y|Y|yes|YES) run_setup=1 ;;
        *) run_setup=0 ;;
    esac
fi

if [ "$run_setup" = "1" ]; then
    say "Launching: shiprocket-api-skill setup"
    if [ -t 0 ]; then
        "$LINK" setup
    else
        # Re-attach stdin to the controlling terminal so getpass can hide input.
        "$LINK" setup < /dev/tty
    fi
fi

# 7. Done ---------------------------------------------------------------------
echo
say "Installed. Next steps:"
if [ "$run_setup" != "1" ]; then
    say "  1. Run:  shiprocket-api-skill setup           # enter API-user email + password (password hidden)"
    say "  2. Run:  shiprocket-api-skill whoami          # verify auth"
else
    say "  1. Run:  shiprocket-api-skill whoami          # verify auth"
fi
say "  - To change credentials later:  shiprocket-api-skill setup        (or 'rotate-token')"
say "  - To remove the local JWT:      shiprocket-api-skill uninstall-token --yes"
say "  - JWT lifetime is ~10 days. Re-run setup when whoami returns 401."
say "  - Read: $SRC/README.md"
