source ~/.shell_exts/shell/complete_alias

alias l='ls -hal'
alias ..='cd ..'

alias nr='npm run'
complete -F _complete_alias nr

alias prm='gh pr merge -m'
alias prma='gh pr merge -m --auto'
alias prnew='gh pr new'
alias prvi='gh pr view --web'
alias prchk='gh pr checks --watch'
complete -F _complete_alias prm
complete -F _complete_alias prma
complete -F _complete_alias prnew
complete -F _complete_alias prvi
complete -F _complete_alias prchk

alias gpl='git pull'
alias gpu='git push'
alias gf='git fetch'
alias gc='git commit'
alias gco='git switch'
alias gcamend='git commit --amend -a'
alias gs='git stash push'
alias gsp='git stash pop'
alias gm='git merge'
complete -F _complete_alias gpl
complete -F _complete_alias gpu
complete -F _complete_alias gf
complete -F _complete_alias gc
complete -F _complete_alias gco
complete -F _complete_alias gcamend
complete -F _complete_alias gs
complete -F _complete_alias gsp
complete -F _complete_alias gm

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

unset -f complete-alias
