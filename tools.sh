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

    cat << EOF > pages/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>iKuai 历史版本下载</title>
    <script src="https://unpkg.com/vue@3/dist/vue.global.prod.js"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.8.1/github-markdown.min.css">
    <style>
        .markdown-body {
            box-sizing: border-box;
            min-width: 200px;
            max-width: 980px;
            margin: 0 auto;
            padding: 45px;
        }

        @media (max-width: 767px) {
            .markdown-body {
                padding: 15px;
            }
        }
    </style>
</head>
<body class="markdown-body">
<div id="app">
    <h1>iKuai 历史固件下载</h1>
    <div>
        <label for="edition">固件类型：</label>
        <select id="edition" v-model="form.edition">
            <option value="free">免费版</option>
            <option value="enterprise">企业版</option>
            <option value="oem">OEM</option>
        </select>
    </div>
    <div>
        <label for="bit">系统位数：</label>
        <select id="bit" v-model="form.bit">
            <option value="64">64</option>
            <option value="32">32</option>
        </select>
    </div>
    <div>
        <label for="installation-type">固件格式：</label>
        <select id="installation-type" v-model="form.type">
            <option v-for="(value, key) in filteredTypeDict" :value="{url: key, suffix: value}">{{ value }}</option>
        </select>
    </div>
    <div>
        <label for="version">版本号：</label>
        <select id="version" v-model="form.version">
            <template v-for="each in filteredVersionList">
                <option v-if="each.includes('_')" v-bind:value="each">{{ each.split("_")[0]}}</option>
            </template>
        </select>
    </div>
    <h2>下载链接</h2>
    <div>
        <a v-bind:href="downloadLink">{{ downloadLink }}</a>
    </div>
</div>
</body>
<footer style="text-align: center" class="markdown-body">
    <a href="https://github.com/LucienShui/ikuai-firmware" target="_blank">GitHub</a>
    |
    <a href="https://www.ikuai8.com/index.php?option=com_content&view=article&id=331">iKuai 更新日志</a>
</footer>
<script>
    const {createApp} = Vue;
    const VersionList = ${VERSION_LIST};
    const EnterpriseVersionList = ${VERSION_ENTERPRISE_LIST};

    const OEMVersionList = [
        "3.7.14_Build202408071731",
        "3.6.5_Build202207280937"
    ]

    createApp({
        data() {
            return {
                typeDict: {
                    iso: "iso",
                    img: "img.gz",
                    ghost: "gho",
                    patch: "bin",
                },
                historyVersionList: VersionList,
                historyEnterpriseVersionList: EnterpriseVersionList,
                historyOEMVersionList: OEMVersionList,
                form: {
                    edition: "free",
                    type: {url: "iso", suffix: "iso"},
                    bit: "64",
                    version: VersionList[0]
                }
            }
        },
        computed: {
            filteredTypeDict() {
                if (this.form.edition === "enterprise" || this.form.edition === "oem") {
                    return {patch: "bin"};
                }
                return this.typeDict;
            },
            filteredBitOptions() {
                return this.form.bit;
            },
            filteredVersionList() {
                if (this.form.edition === "enterprise") {
                    return this.historyEnterpriseVersionList
                } else if (this.form.edition === "oem") {
                    return this.historyOEMVersionList
                }
                return this.historyVersionList;
            },
            downloadLink() {
                let baseUrl = this.form.edition === "enterprise" ? "https://patch.ikuai8.com/ent/" : "https://patch.ikuai8.com/3.x/";

                let link =
                    baseUrl +
                    ((this.form.edition === "enterprise") ? "" : this.form.type.url + "/") +
                    (this.form.edition === "oem" ? "oem_x" : "iKuai8_x") +
                    this.form.bit +
                    "_" +
                    this.form.version;

                if (this.form.edition === "enterprise") {
                    const index = link.indexOf("Build");
                    link = link.slice(0, index) + "Enterprise_" + link.slice(index);
                }

                return link + "." + this.form.type.suffix;
            }
        },
        watch: {
            "form.edition"(newEdition) {
                // 重置为第一项
                const firstTypeOption = Object.entries(this.filteredTypeDict)[0];
                if (firstTypeOption) {
                    const [key, value] = firstTypeOption;
                    this.form.type = { url: key, suffix: value };
                }
                if (this.filteredBitOptions.length > 0) {
                    this.form.bit = this.filteredBitOptions;
                }
                if (this.filteredVersionList.length > 0) {
                    this.form.version = this.filteredVersionList[0];
                }
            }
        }
    }).mount("#app")
</script>
</html>
EOF
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
