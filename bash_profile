# source this to be sure
if [ -f /etc/profile ]; then
  source /etc/profile
fi

if [ -f ${HOME}/.bashrc ]; then
  source ${HOME}/.bashrc
fi

# Toon juiste host in terminal titel
export PROMPT_COMMAND="echo -ne '\033]0;${USER}@${HOSTNAME}\007';$PROMPT_COMMAND"

# fancy prompt with colors
if [ $USER = root ]; then
  # Rode prompt
  export PS1='\[\e]0;[\u@\h]: \w\a\][\[\033[01;31m\]\u@\h\[\033[00m\]]${PSFW}:\W\[\033[00m\]\$ '
else
  # Groene prompt
  export PS1='\[\e]0;[\u@\h]: \w\a\][\[\033[01;32m\]\u@\h\[\033[00m\]]${PSFW}:\W\[\033[00m\]\$ '
fi

# hsitory timestamps
export HISTTIMEFORMAT="%d/%m/%y %T "

# apt-history functie
### options:  install | remove | rollback
function apt-history(){

      case "$1" in
        install)
              grep 'install ' /var/log/dpkg.log
              ;;
        upgrade|remove)
              grep $1 /var/log/dpkg.log
              ;;
        rollback)
              grep upgrade /var/log/dpkg.log | \
                  grep "$2" -A10000000 | \
                  grep "$3" -B10000000 | \
                  awk '{print $4"="$5}'
              ;;
        *)
              cat /var/log/dpkg.log
              ;;
      esac
}

# vang sudo af
f_sudo() {
  if [ ! "$#" = 0 ]; then
    if [ "$1" = "su" ] || [ "$1" = "-i" ]; then
      sudo bash --rcfile ${HOME}/.bash_profile
    else
      sudo $@
    fi
  else
    sudo $@
  fi
} 

# Aliases
alias ls='ls --color=auto'
alias ll='ls --color=auto -l'
alias la='ls --color=auto -la'
alias lt='ls --color=auto -ltr'
if [ -n "$(type -t f_sudo)" ] && [ "$(type -t f_sudo)" = function ] && [ ! $USER = "root" ]; then
  alias sudo='f_sudo'
fi

# start in $HOME
cd
