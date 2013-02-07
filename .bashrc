source ~/.aliases

PATH=$PATH:$HOME/.rvm/bin:/usr/local/bin # Add RVM to PATH for scripting

# Enable colors
export CLICOLOR=1
export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx

function parse_git_branch {
git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1) /'
}
export PS1='\[\e[0;35m\]⌘\[\e[0m\] \[\e[0;36m\]\w/\[\e[0m\] \[\e[0;33m\]$(parse_git_branch)\[\e[0m\]'
