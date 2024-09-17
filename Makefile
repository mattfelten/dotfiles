define \n


endef

.PHONY: dotfiles ohmyzsh homebrew macos start
start: homebrew ohmyzsh dotfiles macos
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

macos:
	$(info {\n}⏱️ Updating MacOS!)
	open ./terminal/Custom.terminal
	. .macos
