#!/usr/bin/env bash
# Phoenix Package Handler - Installer
# UnitedSys - United Systems | jwl247
# curl -fsSL https://raw.githubusercontent.com/jwl247/Phoenix-Package_handler/main/install.sh | bash

set -euo pipefail

REPO_URL="https://github.com/jwl247/Phoenix-Package_handler.git"
INSTALL_DIR="$HOME/Phoenix/package-handler"
CLONEPOOL_DIR="$HOME/Phoenix/clonepool"
WORKER_URL="https://packages-worker.phoenix-jwl.workers.dev"
ENV_FILE="$HOME/.phoenix_env"

G="\033[0;32m"; Y="\033[0;33m"; N="\033[0m"
ok()  { echo -e "${G}[OK]${N} $1"; }
log() { echo -e "${Y}[PHOENIX]${N} $1"; }

echo ""
echo -e "${Y}================================${N}"
echo -e "${Y}  PHOENIX PACKAGE HANDLER${N}"
echo -e "${Y}  UnitedSys - United Systems${N}"
echo -e "${Y}================================${N}"
echo ""

# Dependencies
log "Checking dependencies..."
for dep in git curl python3; do
  if ! command -v $dep &>/dev/null; then
      log "Installing $dep..."
          sudo apt-get install -y $dep &>/dev/null || true
            fi
            done
            ok "Dependencies ready"

            # Clone or update repo
            log "Fetching Phoenix Package Handler..."
            if [[ -d "$INSTALL_DIR/.git" ]]; then
              git -C "$INSTALL_DIR" pull --ff-only &>/dev/null
              else
                mkdir -p "$INSTALL_DIR"
                  git clone "$REPO_URL" "$INSTALL_DIR" &>/dev/null
                  fi
                  ok "Repo ready"

                  # Directories
                  mkdir -p "$CLONEPOOL_DIR" "$HOME/.unitedsys/logs"
                  ok "Directories ready"

                  # Environment
                  {
                    echo "# Phoenix DevOps OS - Environment"
                      echo "export PHOENIX_WORKER_URL=\"$WORKER_URL\""
                        echo "export CLONEPOOL_DIR=\"$CLONEPOOL_DIR\""
                          echo "export PATH=\"$INSTALL_DIR/intake:\$PATH\""
                          } > "$ENV_FILE"

                          grep -q "phoenix_env" "$HOME/.bashrc" 2>/dev/null || \
                            echo '[[ -f ~/.phoenix_env ]] && source ~/.phoenix_env' >> "$HOME/.bashrc"
                            grep -q "phoenix_env" "$HOME/.zshrc" 2>/dev/null || \
                              echo '[[ -f ~/.phoenix_env ]] && source ~/.phoenix_env' >> "$HOME/.zshrc" 2>/dev/null || true
                              ok "Environment configured"

                              # intake command
                              chmod +x "$INSTALL_DIR/intake/intake.sh"
                              sudo ln -sf "$INSTALL_DIR/intake/intake.sh" /usr/local/bin/intake 2>/dev/null || \
                                { mkdir -p "$HOME/.local/bin" && ln -sf "$INSTALL_DIR/intake/intake.sh" "$HOME/.local/bin/intake" 2>/dev/null || true; }
                                ok "intake command ready"

                                echo ""
                                echo -e "${G}================================${N}"
                                echo -e "${G}  PHOENIX IS ACTIVE${N}"
                                echo -e "${G}================================${N}"
                                echo ""
                                echo "  Restart your terminal or run:  source ~/.phoenix_env"
                                echo "  Then use:  intake ./yourfile.sh"
                                echo ""
                                echo "  Glossary access: authenticcoder.com"
                                echo ""
