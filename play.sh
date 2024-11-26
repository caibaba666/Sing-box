#!/bin/bash

# 定义颜色
re="\033[0m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"

green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }

# 预设变量
USERNAME=$(whoami)
HOSTNAME=$(hostname)
UUID=${UUID:-'bc97f674-c578-4940-9234-0a1da46041b9'}
NEZHA_SERVER=${NEZHA_SERVER:-''}
NEZHA_PORT=${NEZHA_PORT:-'5555'}
NEZHA_KEY=${NEZHA_KEY:-''}
vless_port=23205
hy2_port=11983
tuic_port=43677

WORKDIR="domains/${USERNAME}.serv00.net/logs"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")

ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1

install_singbox() {
    echo -e "${yellow}开始安装sing-box，启用三协议：${purple}(vless-reality | hysteria2 | tuic)${re}"
    echo -e "${yellow}默认端口：VLESS=${vless_port}, Hysteria2=${hy2_port}, Tuic=${tuic_port}${re}"

    cd "$WORKDIR"

    ARCH=$(uname -m)
    DOWNLOAD_DIR="."
    mkdir -p "$DOWNLOAD_DIR"
    FILE_INFO=()

    if [[ "$ARCH" == "arm" || "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
        FILE_INFO=("https://github.com/eooce/test/releases/download/arm64/sb web" "https://github.com/eooce/test/releases/download/ARM/swith npm")
    elif [[ "$ARCH" == "amd64" || "$ARCH" == "x86_64" || "$ARCH" == "x86" ]]; then
        FILE_INFO=("https://github.com/eooce/test/releases/download/freebsd/sb web" "https://github.com/eooce/test/releases/download/freebsd/npm npm")
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi

    declare -A FILE_MAP
    generate_random_name() {
        local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
        local name=""
        for i in {1..6}; do
            name="$name${chars:RANDOM%${#chars}:1}"
        done
        echo "$name"
    }

    download_with_fallback() {
        local URL=$1
        local NEW_FILENAME=$2

        curl -L -sS --max-time 2 -o "$NEW_FILENAME" "$URL" &
        CURL_PID=$!
        CURL_START_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)

        sleep 1
        CURL_CURRENT_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)

        if [ "$CURL_CURRENT_SIZE" -le "$CURL_START_SIZE" ]; then
            kill $CURL_PID 2>/dev/null
            wait $CURL_PID 2>/dev/null
            wget -q -O "$NEW_FILENAME" "$URL"
            green "Downloading $NEW_FILENAME by wget"
        else
            wait $CURL_PID
            green "Downloading $NEW_FILENAME by curl"
        fi
    }

    for entry in "${FILE_INFO[@]}"; do
        URL=$(echo "$entry" | cut -d ' ' -f 1)
        RANDOM_NAME=$(generate_random_name)
        NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"

        if [ -e "$NEW_FILENAME" ]; then
            green "$NEW_FILENAME already exists, Skipping download"
        else
            download_with_fallback "$URL" "$NEW_FILENAME"
        fi

        chmod +x "$NEW_FILENAME"
        FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
    done
    wait

    output=$("./$(basename "${FILE_MAP[web]}")" generate reality-keypair)
    private_key=$(echo "$output" | awk '/PrivateKey:/ {print $2}')
    public_key=$(echo "$output" | awk '/PublicKey:/ {print $2}')

    openssl ecparam -genkey -name prime256v1 -out "private.key"
    openssl req -new -x509 -days 3650 -key "private.key" -out "cert.pem" -subj "/CN=$USERNAME.serv00.net"

    cat > config.json << EOF
{
  "log": { "disabled": true, "level": "info", "timestamp": true },
  "inbounds": [
    {
      "tag": "vless-reality",
      "type": "vless",
      "listen": "0.0.0.0",
      "listen_port": $vless_port,
      "users": [{ "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
      "tls": {
        "enabled": true,
        "server_name": "play-fe.googleapis.com",
        "reality": {
          "enabled": true,
          "handshake": { "server": "play-fe.googleapis.com", "server_port": 443 },
          "private_key": "$private_key",
          "short_id": [""]
        }
      }
    }
  ],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
EOF

    green "Sing-box 安装完成！"
}

# 执行安装
install_singbox
