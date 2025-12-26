#!/bin/bash

# Abortar o script se algum comando der erro
set -e

# --- Definição de Cores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Iniciando configuração do ambiente ---${NC}"

# 1. Instalar pacotes com pacman
echo -e "${YELLOW}>>> Instalando pacotes...${NC}"
# Nota: Confirme se o nome é 'quickshell' ou 'quick-shell' no seu repo
sudo pacman -S --needed --noconfirm quickshell noctalia-shell wlsunset nwg-look adw-gtk-theme pavucontrol-qt stow yay lsd ufw ttf-firacode-nerd

# 2. Desinstalar pacotes
echo -e "${YELLOW}>>> Removendo pacotes indesejados...${NC}"
if pacman -Qs cachyos-fish-config > /dev/null; then
    sudo pacman -Rns --noconfirm cachyos-fish-config
fi

if pacman -Qs fastfetch > /dev/null; then
    sudo pacman -Rns --noconfirm fastfetch
fi

# 3. Configurar e Ativar UFW (Firewall)
echo -e "${GREEN}>>> Configurando o Firewall (UFW)...${NC}"
sudo systemctl enable --now ufw.service
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
echo -e "${BLUE}Status do UFW:${NC}"
sudo ufw status verbose

# 4. Definir ZSH como shell padrão
echo -e "${GREEN}>>> Alterando shell padrão para Zsh...${NC}"
sudo chsh -s /usr/bin/zsh $(whoami)

# 5. Clonar repositório de dotfiles
echo -e "${GREEN}>>> Clonando dotfiles...${NC}"
REPO_URL="https://github.com/fabioalmeida08/.dotfiles"

if [ -d "$HOME/.dotfiles" ]; then
    echo -e "${BLUE}A pasta .dotfiles já existe. Pulando clone.${NC}"
else
    git clone "$REPO_URL" "$HOME/.dotfiles"
fi

# 6. Aplicar Stow (Ignorando TODOS os arquivos .zshrc*)
echo -e "${GREEN}>>> Aplicando configurações com Stow...${NC}"
cd "$HOME/.dotfiles"

# --ignore="^.zshrc" vai ignorar .zshrc, .zshrc_cachy, .zshrc_custom, etc.
stow --adopt --ignore='^.zshrc' .

# 7. Linkar manualmente APENAS o arquivo Cachy
echo -e "${GREEN}>>> Configurando .zshrc específico do CachyOS...${NC}"

# Remove qualquer .zshrc que exista na home (arquivo ou link antigo)
if [ -f "$HOME/.zshrc" ] || [ -L "$HOME/.zshrc" ]; then
    rm "$HOME/.zshrc"
    echo -e "${GREEN}Arquivo/Link .zshrc antigo removido da Home.${NC}"
fi

# Cria o link simbólico manual: Home/.zshrc -> Repo/.zshrc_cachy
if [ -f "$HOME/.dotfiles/.zshrc_cachy" ]; then
    ln -s "$HOME/.dotfiles/.zshrc_cachy" "$HOME/.zshrc"
    echo -e "${GREEN}Sucesso: ~/.zshrc agora aponta para .dotfiles/.zshrc_cachy${NC}"
else
    echo -e "${RED}Erro CRÍTICO: Arquivo .zshrc_cachy não encontrado no repositório!${NC}"
    exit 1
fi

echo -e "${GREEN}--- Script finalizado com sucesso! ---${NC}"
echo -e "Por favor, faça ${BLUE}logout e login${NC} novamente."
