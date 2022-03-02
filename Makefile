start:
	rake
	/usr/bin/ruby -e \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)\"
	brew update
	brew upgrade
	brew bundle --global
	open ./terminal/Custom.terminal
	. .osx
	$(info ✨ All done! Some changes may require a restart to start working. Make sure to install nvm manually.)
