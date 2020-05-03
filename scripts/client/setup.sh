#!/bin/bash
# @author Kevin Veen-Birkenbach
# shellcheck source=/dev/null # Deactivate SC1090

source "$(dirname "$(readlink -f "${0}")")/../base.sh" || (echo "Loading base.sh failed." && exit 1)
SYSTEM_MEMORY_KB="$(grep MemTotal /proc/meminfo | awk '{print $2}')"
info "Start setup of customized core software..."

info "Copying templates to home folder..." &&
cp -rfv "$TEMPLATE_PATH/." "$HOME" || error "Copy templates failed."

info "Update packages..." &&
sudo pacman -Syyu || error "Package syncronisation failed."

info "Synchronizing pacman packages..." &&
get_packages "general" "client-pacman" | sudo pacman -S --needed - && #|| error "Syncronisation failed."
info "Synchronizing yay packages..." &&
get_packages "client-yay" | yay -S - || error "Syncronisation failed."

info "Installing atom packages..." &&
get_packages "atom" | apm install -c - || error "Installation failed." # @todo needs to be fixed

FSTAB_SWAP_ENTRY="/swapfile none swap defaults 0 0"
SWAP_FILE="/swapfile"
FSTAB_FILE="/etc/fstab"
if grep -q "$FSTAB_SWAP_ENTRY" "$FSTAB_FILE"; then
	info "Skipping creation of swap partion because entry allready exists in \"$FSTAB_FILE\"!"
else
	info "Creating swap partition..." &&
	sudo fallocate -l 16G "$SWAP_FILE" &&
	sudo chmod 600 "$SWAP_FILE" &&
	sudo mkswap "$SWAP_FILE" &&
	sudo swapon "$SWAP_FILE" &&
	sudo sh -c "echo \"$FSTAB_SWAP_ENTRY\">>\"$FSTAB_FILE\"" || error "Creation of swap partition failed."
fi

info "Setup SSH key..."
ssh_key_path="$HOME/.ssh/id_rsa"
if [ ! -f "$ssh_key_path" ]; then
	info "SSH key $ssh_key_path doesn't exists!"
	if [ ! -f "./data$ssh_key_path" ]; then
		info "Importing ssh key by copying data..." &&
		bash "$SCRIPT_PATH""/data/export-to-system.sh" || error "Copying failed."
	else
		info "Generating ssh key..." &&
		ssh-keygen -t rsa -b 4096 -C "$USER@$HOSTNAME" || error "Key generation failed."
	fi
fi
# @todo the following part can be optimized
if [[ "$(sudo lshw -C display)" == *"NVIDIA"* ]]; then
	info "Install NVIDIA drivers..." &&
	sudo mhwd -a pci nonfree 0300 || error "Failed."
fi

# @todo optimize
obs_requirements_memory_kb="4000000"
if [ "$SYSTEM_MEMORY_KB" -gt "$obs_requirements_memory_kb" ]; then
	info "Synchronizing obs studio..."
	sudo pacman -S obs-studio
fi

info "Configurate system for arduino..." &&
sudo usermod -a -G uucp "$USER" &&
sudo usermod -a -G lock "$USER" || error "Couldn't add \"$USER\" to the relevant groups."

info "Installing software which is required by atom..." &&
sudo npm i -g bash-language-server && #Needed by atom-package ide-bash
python -m pip install 'python-language-server[all]' || error "Installation failed."#Needed by atom

info "Synchronizing containerization tools..."
info "Add current user \"$USER\" to user group docker..."
sudo usermod -a -G docker "$USER"
info "Enable docker service..."
sudo systemctl enable docker --now
info "Synchronizing virtualisation tools..."
pamac install virtualbox $(pacman -Qsq "^linux" | grep "^linux[0-9]*[-rt]*$" | awk '{print $1"-virtualbox-host-modules"}' ORS=' ')
sudo vboxreload
pamac build virtualbox-ext-oracle
sudo gpasswd -a "$USER" vboxusers
info "Keep in mind to install the guest additions in the virtualized system. See https://wiki.manjaro.org/index.php?title=VirtualBox"

minimum_gaming_memory_kb="4000000"
if [ "$SYSTEM_MEMORY_KB" -gt "$minimum_gaming_memory_kb" ]; then
	info "Synchronizing games..."
	sudo pacman --needed -S 0ad warzone2100
	info "Synchronizing emulationstation..."
	yay -S emulationstation #retroarch joyutils jstest-gtk-git
	yay -S libretro-snes9x-next-git libretro-quicknes-git libretro-fceumm-git libretro-prosystem-git libretro-gambatte-git libretro-mgba-git
	info "Installing themes..."
	mkdir .emulationstation/themes
	git clone https://github.com/RetroPie/es-theme-carbon .emulationstation/themes/carbon
	info "More game recomendations you will find here: https://wiki.archlinux.org/index.php/List_of_games..."
fi
if [ "$XDG_SESSION_TYPE" == "x11" ]; then
	info "Synchronizing xserver tools..."
	sudo pacman --needed -S xbindkeys
	info "Setting up key bindings..."
	echo "" >> "$HOME/.xbindkeysrc"
	echo "\"gnome-terminal -e '/bin/bash $SCRIPT_PATH/import-data-from-system.sh'\"" >> "$HOME/.xbindkeysrc"
	echo "  control+alt+s" >> "$HOME/.xbindkeysrc"
	xbindkeys --poll-rc
fi
if [ "$DESKTOP_SESSION" == "gnome" ]; then
	info "Synchronizing gnome tools..."
	sudo pacman --needed -S gnome-shell-extensions gnome-terminal
	info "Setting up gnome specific software..."
	info "Setting up dash favourites..."
	gsettings set org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop',
	'org.gnome.Terminal.desktop',
	'org.keepassxc.KeePassXC.desktop',
	'firefox.desktop',
	'chromium.desktop',
	'atom.desktop',
	'arduino.desktop',
	'eclipse.desktop',
	'vlc.desktop',
	'gimp.desktop',
	'blender.desktop',
	'rhythmbox.desktop',
	'org.gnome.Screenshot.desktop']"
	info "Install GNOME extensions..."
	info "Install \"NASA picture of the day\"..."
	git clone https://github.com/Elinvention/gnome-shell-extension-nasa-apod.git "$HOME/.local/share/gnome-shell/extensions/nasa_apod@elinvention.ovh"
	gnome-extensions enable  nasa_apod@elinvention.ovh
	info "Install \"Open Weather\"..."
	git clone https://gitlab.com/jenslody/gnome-shell-extension-openweather "$HOME/.local/share/gnome-shell/extensions/openweather-extension@jenslody.de"
	gnome-extensions enable openweather-extension@jenslody.de
	info "Install \"Dash to Panel\"..."
	git clone https://github.com/home-sweet-gnome/dash-to-panel "$HOME/.local/share/gnome-shell/extensions/openweather-extension@dash-to-panel@jderose9.github.com"
	gnome-extensions enable dash-to-panel@jderose9.github.com
	info "Deaktivating \"Dash to Dock\""
	gnome-extensions disable dash-to-dock@micxgx.gmail.com
fi
info "Removing all software from user startup..."
rm ~/.config/autostart/*
info "More software recomendations you will find here: https://wiki.archlinux.org/index.php/list_of_applications"
