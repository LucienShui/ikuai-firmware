#!/usr/bin/env sh
set -e
TMP_DIR="$(mktemp -d)"

clean_up() {
	rm -rf "${TMP_DIR}"
}

trap clean_up EXIT

parse_version_list() {
    RESULT="["
    while read line; do
        RESULT="${RESULT}\n        \"${line}\","
    done < ${1}
    RESULT="${RESULT%?}" # 移除最后一个 ","
    RESULT="${RESULT}\n    ]"
    echo "${RESULT}"
}

main() {
    LOCAL_LATEST_VERSION="$(head -n 1 version_list.txt | awk -F'_' '{print $1}')"
    LOCAL_LATEST_ENTERPRISE_VERSION="$(head -n 1 version_enterprise_list.txt | awk -F'_' '{print $1}')"
    if [ -z "${LOCAL_LATEST_VERSION}" ]; then
        echo "Error: LOCAL_LATEST_VERSION is empty."
        exit 1
    fi

    ONLINE_LATEST_VERSION="$(curl -s "https://download.ikuai8.com/submit3x/Version_all" | awk '/\[X86\]/ {flag=1} flag && /firmware/ {print $3; exit}' | sed -E 's/iKuai8_(x32_|x64_)?([0-9.]+)_Build([0-9]+).bin/iKuai8_\2_Build\3/')"
    ONLINE_LATEST_ENTERPRISE_VERSION="$(curl -s "https://download.ikuai8.com/submit3x/Version_all" | awk '/\[X86ENT\]/ {flag=1} flag && /firmware/ {print $3; exit}' | sed -E 's/iKuai8_(x32_|x64_)?([0-9.]+)_Enterprise_Build([0-9]+).bin/iKuai8_\2_Build\3/')"
    if [ -z "${ONLINE_LATEST_VERSION}" ] || [ -z "${ONLINE_LATEST_ENTERPRISE_VERSION}" ]; then
        echo "Error: ONLINE_LATEST_VERSION is empty."
        exit 1
    fi

    if [ "${LOCAL_LATEST_VERSION}" != "${ONLINE_LATEST_VERSION}" ] || [ "${LOCAL_LATEST_ENTERPRISE_VERSION}" != "${ONLINE_LATEST_ENTERPRISE_VERSION}" ]; then
        BUF_FILE="${TMP_DIR}/version_list.txt"
        BUF_ENTERPRISE_FILE="${TMP_DIR}/version_enterprise_list.txt"

        echo "${ONLINE_LATEST_VERSION}" > "${BUF_FILE}"
        echo "${LOCAL_LATEST_ENTERPRISE_VERSION}" > "${BUF_ENTERPRISE_FILE}"

        cat version_list.txt >> "${BUF_FILE}"
        cat version_enterprise_list.txt >> "${BUF_ENTERPRISE_FILE}"

        yes | cp "${BUF_FILE}" version_list.txt
        yes | cp "${BUF_ENTERPRISE_FILE}" version_enterprise_list.txt

        VERSION_LIST="$(parse_version_list ${BUF_FILE})"
        VERSION_ENTERPRISE_LIST="$(parse_version_list ${BUF_FILE})"
        cat << EOF > index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>iKuai 历史版本下载</title>
    <script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>
</head>
<body>
<div id="app">
    <div>
        <label for="edition">固件类型：</label>
        <select id="edition" v-model="form.edition">
            <option value="free">免费版</option>
            <option value="enterprise">企业版</option>
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
    <div>
        <p>历史日志：<a href="https://www.ikuai8.com/index.php?option=com_content&view=article&id=331">iKuai - 历史日志</a>
        </p>
        <p>下载链接：<a v-bind:href="downloadLink">{{ downloadLink }}</a></p>
    </div>
</div>
</body>
<script>
    const {createApp} = Vue;
    const VersionList = ${VERSION_LIST};
    const VersionList = ${VERSION_ENTERPRISE_LIST};

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
                if (this.form.edition === "enterprise") {
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
                }
                return this.historyVersionList;
            },
            downloadLink() {
                const baseUrl =
                    this.form.edition === "enterprise"
                        ? "https://patch.ikuai8.com/ent/"
                        : "https://patch.ikuai8.com/3.x/";

                let link =
                    baseUrl +
                    (this.form.edition === "enterprise" ? "" : this.form.type.url) +
                    "/iKuai8_x" +
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
        git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
        git config --local user.name "github-actions[bot]"
        git add version_list.txt index.html
        git commit -m "$(date +'%Y%m%d') add ${ONLINE_LATEST_VERSION}"
    fi
}

main
