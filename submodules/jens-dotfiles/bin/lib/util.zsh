print_info() {
  if [[ $# -ge 1 ]]
  then
    print -P "%B%F{blue}$1%b%f" >&2
  else
    print >&2
  fi
}

print_warning() {
  if [[ $# -ge 1 ]]
  then
    print -P "%B%F{yellow}$1%b%f" >&2
  else
    print >&2
  fi
}

print_error() {
  if [[ $# -ge 1 ]]
  then
    print -P "%B%F{red}$1%b%f" >&2
  else
    print >&2
  fi
}
