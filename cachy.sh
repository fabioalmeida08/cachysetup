#!/bin/bash

# Abortar o script se algum comando der erro
set -e

echo "--- Iniciando configuração do ambiente ---"

# 1. Instalar pacotes com pacman
# A flag --needed evita reinstalar o que já existe
echo ">>> Instalando pacotes..."
sudo pacman -S --needed quickshell noctalia-shell wlsunset nwg-look adw-gtk-theme pavucontrol-qt stow yay lsd ufw 

# 2. Desinstalar pacotes
# A flag -Rns remove o pacote, seus arquivos de configuração e dependências que não são usadas por mais nada
echo ">>> Removendo pacotes indesejados..."
# Verifica se estão instalados antes de tentar remover para não quebrar o script
if pacman -Qs cachyos-fish-config > /dev/null; then
    sudo pacman -Rns --noconfirm cachyos-fish-config
fi

if pacman -Qs fastfetch > /dev/null; then
    sudo pacman -Rns --noconfirm fastfetch
fi

# 3. Definir ZSH como shell padrão
echo ">>> Alterando shell padrão para Zsh..."
# Usa o caminho absoluto e aplica ao usuário atual
sudo chsh -s /usr/bin/zsh $(whoami)

# 4. Clonar repositório de dotfiles
echo ">>> Clonando dotfiles..."
# IMPORTANTE: Substitua o link abaixo pelo seu repositório real antes de rodar
REPO_URL="https://github.com/fabioalmeida08/.dotfiles" 

if [ -d "$HOME/.dotfiles" ]; then
    echo "A pasta .dotfiles já existe. Pulando clone."
else
    git clone "$REPO_URL" "$HOME/.dotfiles"
fi

# 5. Aplicar Stow
echo ">>> Aplicando configurações com Stow..."
cd "$HOME/.dotfiles"
# --adopt fará com que os arquivos do repo adotem o conteúdo local se houver conflito,
# ou sobrescrevam links simbólicos se necessário.
stow --adopt .

echo "--- Script finalizado com sucesso! ---"
echo "Por favor, faça logout e login novamente para que o shell padrão seja atualizado."
