#!/bin/bash

# Exit on any failure.
set -eu
set -x

GITHUB_ACTION_REPOSITORY=${GITHUB_ACTION_REPOSITORY:-$0}
INPUT_ADD_OPTIONS=${INPUT_ADD_OPTIONS:-}
INPUT_COMMIT_AUTHOR=${INPUT_COMMIT_AUTHOR:-Local <actions@github.com>}
INPUT_COMMIT_MESSAGE=${INPUT_COMMIT_MESSAGE:-Local Test}
INPUT_COMMIT_OPTIONS=${INPUT_COMMIT_OPTIONS:-}
INPUT_COMMIT_USER_EMAIL=${INPUT_COMMIT_USER_EMAIL:-actions@github.com}
INPUT_COMMIT_USER_NAME=${INPUT_COMMIT_USERNAME:-${GITHUB_ACTION_REPOSITORY}}
INPUT_DEST_BRANCH=${INPUT_DEST_BRANCH:-}
INPUT_DISABLE_GLOBBING=${INPUT_DISABLE_GLOBBING:-}
INPUT_DRY=${INPUT_DRY:-false}
INPUT_FILE_PATTERN=${INPUT_FILE_PATTERN:-.}
INPUT_PUSH_OPTIONS=${INPUT_PUSH_OPTIONS:-}
INPUT_REPOSITORY=${INPUT_REPOSITORY:-.}
INPUT_SKIP_DIRTY_CHECK=${INPUT_SKIP_DIRTY_CHECK:-false}
INPUT_SKIP_FETCH=${INPUT_SKIP_FETCH:-false}
INPUT_STATUS_OPTIONS=${INPUT_STATUS_OPTIONS:-}
INPUT_VERBOSE=${INPUT_VERBOSE:-false}


# This must be set by hand explicitly if you are doing local testing.
# Otherwise, INPUT_BRANCH is passed in by Github actions.
#
# INPUT_BRANCH=...

if [ "$INPUT_DISABLE_GLOBBING" ]; then
    set -o noglob;
fi

_switch_to_repository() {
    echo "INPUT_REPOSITORY value: $INPUT_REPOSITORY";
    cd "$INPUT_REPOSITORY";
}

_run_template() {
    echo "Executing Templating Engine"
    date > test_file
}

_git_is_dirty() {
    echo "INPUT_STATUS_OPTIONS: ${INPUT_STATUS_OPTIONS}";
    echo "::debug::Apply status options ${INPUT_STATUS_OPTIONS}";

    # shellcheck disable=SC2086
    [ -n "$(git status -s $INPUT_STATUS_OPTIONS -- $INPUT_FILE_PATTERN)" ]
}

_config_git_identity() {
    git config --global user.email "${INPUT_COMMIT_USER_EMAIL}"
    git config --global user.name "${INPUT_COMMIT_USER_NAME}"
}

_switch_to_branch() {
    echo "INPUT_BRANCH value: $INPUT_BRANCH";

    # Fetch remote to make sure that repo can be switched to the right branch.

    if "$INPUT_SKIP_FETCH"; then
        echo "::debug::git-fetch has not been executed";
    else
        git fetch --depth=1;
    fi

    # Switch to branch from current Workflow run
    # shellcheck disable=SC2086
    git checkout $INPUT_BRANCH;
}

_add_files() {
    echo "INPUT_ADD_OPTIONS: ${INPUT_ADD_OPTIONS}";
    echo "::debug::Apply add options ${INPUT_ADD_OPTIONS}";

    echo "INPUT_FILE_PATTERN: ${INPUT_FILE_PATTERN}";

    # shellcheck disable=SC2086
    git add ${INPUT_ADD_OPTIONS} ${INPUT_FILE_PATTERN};
}

_local_commit() {
    echo "INPUT_COMMIT_OPTIONS: ${INPUT_COMMIT_OPTIONS}";
    echo "::debug::Apply commit options ${INPUT_COMMIT_OPTIONS}";

    # shellcheck disable=SC2206
    local INPUT_COMMIT_OPTIONS_ARRAY=( $INPUT_COMMIT_OPTIONS );

    echo "INPUT_COMMIT_USER_NAME: ${INPUT_COMMIT_USER_NAME}";
    echo "INPUT_COMMIT_USER_EMAIL: ${INPUT_COMMIT_USER_EMAIL}";
    echo "INPUT_COMMIT_MESSAGE: ${INPUT_COMMIT_MESSAGE}";
    echo "INPUT_COMMIT_AUTHOR: ${INPUT_COMMIT_AUTHOR}";

    git commit -m "$INPUT_COMMIT_MESSAGE" \
        --author="$INPUT_COMMIT_AUTHOR" \
        ${INPUT_COMMIT_OPTIONS:+"${INPUT_COMMIT_OPTIONS_ARRAY[@]}"};
}

_push_to_github() {
    echo "INPUT_PUSH_OPTIONS: ${INPUT_PUSH_OPTIONS}";
    echo "::debug::Apply push options ${INPUT_PUSH_OPTIONS}";

    # shellcheck disable=SC2206
    local INPUT_PUSH_OPTIONS_ARRAY=( $INPUT_PUSH_OPTIONS );

    if [ ! "${INPUT_DRY}" == "false" ]; then
      echo "INPUT_DRY=${INPUT_DRY}... skipping push!"
      return
    fi
      
    if [ -z "$INPUT_BRANCH" ]; then
        echo "::debug::git push origin";
        git push origin ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
    else
        echo "::debug::Push commit to remote branch $INPUT_BRANCH";
        #git push --set-upstream origin "HEAD:$INPUT_BRANCH" --follow-tags --atomic ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
        git push origin "$INPUT_BRANCH" --atomic ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
    fi

    if [ -z "$INPUT_DEST_BRANCH" ]; then
        echo "::debug::git push origin";
        git push origin ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
    else
        echo "::debug::Push commit to remote branch $INPUT_DEST_BRANCH";
        #git push --set-upstream origin "HEAD:$INPUT_DEST_BRANCH" --follow-tags --atomic ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
        git push origin "$INPUT_DEST_BRANCH" --atomic ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
    fi
}

_merge_to_dest_branch() {
    echo "INPUT_DEST_BRANCH: ${INPUT_DEST_BRANCH}";
    echo "::debug::Merge ${INPUT_BRANCH} to ${INPUT_DEST_BRANCH}";

    if [ -z "${INPUT_DEST_BRANCH}" ]; then
      return
    fi
    
    local BRANCH_EXISTS
    git branch -lr | grep -q ${INPUT_DEST_BRANCH} && BRANCH_EXISTS=0 || BRANCH_EXISTS=1
    if [ $BRANCH_EXISTS -gt 0 ]; then
      echo "**Destination branch ${INPUT_DEST_BRANCH} does not exist... creating it from our current working branch ${INPUT_BRANCH}..."
      git checkout -b "${INPUT_DEST_BRANCH}"
    else
      echo "::debug::git checkout -b ${INPUT_DEST_BRANCH}..."
      git fetch origin "refs/heads/${INPUT_DEST_BRANCH}"
      #git checkout -b "${INPUT_DEST_BRANCH}" --track "refs/heads/${INPUT_DEST_BRANCH}"
      git checkout "${INPUT_DEST_BRANCH}"
    fi

    echo "::debug::git merge --message ..."
    git merge --message "[${INPUT_COMMIT_USER_NAME}] Merge from ${INPUT_BRANCH}" \
            --commit \
            --stat \
            --no-ff \
            "${INPUT_BRANCH}"
}

_main() {
    _switch_to_repository
    _config_git_identity
    _switch_to_branch
    _run_template
    
    if _git_is_dirty || "$INPUT_SKIP_DIRTY_CHECK"; then
        echo "::set-output name=changes_detected::true";
        _add_files
        _local_commit
        _merge_to_dest_branch
        _push_to_github
    else
        echo "::set-output name=changes_detected::false";
        echo "Working tree clean. Nothing to commit.";
    fi
}

# Be really loud and verbose if we're running in VERBOSE mode
if [ "${INPUT_VERBOSE}" == "true" ]; then
  set -x
  echo "Environment:"
  env
  echo "Arguments: $@"
fi

_main
