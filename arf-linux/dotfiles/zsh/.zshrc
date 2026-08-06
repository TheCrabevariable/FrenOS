# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=50
SAVEHIST=50
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/catboy/.zshrc'

autoload -U colors && colors
export PS1="%{$(tput setaf 225)%}%n%{$(tput setaf 224)%}@%{$(tput setaf 105)%}%m %{$(tput setaf 133)%}%1~ %{$(tput sgr0)%}$ "

autoload -Uz compinit promptinit
compinit
promptinit

# End of lines added by compinstall
sleep .1
fastfetch

# alias
alias install="sudo pacman -S"
alias update="sudo pacman -Syu"
alias remove="sudo pacman -Rns"
alias clean="sudo pacman -Scc"
alias ff="fastfetch"
alias music-dl="yt-dlp --embed-thumbnail --no-playlist --embed-metadata -x --audio-format mp3 -o \"%(artist)s - %(title)s.%(ext)s\""

# Fren emoji icons
export FREN_ICON_MODE=emoji
export TERMINAL=kitty

# Powerlevel10k theme
source ~/powerlevel10k/powerlevel10k.zsh-theme
# load optional rice config
[ -f ~/.rice.zsh ] && source ~/.rice.zsh
