#!/bin/bash

cd "$HOME"

echo -ne "\e[36m
 _   _                 ____       _               
| | | |___  ___ _ __  / ___|  ___| |_ _   _ _ __  
| | | / __|/ _ \ '__| \___ \ / _ \ __| | | | '_ \ 
| |_| \__ \  __/ |     ___) |  __/ |_| |_| | |_) |
 \___/|___/\___|_|    |____/ \___|\__|\__,_| .__/ 
                                           |_|    
\e[0m"
echo -e "This script does not include installing a Desktop Environment"
echo -e "This script will install everything I use on my personal Arch Linux setup"
echo -e "This script is intended for installing a minimal Arch Linux setup with a Tiling Window Manager."

# Core system was already installed in first stage:
# base base-devel nano vim neovim networkmanager lvm2 cryptsetup grub efibootmgr linux linux-firmware

echo -e "\nUpdating system..."
sudo pacman -Syu --noconfirm
echo -e "\nSyncing package databases..."
sudo pacman -Syy

# Set up AUR helper (yay)
echo -e "\nSetting up AUR helper (yay)..."
sudo pacman -S --needed --noconfirm base-devel git
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd .. && rm -rf yay
yay -Syu --noconfirm

# Additional Core System
echo -e "\n\e[33mInstalling core packages...\e[0m"
sudo pacman -S --noconfirm \
    linux-lts-headers \
    pipewire-pulse pipewire-alsa pavucontrol pipewire \
    nvidia-lts nvidia-settings

# System Utilities
sudo pacman -S --noconfirm \
    htop \
    fastfetch \
    wget \
    curl \
    unzip \
    xclip \
    tree \
    man-db \
    man-pages \
    kitty

# Tiling Window Manager (X11 or Wayland)
echo -e "\n\e[33mDo you want your display server to be X11 or Wayland?\e[0m"
echo "1) X11 (with dwm)"
echo "2) Wayland (with Hyprland)"
read -r display_choice

# For X11, ask about compositor
if [ "${display_choice}" == "1" ]; then
	echo -e "\e[33mDo you want the picom compositor? (Y/N)\e[0m"
	read -r use_compositor
fi

case "${display_choice}" in
	1)
		echo -e "\n\e[34mInstalling X11 with dwm...\e[0m"
		sudo pacman -S --noconfirm \
            xorg-server \
            xorg-xinit \
            xorg-xrandr \
            xorg-xsetroot
		if [[ "${use_compositor}" == "Y" || "${use_compositor}" == "y" ]]; then
            yay -S --noconfirm picom
        fi

		# DWM Installation
        echo -e "\n\e[33mInstalling dwm and related tools...\e[0m"
		if wget https://dl.suckless.org/dwm/dwm-6.5.tar.gz; then
			tar -xzvf dwm-6.5.tar.gz
        	cd dwm-6.5
        	sudo make clean install
        	cd ..
        	rm dwm-6.5.tar.gz
		else
		    echo -e "\e[31mFailed to download DWM\e[0m"
		    exit 1
		fi

		# I do not use ST

		# dmenu Installation
		wget https://dl.suckless.org/tools/dmenu-5.3.tar.gz
		tar -xzvf dmenu-5.3.tar.gz
        cd dmenu-5.3
        sudo make clean install
        cd ..
        rm dmenu-5.3.tar.gz
		;;
	2)
		echo -e "\n\e[34mInstalling Wayland with Hyprland...\e[0m"
		sudo pacman -S --noconfirm \
            hyprland \
            waybar \
			wofi \
            grim \
            slurp \
            swww \
            wl-clipboard \
			xdg-desktop-portal-hyprland \
			qt5-wayland \
			qt6-wayland
        ;;
esac

# Development Tools
sudo pacman -S --noconfirm \
    nodejs \
    npm \
    python-pip \
    docker \
    docker-compose

# Daily Applications
sudo pacman -S --noconfirm \
    firefox \
	flameshot \
    thunderbird \
    discord \
    keepassxc \
    obsidian \
    mpv \
    zathura \
	zathura-pdf-mupdf

# Input Method
sudo pacman -S --noconfirm \
    fcitx5 \
    fcitx5-configtool \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-rime \
    rime-cantonese

# Fonts
sudo pacman -S --noconfirm \
    ttf-font-awesome \
    noto-fonts-cjk \
    noto-fonts-emoji

# Shell
sudo pacman -S --noconfirm \
    zsh \
    zsh-syntax-highlighting

# Change shell to zsh
echo -e "\n\e[33mChanging shell to zsh...\e[0m"
chsh -s /bin/zsh

# Services
systemctl --user enable --now pipewire
systemctl --user enable --now pipewire-pulse
systemctl --user enable --now wireplumber

echo -e "\n\e[32mSetup complete!\e[0m"
echo -e "You may need to reboot your system for all changes to take effect."
