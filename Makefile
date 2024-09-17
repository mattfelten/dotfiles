define \n


endef

.PHONY: dotfiles ohmyzsh homebrew macos start nvm
start: homebrew nvm ohmyzsh dotfiles macos
	$(info {\n}✨ All done! Some changes may require a restart to start working. Make sure to install nvm manually.)

dotfiles:
	$(info {\n}⏱️ Linking dotfiles!)
	rake

ohmyzsh:
	$(info {\n}⏱️ Installing oh-my-zsh!)
	curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh

homebrew:
	$(info {\n}⏱️ Installing Homebrew!)
	sudo true
	curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | sudo -u $$USER bash
	eval "$(/opt/homebrew/bin/brew shellenv)"

	brew update
	brew upgrade
	brew bundle --global

nvm:
	$(info {\n}⏱️ Installing NVM!)
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

macos:
	$(info {\n}⏱️ Updating MacOS!)
	. .macos
