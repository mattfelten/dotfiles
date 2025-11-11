MAKEFLAGS += --silent

.PHONY: dotfiles homebrew macos start nvm

start: homebrew nvm dotfiles macos
	$(info )
	$(info ✨ All done! Some changes may require a restart to start working.)

dotfiles:
	$(info )
	$(info ⏱️ Linking dotfiles!)
	rake
	source ~/.zshrc
	source ~/.aliases

homebrew:
	$(info )
	$(info ⏱️ Installing Homebrew!)
	sudo true
	curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | sudo -u $$USER bash
	eval "$(/opt/homebrew/bin/brew shellenv)"

	brew update
	brew upgrade
	brew bundle --global

nvm:
	$(info )
	$(info ⏱️ Installing NVM!)
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
	nvm install --lts --latest-npm --default

macos:
	$(info )
	$(info ⏱️ Updating MacOS!)
	. .macos
