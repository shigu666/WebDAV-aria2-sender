#!/bin/bash

# 脚本使用说明
usage() {
    echo "用法: $0 -u <http用户名> -p <http密码> -r <aria2的rpc地址> [-t <aria2的rpc认证token>] [-d <下载路径>] -l <txt文件路径>"
    echo ""
    echo "参数说明:"
    echo "  -u  HTTP认证用户名"
    echo "  -p  HTTP认证密码"
    echo "  -r  aria2 RPC地址 (例如: http://127.0.0.1:6800/jsonrpc)"
    echo "  -t  aria2 RPC认证token (可选)"
    echo "  -d  下载路径 (可选，默认为当前目录)"
    echo "  -l  包含URL和文件名的txt文件路径"
    echo ""
    echo "txt文件格式:"
    echo "  每行: URL<tab>文件名"
    echo "  示例: http://example.com/file.zip<tab>myfile.zip"
    exit 1
}

# 初始化变量
USERNAME=""
PASSWORD=""
RPC_URL=""
TOKEN=""
DOWNLOAD_DIR="."
TXT_FILE=""

# 解析命令行参数
while getopts "u:p:r:t:d:l:h" opt; do
    case $opt in
        u) USERNAME="$OPTARG" ;;
        p) PASSWORD="$OPTARG" ;;
        r) RPC_URL="$OPTARG" ;;
        t) TOKEN="$OPTARG" ;;
        d) DOWNLOAD_DIR="$OPTARG" ;;
        l) TXT_FILE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# 检查必需参数
if [[ -z "$USERNAME" || -z "$PASSWORD" || -z "$RPC_URL" || -z "$TXT_FILE" ]]; then
    echo "错误: 缺少必需参数"
    usage
fi

# 检查文件是否存在
if [[ ! -f "$TXT_FILE" ]]; then
    echo "错误: 文件 '$TXT_FILE' 不存在"
    exit 1
fi

# 创建下载目录（如果不存在）
mkdir -p "$DOWNLOAD_DIR"

# 计数器
total=0
success=0
fail=0

echo "开始处理下载任务..."
echo "下载目录: $DOWNLOAD_DIR"
echo "RPC地址: $RPC_URL"
echo "========================================"

# 读取txt文件的每一行
while IFS=$'\t' read -r url filename || [[ -n "$url" ]]; do
    # 跳过空行
    if [[ -z "$url" || -z "$filename" ]]; then
        continue
    fi
    
    # 去除可能的空白字符
    url=$(echo "$url" | xargs)
    filename=$(echo "$filename" | xargs)
    
    ((total++))
    
    echo "添加任务 $total: $filename"
    echo "  URL: $url"
    
    # 构建JSON-RPC请求
    json_request=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "id": "$total",
    "method": "aria2.addUri",
    "params": [
EOF
)
    
    # 如果有token，添加到params的第一个元素
    if [[ -n "$TOKEN" ]]; then
        json_request+="\n        \"token:$TOKEN\","
    fi
    
    # 继续构建JSON
    json_request+=$(cat <<EOF
        
        ["$url"],
        {
            "dir": "$DOWNLOAD_DIR",
            "out": "$filename",
            "header": ["Authorization: Basic $(echo -n "$USERNAME:$PASSWORD" | base64)"]
        }
    ]
}
EOF
)
    
    # 发送请求到aria2 RPC
    response=$(echo -e "$json_request" | curl -s -X POST \
        -H "Content-Type: application/json" \
        -d @- \
        "$RPC_URL" 2>/dev/null)
    
    # 检查响应
    if echo "$response" | grep -q '"result":'; then
        gid=$(echo "$response" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        if [[ -n "$gid" ]]; then
            echo "  状态: 成功 (GID: $gid)"
            ((success++))
        else
            echo "  状态: 失败 - 未获取到GID"
            echo "  响应: $response"
            ((fail++))
        fi
    else
        echo "  状态: 失败"
        echo "  响应: $response"
        ((fail++))
    fi
    
    echo "  -----------------------------------------"
    
done < "$TXT_FILE"

echo "========================================"
echo "任务完成统计:"
echo "  总计: $total"
echo "  成功: $success"
echo "  失败: $fail"
echo "========================================"

if [[ $fail -eq 0 ]]; then
    exit 0
else
    echo "有 $fail 个任务添加失败"
    exit 1
fi