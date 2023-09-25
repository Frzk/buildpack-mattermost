#!/usr/bin/env bash

STEP="----->"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

info() {
    echo "       $*"
}

warn() {
    echo -e "${YELLOW} !     $*${NC}"
}

err() {
    echo -e "${RED} !!    $*${NC}" >&2
}

success() {
    echo -e "${GREEN}       Done.${NC}"
}

failure() {
    echo -e "${RED}       Failed.${NC}" >&2
    exit 1
}

start() {
    echo "${STEP} $*"
}

do_start() {
    echo -n "       $*... "
}

do_finish() {
    echo "OK."
}

do_fail() {
    echo "Failed."
}

read_env() {
    local env_dir
    local env_vars

    env_dir="${1}"
    env_vars=$( list_env_vars "${env_dir}" )

    while read -r e
    do
        local value
        value=$( cat "${env_dir}/${e}" )

        export "${e}=${value}"
    done <<< "${env_vars}"
}

list_env_vars() {
    local env_dir
    local env_vars
    local blacklist_regex

    env_dir="${1}"
    env_vars=""
    blacklist_regex="^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH|LD_LIBRARY_PATH)$"

    if [ -d "${env_dir}" ]
    then
        env_vars=$( ls "${env_dir}" \
                    | grep \
                        --invert-match \
                        --extended-regexp \
                        "${blacklist_regex}" )
    fi

    echo "${env_vars}"
}

check_cached_file() {
    local rc
    local cached
    local hash_url
    local ref
    local checksum

    rc=1
    cached="${1}"
    hash_url="${2}"

    curl --silent --location "${hash_url}" --output "${cached}.checksum"

    opt=0

    case "${hash_url##*.}" in
        "sha1")
            opt="1"
            ;;
        "sha256")
            opt="256"
            ;;
        *)
            echo "Unsupported hash." >&2
            ;;
    esac

    if [ ${opt} -gt 0 ]
    then
        checksum="$( shasum -a "${opt}" "${cached}" | cut -d ' ' -f 1 )"

        if [ -f "${cached}.checksum" ]
        then
            ref="$( cat "${cached}.checksum" | cut -d ' ' -f 1 )"

            if [ "${checksum}" == "${ref}" ]
            then
                rc=0
            else
                rm -f "${cached}"
            fi
        fi
    fi

    return "${rc}"
}

helper::github::retrieve_latest_release_info() {
    local rc
    local org
    local repo
    local base_url
    local output

    org="${1}"
    repo="${2}"
    rc=1
    base_url="https://api.github.com/repos/%s/%s/releases/latest"
    output="/tmp/${org}_${repo}_info"

    printf -v url "${base_url}" "${org}" "${repo}"

    if curl --fail --silent --location "${url}" --output "${output}"; then
        rc=0
        echo "${output}"
    fi

    return "${rc}"
}

helper::github::retrieve_latest_release_tarball_url() {
    local rc
    local info_file
    local url

    info_file="${1}"
    rc=1

    url="$( grep --perl-regexp \
                 --only-matching '"tarball_url": "\K.*?(?=")' \
                 "${info_file}" )"

    rc="${?}"

    if [ "${rc}" = "0" ]; then
        echo "${url}"
    fi

    return "${rc}"
}

helper::github::retrieve_latest_release_version() {
    local rc
    local info_file
    local version

    info_file="${1}"
    rc=1

    version="$( grep --perl-regexp \
                     --only-matching '"tag_name": "\K.*?(?=")' \
                     "${info_file}" )"

    rc="${?}"

    if [ "${rc}" = "0" ]; then
        echo "${version}"
    fi

    return "${rc}"
}

retrieve_github_latest_release() {
    local org
    local repo
    local info

    info="$( helper::github::retrieve_latest_release_info "${org}" "${repo}" )"

    helper::github::retrieve_latest_release_version "${info}"
}

download() {
    local rc
    local url
    local hash_url
    local cached

    rc=1
    url="${1}"
    hash_url="${2}"
    cached="${3}"

    curl --silent --location "${url}" --output "${cached}" \
        && check_cached_file "${cached}" "${hash_url}" \
        && rc=0

    return "${rc}"

}

