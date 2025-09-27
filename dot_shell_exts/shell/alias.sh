function make-completion-wrapper () {
  local function_name="$2"
  local arg_count=$(($#-3))
  local comp_function_name="$1"
  shift 2
  local function="
    function $function_name {
      ((COMP_CWORD+=$arg_count))
      # Quotes here are important
      COMP_WORDS=( "$@" \"\${COMP_WORDS[@]:1}\" )
      "$comp_function_name"
      return 0
    }"
  eval "$function"
  # echo $function_name
  # echo "$function"
}

function complete-alias  {
  # uses make-completion-wrapper: https://unix.stackexchange.com/a/4220/50978
  # example usage
  # complete-alias _pass pshow pass show
  # complete-alias _pass pgen pass generate

  local EXISTING_COMPLETION_FN=${1} && shift
  local ALIAS=${1} && shift
  local AUTOGEN_COMPLETION_FN="__autogen_completion_${ALIAS}"

  local ORIGINAL_COMMAND="${*}"
  local ARGS_FOR_COMPLETION_FN=""   # original command without -args
  while [ $# -gt 0 ]; do
    if ! [ "$1" == "-" ]; then
      ARGS_FOR_COMPLETION_FN="$ARGS_FOR_COMPLETION_FN $1"
    fi
    shift
  done

  make-completion-wrapper ${EXISTING_COMPLETION_FN} ${AUTOGEN_COMPLETION_FN} ${ARGS_FOR_COMPLETION_FN}
  complete -F ${AUTOGEN_COMPLETION_FN} ${ALIAS}
  alias ${ALIAS}="$ORIGINAL_COMMAND"
}

alias l='ls -hal'
alias ..='cd ..'

complete-alias _npm_completion nr npm run

complete-alias __git_wrap__git_main gpl git pull
complete-alias __git_wrap__git_main gpu git push
complete-alias __git_wrap__git_main gf git fetch
complete-alias __git_wrap__git_main gc git commit
complete-alias __git_wrap__git_main gco git switch
complete-alias __git_wrap__git_main gcamend git commit --amend -a
complete-alias __git_wrap__git_main gs git stash push
complete-alias __git_wrap__git_main gsp git stash pop
complete-alias __git_wrap__git_main gm git merge
alias gmom='gmo m'   # main or master
gmo() {
  # git fetch && merge <branch> 
  # -- branch defaults to current.
  # -- use m as "master" or "main"
  local branch=${1:-$(git rev-parse --abbrev-ref HEAD)}
  if [ "$branch" == "m" ]; then
    if git ls-remote --exit-code --heads origin main; then
      branch=main
    else
      branch=master
    fi
  fi

  git fetch origin && git merge "origin/$branch"
}
greset-origin-hard() {
  local branch=$(git rev-parse --abbrev-ref HEAD)
  git reset --hard origin/$branch
}

unset -f make-completion-wrapper
unset -f complete-alias
