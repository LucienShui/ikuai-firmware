#!/usr/bin/env bash
# set -e
TMP_DIR="$(mktemp -d)"

clean_up() {
	rm -rf "${TMP_DIR}"
}

trap clean_up EXIT

parse_version_list() {
    RESULT="["
    while read -r line; do
        RESULT="${RESULT}\"${line}\","
    done < "${1}"
    RESULT="${RESULT%?}" # 移除最后一个 ","
    RESULT="${RESULT}]"
    echo "${RESULT}"
}

fetch_free() {
    LOCAL_LATEST_VERSION="$(head -n 1 version_list.txt)"
    if [ -z "${LOCAL_LATEST_VERSION}" ]; then
        echo "ERROR: LOCAL_LATEST_VERSION is empty."
        return 1
    fi

    ONLINE_LATEST_VERSION="$(curl -s "https://download.ikuai8.com/submit3x/Version_all" | awk '/\[X86\]/ {flag=1} flag && /firmware/ {print $3; exit}' | sed -E 's/iKuai8_(x32_|x64_)?([0-9.]+)_Build([0-9]+).bin/\2_Build\3/')"
    if [ -z "${ONLINE_LATEST_VERSION}" ]; then
        echo "ERROR: ONLINE_LATEST_VERSION is empty."
        return 1
    fi

    if [ "${LOCAL_LATEST_VERSION}" = "${ONLINE_LATEST_VERSION}" ]; then
        echo "INFO: Same version, skip."
        return 1
    fi
    BUF_FILE="${TMP_DIR}/version_list.txt"
    echo "${ONLINE_LATEST_VERSION}" > "${BUF_FILE}"
    cat version_list.txt >> "${BUF_FILE}"
    /usr/bin/env cp "${BUF_FILE}" version_list.txt

    echo "${ONLINE_LATEST_VERSION}"
    return 0
}

fetch_enterprise() {
    LOCAL_LATEST_ENTERPRISE_VERSION="$(head -n 1 version_enterprise_list.txt)"
    if [ -z "${LOCAL_LATEST_ENTERPRISE_VERSION}" ]; then
        echo "ERROR: LOCAL_LATEST_ENTERPRISE_VERSION is empty."
        return 1
    fi

    ONLINE_LATEST_ENTERPRISE_VERSION="$(curl -s "https://download.ikuai8.com/submit3x/Version_all" | awk '/\[X86ENT\]/ {flag=1} flag && /firmware/ {print $3; exit}' | sed -E 's/iKuai8_(x32_|x64_)?([0-9.]+)_Enterprise_Build([0-9]+).bin/\2_Build\3/')"
    if [ -z "${ONLINE_LATEST_ENTERPRISE_VERSION}" ]; then
        echo "ERROR: ONLINE_LATEST_ENTERPRISE_VERSION is empty."
        return 1
    fi
    if [ "${LOCAL_LATEST_ENTERPRISE_VERSION}" = "${ONLINE_LATEST_ENTERPRISE_VERSION}" ]; then
        echo "INFO: Same version, skip."
        return 1
    fi
    BUF_ENTERPRISE_FILE="${TMP_DIR}/version_enterprise_list.txt"
    echo "${ONLINE_LATEST_ENTERPRISE_VERSION}" > "${BUF_ENTERPRISE_FILE}"
    cat version_enterprise_list.txt >> "${BUF_ENTERPRISE_FILE}"
    /usr/bin/env cp "${BUF_ENTERPRISE_FILE}" version_enterprise_list.txt
    
    echo "${ONLINE_LATEST_ENTERPRISE_VERSION}"
    return 0
}

generate() {
    VERSION_LIST="$(parse_version_list "version_list.txt")"
    VERSION_ENTERPRISE_LIST="$(parse_version_list "version_enterprise_list.txt")"

    mkdir -p pages
    cp resources/favicon.ico pages/

    # Read template, replace placeholders, and output to pages/index.html
    sed \
        -e "s|{{VERSION_LIST}}|${VERSION_LIST}|g" \
        -e "s|{{VERSION_ENTERPRISE_LIST}}|${VERSION_ENTERPRISE_LIST}|g" \
        resources/index.template.html > pages/index.html
}

fetch_and_commit() {
    ONLINE_LATEST_VERSION="$(fetch_free)"
    FREE_RESULT="${?}"

    ONLINE_LATEST_ENTERPRISE_VERSION="$(fetch_enterprise)"
    ENTERPRISE_RESULT="${?}"

    COMMIT_MESSAGE=""

    if [ "${FREE_RESULT}" -eq 0 ]; then
        COMMIT_MESSAGE="${ONLINE_LATEST_VERSION}"
    fi
    
    if [ "${ENTERPRISE_RESULT}" -eq 0 ]; then
        if [ "${FREE_RESULT}" -eq 0 ]; then
            COMMIT_MESSAGE="${COMMIT_MESSAGE} and "
        fi
        COMMIT_MESSAGE="${COMMIT_MESSAGE}${ONLINE_LATEST_ENTERPRISE_VERSION}"
    fi

    if [ "${FREE_RESULT}" -eq 0 ] || [ "${ENTERPRISE_RESULT}" -eq 0 ]; then
        git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
        git config --local user.name "github-actions[bot]"
        git add version_list.txt version_enterprise_list.txt
        git commit -m "$(date +'%Y%m%d') add ${COMMIT_MESSAGE}"
    fi
}

main() {
    case "${1}" in
        fetch_and_commit)
            fetch_and_commit
            ;;
        generate)
            generate
            ;;
        *)
            echo "Usage: bash tools.sh <fetch_and_commit|generate>"
            ;;
    esac
}

main "${@}"
