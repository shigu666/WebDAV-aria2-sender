#!/bin/bash

# 用法说明
usage() {
    echo "用法: $0 -w <webdav_url> -u <username> -p <passwd> [-r <aria2_rpc_url>] [-t <aria2_token>] [-d <aria2_dir>]"
    echo "示例: $0 -w https://webdav.example.com/parentdir/subdir/ -u user -p pass -r http://127.0.0.1:6800/jsonrpc -t secret -d /downloads"
    exit 1
}

# 默认值
ARIA2_RPC="http://127.0.0.1:6800/jsonrpc"
ARIA2_TOKEN=""
ARIA2_DIR=""

# 解析参数
while getopts "w:u:p:r:t:d:" opt; do
    case $opt in
        w) WEBDAV_URL="$OPTARG" ;;
        u) USERNAME="$OPTARG" ;;
        p) PASSWD="$OPTARG" ;;
        r) ARIA2_RPC="$OPTARG" ;;
        t) ARIA2_TOKEN="$OPTARG" ;;
        d) ARIA2_DIR="$OPTARG" ;;
        *) usage ;;
    esac
done

# 必填参数检查
if [[ -z "$WEBDAV_URL" || -z "$USERNAME" || -z "$PASSWD" ]]; then
    usage
fi

# 确保 URL 以 / 结尾
WEBDAV_URL="${WEBDAV_URL%/}/"

# 临时文件
XML_FILE="webdav_listing.xml"
URL_LIST="webdav_urls.txt"

echo "正在从 WebDAV 获取目录列表..."
curl -u "$USERNAME:$PASSWD" "$WEBDAV_URL" -X PROPFIND --silent --show-error -o "$XML_FILE"

if [[ $? -ne 0 || ! -s "$XML_FILE" ]]; then
    echo "错误：无法获取 WebDAV XML 文件"
    exit 1
fi

echo "正在解析 XML 并生成完整 URL 列表..."
# 调用xml解析
java -jar WebDAVParser.jar "$XML_FILE" "$URL_LIST" "$WEBDAV_URL"

if [[ $? -ne 0 ]]; then
    echo "错误：Java 程序执行失败"
    rm -f "$XML_FILE" "$URL_LIST"
    exit 1
fi

echo "文件列表已生成：$URL_LIST（共 $(wc -l < "$URL_LIST") 个文件）"

#调用下载脚本
echo "正在向 Aria2 添加下载任务..."
./aria2-add-from-list.sh -u "$USERNAME" -p "$PASSWD" -r "$ARIA2_RPC" ${ARIA2_TOKEN:+-t "$ARIA2_TOKEN"} ${ARIA2_DIR:+-d "$ARIA2_DIR"} -l "$URL_LIST"
if [[ $? -eq 0 ]]; then
    echo "所有任务已成功提交至 Aria2"
fi


# 清理 XML （保留 URL 列表供检查）
rm -f "$XML_FILE"