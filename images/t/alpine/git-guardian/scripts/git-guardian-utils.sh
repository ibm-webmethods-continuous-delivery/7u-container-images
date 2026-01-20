#!/bin/sh

# Copyright IBM Corporation All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC3043
# SC3043 is about the usage of "local" keyword. While it is not strictly POSIX compliant,
# it works with out current software stack and simplifies our code.

pu_log_i "GG|-- Sourcing git guardian commands..."

# Function 02
gg_assure_user_email(){
  if [ "${__gg_user_email}" = "dev@example.com" ]; then
    pu_log_w "GG|02 User email has not been passed in the environment, considering ${__gg_user_email}"
    # TODO: ask the user if this is ok and if not ask for the email
  fi
  pu_log_i "GG|02 Using user email ${__gg_user_email} for git guardian"
}

# Function 03
gg_assure_ssh_key() {
  if [ ! -f "${__gg_ssh_key_file}" ]; then
    pu_log_i "GG|03 Generating new ed25519 SSH key..."
    pu_log_w "GG|03 You will be prompted for a passphrase - use a strong one!"
    # Generate the key
    if ssh-keygen -t ed25519 -C "${__gg_user_email}" -f "${__gg_ssh_key_file}" ; then
    
      if [ ! -f "${__gg_ssh_key_file}.pub" ]; then
        pu_log_w "GG|03 Public key ${__gg_ssh_key_file}.pub not found after execution of command, maybe it was interrupted?"
        return 1
      else
        pu_log_i "GG|03 SSH key generated successfully: $(cat \"${__gg_ssh_key_file}.pub\")" 
      fi
    else
      pu_log_e "GG|03 ssh-keygen command failed! Code: $?"
      return 2
    fi
  fi
}

# Initialize ssh-agent, ensure it does not write into the rootfs
# shellcheck disable=SC1090,SC1091

# Function 04
gg_agent_start() {
  mkdir -p "${__gg_ssh_agent_dir}"
  (umask 077; TMPDIR="${__gg_ssh_agent_dir}" ssh-agent 2>/dev/null | sed 's/^echo/#echo/' > "${__gg_ssh_agent_env}")
  [ -f "${__gg_ssh_agent_env}" ] && . "${__gg_ssh_agent_env}" >/dev/null 2>&1
}

# Function 05
gg_assure_git_config() {

  __gg_assure_git_config_errors=0
  if ! gg_assure_ssh_key ; then
    pu_log_e "GG|05 You must have a working ssh key valid for signing before configuring git! Code $?"
    __gg_assure_git_config_errors=$((__gg_assure_git_config_errors+1))
  fi

  # Validate inputs
  if [ -z "${GG_GIT_USER_NAME+x}" ]; then
    pu_log_e "GG|05 GG_GIT_USER_NAME environment variable must be set!"
    __gg_assure_git_config_errors=$((__gg_assure_git_config_errors+1))
  fi

  if [ -z "${GG_USER_EMAIL+x}" ]; then
    pu_log_e "GG|05 GG_USER_EMAIL environment variable must be set"
    __gg_assure_git_config_errors=$((__gg_assure_git_config_errors+1))
  fi

  if [ "${__gg_assure_git_config_errors}" -ne 0 ]; then
    pu_log_e "GG|05 Correct the configuration errors before configuring git"
    unset __gg_assure_git_config_errors
    return 1
  fi
  unset __gg_assure_git_config_errors

  [ ! -f "$HOME/.ssh/allowed_signers" ] && touch "${HOME}/.ssh/allowed_signers"

  local tmp_pub_key
  tmp_pub_key=$(cat "${__gg_ssh_key_file}.pub")
  echo "${GG_USER_EMAIL} ${tmp_pub_key})" > /dev/shm/ssh_allowed_signers
  sort /dev/shm/ssh_allowed_signers | uniq  > "${HOME}/.ssh/allowed_signers"
  rm /dev/shm/ssh_allowed_signers

  git config --global commit.gpgsign true
  git config --global core.autocrlf input
  git config --global core.eol lf
  git config --global core.filemode true
  git config --global core.safecrlf warn
  git config --global gpg.format ssh
  git config --global gpg.ssh.allowedSignersFile "${HOME}//.ssh/allowed_signers"
  git config --global pull.ff only
  git config --global user.email "${GG_USER_EMAIL}"
  git config --global user.name "${GG_GIT_USER_NAME}"
  git config --global user.signingkey "${HOME}/.ssh/id_ed25519.pub"

  pu_log_i "GG|05 Git global configuration completed successfully!"
}

# Function 06
gg_trivy_scan() {
  # Run Trivy scan, skipping .ssh directories
  if ! trivy fs --skip-dirs "**/.git" --skip-dirs "**/.local" .; then
    pu_msg_fail_utf8 "GG|06 Trivy scan on folder $(pwd) failed!"
    exit 1
  fi
  pu_msg_info_utf8 "GG|06 Trivy scan on folder $(pwd) passed!"
}

# ============================================================================
# Repository Management Functions (30-39)
# ============================================================================

# Function 30 - Check if a directory is a git repository
_gg_repo_is_git_repo() {
  [ -d "${1}/.git" ]
}

# Function 31 - Get repository status details
# TODO: refactor for POSIX compatibility
_gg_repo_get_status() {
  local repo_path="$1"
  if ! _gg_repo_is_git_repo "$repo_path"; then
    pu_log_w "GG|31 Not a git repo: ${repo_path}"
    return 1
  fi

  local crt_pwd
  crt_pwd="$(pwd)"
    
  cd "$repo_path" || return 1
    
  local branch commits_behind commits_ahead staged unstaged untracked merge_conflicts
    
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
  
  # Commits behind/ahead
  local upstream
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo '')"
  if [ -n "$upstream" ]; then
    commits_behind="$(git rev-list --count HEAD.."$upstream" 2>/dev/null || echo '0')"
    commits_ahead="$(git rev-list --count "$upstream"..HEAD 2>/dev/null || echo '0')"
  else
    commits_behind="-"
    commits_ahead="-"
  fi
  
  # Staged files
  staged="$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"
  
  # Unstaged files
  unstaged="$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')"
  
  # Untracked files
  untracked="$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')"
  
  # Merge conflicts
  local conflict_count
  conflict_count="$(git ls-files -u 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$conflict_count" -gt 0 ]; then
    merge_conflicts="yes"
  else
    merge_conflicts="no"
  fi
  
  # Last commit date
  local last_commit
  last_commit="$(git log -1 --format="%cd" --date=short 2>/dev/null || echo 'unknown')"
  
  # Return status as CSV
  echo "$branch,$commits_behind,$commits_ahead,$staged,$unstaged,$untracked,$merge_conflicts,$last_commit"

  cd "${crt_pwd}" || return 2
}

# Function 32 - Check if repository has local changes
# Returns 0 (success) if changes are detected, 1 (failure) if no changes
_gg_repo_has_changes() {
  _gg_repo_is_git_repo "${1}" || return 1 # no repo means no changes

  local orig_path
  orig_path=$(pwd)

  cd "${1}" || return 1

  local changes_types_no=0

  # Check staged files
  local staged_changes_no
  staged_changes_no="$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${staged_changes_no}" -gt 0 ]; then
    changes_types_no=$((changes_types_no+1))
  fi
  
  # Check unstaged files
  local unstaged_changes_no
  unstaged_changes_no=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  if [ "${unstaged_changes_no}" -gt 0 ]; then
    changes_types_no=$((changes_types_no+1))
  fi
  
  # Check untracked files
  local untracked_files_no
  untracked_files_no=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  if [ "${untracked_files_no}" -gt 0 ]; then
    changes_types_no=$((changes_types_no+1))
  fi

  if [ ${changes_types_no} -gt 0 ]; then
    pu_log_d "GG|32 Repo $1 has changes: Untracked files: ${untracked_files_no}, Unstaged changes: ${unstaged_changes_no}, Staged changes: ${staged_changes_no}"
    cd "${orig_path}" || return 2
    return 0
  fi

  # Check commits ahead/behind
  local upstream
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo '')"
  if [ -n "$upstream" ]; then
    local commits_behind commits_ahead
    commits_behind="$(git rev-list --count HEAD.."$upstream" 2>/dev/null || echo '0')"
    if [ "${commits_behind}" -ne 0 ]; then
      pu_log_d "GG|32 Repo $1 is behind origin (${commits_behind})"
      cd "${orig_path}" || return 3
      return 0
    fi
    commits_ahead="$(git rev-list --count "$upstream"..HEAD 2>/dev/null || echo '0')"
    if [ "${commits_ahead}" -ne 0 ]; then
      pu_log_d "GG|32 Repo $1 is ahead of origin (${commits_ahead})"
      cd "${orig_path}" || return 4
      return 0
    fi
  fi
  cd "${orig_path}" || return 5
  return 1  # No changes detected
}

# Function 33 - Find all git repositories under a base directory
_gg_repo_find_all() {
  [ -d "${1}" ] || return 0
  
  # Find all .git directories and return their parent paths
  find "${1}" -name ".git" -type d 2>/dev/null | while read -r git_dir; do
    dirname "$git_dir"
  done
}

# Function 34 - Fetch a single repository
# TODO: refactor for posix compatibility
_gg_repo_fetch_one() {
  local repo_path="$1"
  local repo_name="${2:-$(basename "$repo_path")}"
  
  if ! _gg_repo_is_git_repo "$repo_path"; then
    pu_log_e "GG|34 $repo_path is not a git repository"
    return 1
  fi

  local orig_pwd
  orig_pwd="$(pwd)"
  
  cd "$repo_path" || return 2
  pu_log_i "GG|34 Fetching $repo_path [url=$(git remote get-url --all origin)]..."
  
  # Fetch all remotes
  if ! git fetch --all --prune 2>&1; then
    pu_log_e "GG|34 Failed to fetch $repo_path"
    cd "${orig_pwd}" || return 3
    return 1
  fi

  if [ ! -f .git/hooks/pre-commit ]; then
    if [ -f /usr/share/git-core/templates/hooks/pre-commit ]; then
      pu_log_w "GG|34 No pre-commit hook found for $repo_path, correcting now..."
      if ! git init ; then
        pu_log_e "GG|34 Failed to init git repo for $repo_path"
        cd "${orig_pwd}" || return 7
        return 8
      else
        pu_log_i "GG|34 Pre-commit hook installed successfully for $repo_path"
      fi
    else
      pu_log_w "GG|34 Template pre-commit hook not found, skipping auto-install"
    fi
  fi

  
  # Get current branch
  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
  
  if [ "$current_branch" = "unknown" ] || [ -z "$current_branch" ]; then
    pu_log_w "GG|34 Could not determine current branch for $repo_path, skipping pull"
    cd "${orig_pwd}" || return 4
    return 0
  fi
  
  # Check for local changes before attempting to pull
  local has_local_changes=0
  if [ "$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
    has_local_changes=1
  else
    if [ "$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
      has_local_changes=1
    else
      if [ "$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
        has_local_changes=1
      fi
    fi
  fi
  
  if [ "$has_local_changes" -eq 1 ]; then
    pu_log_w "GG|34 $repo_path has uncommitted changes - skipping pull"
    cd "${orig_pwd}" || return 5
    return 0
  fi
  
  # Update current branch if it has an upstream
  if git rev-parse --verify "@{upstream}" > /dev/null 2>&1; then
    pu_log_i "GG|34 Updating branch $current_branch in $repo_path..."
    if git pull --ff-only 2>&1; then
      pu_log_i "GG|34 Successfully updated $repo_path"
    else
      pu_log_w "GG|34 Could not fast-forward $repo_path (may have diverged from upstream)"
    fi
  else
    pu_log_i "GG|34 No upstream configured for branch $current_branch in $repo_path"
  fi
  
  cd "${orig_pwd}"  || return 6
}

# Function 35 - Clone or update repository from CSV entry
_gg_repo_clone_or_update() {
  local url="$1"
  local parent_dir="$2"
  local repo_name="$3"
  
  local repo_path="${parent_dir}/${repo_name}"
  
  pu_log_i "GG|35 Processing: $repo_path [url: ${url}]"
  
  # Ensure parent directory exists
  if [ ! -d "$parent_dir" ]; then
    pu_log_i "GG|35 Creating parent directory: $parent_dir"
    mkdir -p "$parent_dir"
  fi
  
  if [ -d "$repo_path" ]; then
    # Repository exists, fetch it
    _gg_repo_fetch_one "$repo_path" "$repo_name"
  else
    # Repository doesn't exist, clone it
    pu_log_i "GG|35 Cloning $repo_path from $url..."
    
    if git clone "$url" "$parent_dir"/"$repo_name" 2>&1; then
      pu_log_i "GG|35 Successfully cloned $repo_path"
    else
      pu_log_e "GG|35 Failed to clone $repo_path from $url"
      return 1
    fi
  fi
}

# Function 36 - Fetch all repositories
gg_repo_fetch_all() {
  pu_log_i "GG|36 === Fetching All Repositories ==="
    
  local total_processed=0
  local processed_repos_list_file=/dev/shm/processed_repos-$$.tmp

  rm -rf "${processed_repos_list_file}"

  # Process CSV if configured
  if [ -n "$__gg_managed_repos_csv" ] && [ -f "$__gg_managed_repos_csv" ]; then
    pu_log_i "GG|36 Processing managed repositories from CSV: $__gg_managed_repos_csv"
    
    # Read CSV and process all repositories (format: url,path,name)
    tail -n +2 "$__gg_managed_repos_csv" > /dev/shm/fetch-repos-$$.tmp
    while IFS=',' read -r url parent_dir repo_name; do
      # Skip empty lines
      if [ -z "$url" ] || [ -z "$parent_dir" ] || [ -z "$repo_name" ]; then
        continue
      fi
      
      # Process all repositories
      _gg_repo_clone_or_update "$url" "${__gg_this_repo_dir}/${parent_dir}" "${repo_name}"
      echo "${__gg_this_repo_dir}/${parent_dir}/${repo_name}" >> "${processed_repos_list_file}"
      total_processed=$((total_processed + 1))
    done < /dev/shm/fetch-repos-$$.tmp
    rm -f /dev/shm/fetch-repos-$$.tmp
  fi
    
  # Also fetch all existing repositories in the base directory

  pu_log_i "GG|36 Fetching remaining repositories in $__gg_this_repo_dir"
  _gg_repo_find_all "$__gg_this_repo_dir" > /dev/shm/existing-repos-$$.tmp

  # Compute set difference: existing repos MINUS processed repos
  # If processed_repos_list_file doesn't exist or is empty, all existing repos are not yet fetched
  if [ -f "${processed_repos_list_file}" ] && [ -s "${processed_repos_list_file}" ]; then
    # Use grep -Fxvf: -F (fixed strings), -x (exact match), -v (invert), -f (file)
    grep -Fxvf "${processed_repos_list_file}" /dev/shm/existing-repos-$$.tmp > /dev/shm/remaining-repos-$$.tmp
  else
    # No repos processed yet, all existing repos are remaining
    cp /dev/shm/existing-repos-$$.tmp /dev/shm/remaining-repos-$$.tmp
  fi

  # Fetch remaining repositories
  while read -r repo_path; do
    local repo_name

    repo_name="$(basename "$repo_path")"
    _gg_repo_fetch_one "$repo_path" "$repo_name"
    total_processed=$((total_processed + 1))
  done < /dev/shm/remaining-repos-$$.tmp

  # Cleanup temp files
  rm -f /dev/shm/existing-repos-$$.tmp /dev/shm/remaining-repos-$$.tmp "${processed_repos_list_file}"

  pu_log_i "GG|36 === Fetch Complete ==="
  pu_log_i "GG|36 Total repositories processed: $total_processed"
}

# Function 37 - Show all repositories with local changes
gg_repo_show_all_local_changes() {
  pu_log_i "GG|37 === Repositories With Local Changes ==="
    
  local report_tmpfile="/dev/shm/repo-changes-$$.tmp"
  rm -f "$report_tmpfile"
    
  # Check all repos in base directory (includes __gg_this_repo_dir if it's a git repo)
  _gg_repo_find_all "$__gg_this_repo_dir" | while read -r repo_path; do
    ## Assure that a dir is a repo
    if _gg_repo_is_git_repo "${repo_path}"; then
      if ! git config --global --get-all safe.directory | grep -qx "${repo_path}"; then 
        git config --global --add safe.directory "${repo_path}";
      fi
      if _gg_repo_has_changes "$repo_path"; then
        local repo_name
        repo_name="$(basename "$repo_path")"
        local status
        status="$(_gg_repo_get_status "$repo_path")"
        echo "$repo_path,$status" >> "$report_tmpfile"
      fi
    else
      pu_log_e "GG|37 ${repo_path} is not a git repo! Error code $?"
    fi
  done

  # Display report
  if [ -s "$report_tmpfile" ]; then
    local repo_count
    repo_count=$(wc -l < "$report_tmpfile")
    pu_log_i "GG|37 Found ${repo_count} repositories with changes:"
    
    # Calculate dynamic column widths
    local max_repo=10 max_branch=6
    while IFS=',' read -r repo branch _rest; do
      local repo_len=${#repo}
      local branch_len=${#branch}
      [ "$repo_len" -gt "$max_repo" ] && max_repo=$repo_len
      [ "$branch_len" -gt "$max_branch" ] && max_branch=$branch_len
    done < "$report_tmpfile"
    
    # Add padding
    max_repo=$((max_repo + 2))
    max_branch=$((max_branch + 2))
    
    # Print header
    local header_line
    header_line=$(printf "%-${max_repo}s %-${max_branch}s %-8s %-8s %-8s %-10s %-10s %-10s %-12s\n" \
      "Repository" "Branch" "Behind" "Ahead" "Staged" "Unstaged" "Untracked" "Conflicts" "LastCommit")
    pu_log_i "GG|37 ${header_line}"
    
    # Print separator line
    local total_width=$((max_repo + max_branch + 8 + 8 + 8 + 10 + 10 + 10 + 12 + 7 + 7 + 5))
    printf '%*s\n' "$total_width" '' | tr ' ' '-'
        
    # Print data rows
    while IFS=',' read -r repo branch behind ahead staged unstaged untracked conflicts lastcommit; do
      local data_line
      data_line=$(printf "%-${max_repo}s %-${max_branch}s %-8s %-8s %-8s %-10s %-10s %-10s %-12s\n" \
        "$repo" "$branch" "$behind" "$ahead" "$staged" "$unstaged" "$untracked" "$conflicts" "$lastcommit")
      pu_log_i "GG|37 ${data_line}"
    done < "$report_tmpfile"
        
    # Print separator line
    printf '%*s\n' "$total_width" '' | tr ' ' '-'
  else
    pu_log_i "GG|37 No repositories with local changes."
  fi
    
  rm -f "$report_tmpfile"
}

# Function 38 - List all known repositories
gg_repo_list_all() {
  pu_log_i "GG|38 === All Known Repositories ==="
    
  local count=0
  local tmpfile="/dev/shm/list-repos-$$.tmp"
    
  # List all repos in base directory (includes __gg_this_repo_dir if it's a git repo)
  if [ -d "$__gg_this_repo_dir" ]; then
    _gg_repo_find_all "$__gg_this_repo_dir" > "$tmpfile"
    while read -r repo_path; do
      local repo_name
      repo_name="$(basename "$repo_path")"
      pu_log_i "GG|38 $(printf "%-30s %s\n" "$repo_name" "$repo_path")"
      count=$((count + 1))
    done < "$tmpfile"
    rm -f "$tmpfile"
  fi
  pu_log_i "GG|38 Total: $count repositories"
}

# Create user-friendly aliases with hyphens for backward compatibility
alias fetch-all='gg_repo_fetch_all'
alias show-all-local-changes='gg_repo_show_all_local_changes'
alias list-all-repos='gg_repo_list_all'


########### Functions 9x - automatic initialization at source time

# Function 90
_gg_init(){
  if [ -z "${GG_USER_EMAIL+x}" ]; then
    pu_log_w "GG|90 GG_USER_EMAIL env var not provided. Verify the container setup!"
  fi
  __gg_user_email="${GG_USER_EMAIL:-dev@example.com}"
  # Encapsulation decision: we only consider the ~/.ssh/id_ed25519 file for simplicity
  __gg_ssh_key_file="${HOME}/.ssh/id_ed25519"

  if [ ! -f "${__gg_ssh_key_file}" ]; then
    pu_log_w "GG|90 ssh private key file not found: ${__gg_ssh_key_file}. You might want to initialize it using the function gg_assure_ssh_key"
  fi

  # agent ephemeral directory and configuration
  __gg_ssh_agent_dir="/dev/shm/ssh-agent-dir-$(id -u)-$$"
  __gg_ssh_agent_env="${__gg_ssh_agent_dir}.env"

  # Assure we have an ssh agent
  if ! ssh-add -l >/dev/null 2>&1; then
    # Agent not running or not accessible, start a new one
    gg_agent_start
  fi
}
_gg_init

# Function 91 Load existing ssh agent environment
gg_agent_load_env() {
  # Not supposed to follow this, it is dynamically created
  # shellcheck source=/dev/null
  [ -f "${__gg_ssh_agent_env}" ] && . "${__gg_ssh_agent_env}" >/dev/null 2>&1
}
gg_agent_load_env

# Function 92 - Initialize git repository management configuration
_gg_repo_init() {
  __gg_this_repo_dir="${GG_THIS_REPO_DIR:-/gg}"
  pu_log_i "GG|92 Using ${__gg_this_repo_dir} as base git guardian repo"
  if [ ! -d "${__gg_this_repo_dir}/.git" ]; then
    pu_log_w "GG|92 Not a git repo: ${__gg_this_repo_dir}"
  fi
  __gg_managed_repos_csv="${GG_MANAGED_REPOS_CSV:-${__gg_this_repo_dir}/managed-repos.csv}"

  pu_log_i "GG|92 Using ${__gg_managed_repos_csv} as managed repos file"
  if [ ! -f "${__gg_managed_repos_csv}" ]; then
    pu_log_w "GG|92 Managed repositories file does not exist: ${__gg_managed_repos_csv} !"
  fi
}
_gg_repo_init
