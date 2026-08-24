# History
HISTFILE=~/.histfile
HISTSIZE=50
SAVEHIST=50

# Completion
autoload -Uz compinit && compinit

# Prompt: user@host dir <time> on top, input on the next line
setopt PROMPT_SUBST
autoload -Uz add-zsh-hook
zmodload zsh/datetime

typeset -gF _cmd_start=0
typeset -g _exec_time=""

_prompt_preexec() { _cmd_start=$EPOCHREALTIME }
_prompt_precmd() {
  _exec_time=""
  (( _cmd_start > 0 )) || return
  local elapsed=$(( EPOCHREALTIME - _cmd_start ))
  _cmd_start=0
  (( elapsed >= 0.05 )) && printf -v _exec_time ' %%F{216}<%.2fs>%%f' "$elapsed"
}
add-zsh-hook preexec _prompt_preexec
add-zsh-hook precmd _prompt_precmd

export PS1='%F{225}%n%F{224}@%F{105}%m %F{133}%1~%f${_exec_time}
%F{133}❯%f '

# Env
export FREN_ICON_MODE=emoji
export TERMINAL=kitty

# Aliases
alias install="sudo pacman -S"
alias update="sudo pacman -Syu"
alias remove="sudo pacman -Rns"
alias clean="sudo pacman -Scc"
alias ff="fastfetch"
alias music-dl="yt-dlp --embed-thumbnail --no-playlist --embed-metadata -x --audio-format mp3 -o \"%(artist)s - %(title)s.%(ext)s\""

sleep .1
fastfetch
