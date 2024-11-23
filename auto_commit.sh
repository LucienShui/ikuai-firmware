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
    LOCAL_LATEST_VERSION="$(head -n 1 version_list.txt)"
    if [ -z "${LOCAL_LATEST_VERSION}" ]; then
        echo "Error: LOCAL_LATEST_VERSION is empty."
        exit 1
    fi

    ONLINE_LATEST_VERSION="$(curl -sSL 'https://www.ikuai8.com/component/download' | grep 'btn btn_64' | grep "iso" | awk -F 'x64_' '{ print $2 }' | awk -F '.iso' '{ print $1 }')"
    if [ -z "${ONLINE_LATEST_VERSION}" ]; then
        echo "Error: ONLINE_LATEST_VERSION is empty."
        exit 1
    fi

    if [ "${LOCAL_LATEST_VERSION}" != "${ONLINE_LATEST_VERSION}" ]; then
        BUF_FILE="${TMP_DIR}/version_list.txt"
        echo "${ONLINE_LATEST_VERSION}" > "${BUF_FILE}"
        cat version_list.txt >> "${BUF_FILE}"
        yes | cp "${BUF_FILE}" version_list.txt
        VERSION_LIST="$(parse_version_list ${BUF_FILE})"
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
        <label for="bit">系统位数：</label>
        <select id="bit" v-model="form.bit">
            <option value="64">64</option>
            <option value="32">32</option>
        </select>
    </div>
    <div>
        <label for="installation-type">固件格式：</label>
        <select id="installation-type" v-model="form.type">
            <option v-for="(value, key) in typeDict" v-bind:value="{url: key, suffix: value}">{{ value }}</option>
        </select>
    </div>
    <div>
        <label for="version">版本号：</label>
        <select id="version" v-model="form.version">
            <template v-for="each in historyVersionList">
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
                form: {
                    type: {url: "iso", suffix: "iso"},
                    bit: "64",
                    version: VersionList[0]
                }
            }
        },
        computed: {
            downloadLink() {
                return "https://patch.ikuai8.com/3.x/" + this.form.type.url + "/iKuai8_x" + this.form.bit + "_" + this.form.version + "." + this.form.type.suffix;
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
