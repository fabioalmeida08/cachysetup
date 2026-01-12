#!/bin/bash

# ==============================================================================
# SCRIPT DE PÓS-INSTALAÇÃO E CONFIGURAÇÃO DE AMBIENTE (CachyOS/Arch)
# Objetivo: Instalação de pacotes, troca de DM (SDDM -> Ly) e gestão de dotfiles.
# ==============================================================================

# Interrompe a execução se qualquer comando falhar
set -e

# --- Definição de Cores para Feedback Visual ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

echo -e "${GREEN}--- Iniciando configuração do ambiente ---${NC}"

# ------------------------------------------------------------------------------
# 1. INSTALAÇÃO DE PACOTES SISTEMA
# ------------------------------------------------------------------------------
echo -e "${YELLOW}>>> Instalando pacotes base e ferramentas de UI...${NC}"
# Nota: --needed evita reinstalar o que já está atualizado
sudo pacman -S --needed --noconfirm \
    quickshell noctalia-shell wlsunset nwg-look adw-gtk-theme \
    pavucontrol-qt stow yay lsd ufw ttf-firacode-nerd \
    matugen zoxide fzf zen-browser neovim qt6ct \
    cliphist cava power-profiles-daemon ddcutil \
    protonup-qt mangohud lib32-mangohud

echo -e "${GREEN}--- Definindo esquema de cores: Dark Mode ---${NC}"
gsettings set org.gnome.desktop.interface color-scheme prefer-dark

# ------------------------------------------------------------------------------
# 2. MIGRAÇÃO DE DISPLAY MANAGER (SDDM para Ly TUI)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}>>> Configurando o Ly como novo Display Manager...${NC}"

# Desativa o serviço SDDM caso esteja ativo para evitar conflitos no boot
if systemctl is-enabled --quiet sddm 2>/dev/null; then
    echo -e "${BLUE}Desativando serviço SDDM...${NC}"
    sudo systemctl disable sddm
fi

# Remove o pacote SDDM e suas configurações de sistema
if pacman -Qs sddm > /dev/null; then
    echo -e "${BLUE}Removendo pacote SDDM...${NC}"
    sudo pacman -Rns --noconfirm sddm
else
    echo -e "${BLUE}SDDM não encontrado, ignorando remoção.${NC}"
fi

# Instala e habilita o Ly (Display Manager em modo texto)
echo -e "${BLUE}Instalando e ativando Ly no TTY1...${NC}"
sudo pacman -S --needed --noconfirm ly
sudo systemctl enable ly@tty1.service
# Desativar o getty@tty1 é necessário para o Ly assumir o terminal principal
sudo systemctl disable getty@tty1.service

# ------------------------------------------------------------------------------
# 3. LIMPEZA E SEGURANÇA
# ------------------------------------------------------------------------------
echo -e "${YELLOW}>>> Removendo pacotes redundantes do sistema...${NC}"
# Removendo configurações padrão do Cachy para priorizar os dotfiles pessoais
for pkg in cachyos-fish-config fastfetch; do
    if pacman -Qs $pkg > /dev/null; then
        sudo pacman -Rns --noconfirm $pkg
    fi
done

echo -e "${GREEN}>>> Aplicando políticas de Firewall (UFW)...${NC}"
sudo systemctl enable --now ufw.service
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable

# ------------------------------------------------------------------------------
# 4. GESTÃO DE DOTFILES (Git + GNU Stow)
# ------------------------------------------------------------------------------
echo -e "${GREEN}>>> Configurando Shell e Repositório de Dotfiles...${NC}"
sudo chsh -s /usr/bin/zsh $(whoami)

REPO_URL="https://github.com/fabioalmeida08/.dotfiles"
DOT_DIR="$HOME/.dotfiles"

if [ -d "$DOT_DIR" ]; then
    echo -e "${BLUE}Diretório $DOT_DIR já existe. Pulando clonagem.${NC}"
else
    git clone "$REPO_URL" "$DOT_DIR"
fi

echo -e "${GREEN}>>> Sincronizando configurações com GNU Stow...${NC}"
cd "$DOT_DIR"

# --adopt: Faz o Stow "adotar" arquivos existentes, vinculando-os ao repo
# --ignore: Evita conflitos com arquivos zsh específicos que trataremos manualmente
stow --adopt --ignore='^.zshrc' .

# ------------------------------------------------------------------------------
# 5. CONFIGURAÇÃO MANUAL DO ZSH (Caso específico CachyOS)
# ------------------------------------------------------------------------------
echo -e "${GREEN}>>> Vinculando .zshrc_cachy à Home...${NC}"

# Garante que não haja um arquivo físico ou link quebrado impedindo a criação do novo link
if [ -f "$HOME/.zshrc" ] || [ -L "$HOME/.zshrc" ]; then
    rm "$HOME/.zshrc"
fi

if [ -f "$DOT_DIR/.zshrc_cachy" ]; then
    ln -s "$DOT_DIR/.zshrc_cachy" "$HOME/.zshrc"
    echo -e "${GREEN}Sucesso: ~/.zshrc agora aponta para os dotfiles.${NC}"
else
    echo -e "${RED}ERRO CRÍTICO: .zshrc_cachy ausente no repositório!${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 5.1 CONFIGURAÇÃO DO NIRI (LINK SIMBÓLICO DE CONFIG)
# ------------------------------------------------------------------------------
echo -e "${GREEN}>>> Configurando link do Niri (config.kdl)...${NC}"

NIRI_DIR="$HOME/.config/niri"
NIRI_SRC="$DOT_DIR/.config/niri/config_cachy.kdl"
NIRI_DEST="$NIRI_DIR/config.kdl"

# Garante que o diretório exista
mkdir -p "$NIRI_DIR"

# Remove arquivo ou link existente
if [ -f "$NIRI_DEST" ] || [ -L "$NIRI_DEST" ]; then
    rm "$NIRI_DEST"
fi

# Cria o link simbólico
if [ -f "$NIRI_SRC" ]; then
    ln -s "$NIRI_SRC" "$NIRI_DEST"
    echo -e "${GREEN}Sucesso: config.kdl agora aponta para config_cachy.kdl${NC}"
else
    echo -e "${RED}ERRO: config_cachy.kdl não encontrado em $NIRI_SRC${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 6. CONFIGURAÇÃO DE SISTEMA DO LY
# ------------------------------------------------------------------------------
echo -e "${GREEN}>>> Aplicando config.ini do Ly em /etc/...${NC}"

LY_SRC="$DOT_DIR/.config/ly/config.ini"
LY_DEST="/etc/ly/config.ini"

if [ -f "$LY_SRC" ]; then
    # Backup da config original de fábrica
    [ -f "$LY_DEST" ] && sudo mv "$LY_DEST" "${LY_DEST}.bak"

    # Copiamos em vez de linkar porque o /etc exige permissões de root
    sudo cp "$LY_SRC" "$LY_DEST"
    sudo chown root:root "$LY_DEST"
    echo -e "${GREEN}Configuração do Ly aplicada com sucesso!${NC}"
else
    echo -e "${RED}Aviso: Configuração do Ly não encontrada em $LY_SRC${NC}"
fi

# ------------------------------------------------------------------------------
# FINALIZAÇÃO
# ------------------------------------------------------------------------------
cd "$DOT_DIR"
# Descarta mudanças locais feitas pelo comando 'stow --adopt' para manter o repo limpo
git checkout .

echo -e "${GREEN}--- Script finalizado com sucesso! ---${NC}"
echo -e "O Ly foi ativado. Por favor, ${BLUE}reinicie o sistema${NC} para concluir."
