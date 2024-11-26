install_singbox() {
    echo -e "${yellow}开始安装sing-box，启用三协议：${purple}(vless-reality | hysteria2 | tuic)${re}"
    echo -e "${yellow}默认端口：VLESS=${vless_port}, Hysteria2=${hy2_port}, Tuic=${tuic_port}${re}"

    cd "$WORKDIR" || exit 1

    ARCH=$(uname -m)
    DOWNLOAD_DIR="."
    mkdir -p "$DOWNLOAD_DIR"

    if [[ "$ARCH" == "arm" || "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
        FILE_INFO=("https://github.com/eooce/test/releases/download/arm64/sb web")
    elif [[ "$ARCH" == "amd64" || "$ARCH" == "x86_64" || "$ARCH" == "x86" ]]; then
        FILE_INFO=("https://github.com/eooce/test/releases/download/freebsd/sb web")
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi

    for entry in "${FILE_INFO[@]}"; do
        URL=$(echo "$entry" | cut -d ' ' -f 1)
        NEW_FILENAME="$DOWNLOAD_DIR/$(basename "$URL")"
        echo "Downloading $URL ..."
        curl -L -sS --max-time 10 -o "$NEW_FILENAME" "$URL"
        chmod +x "$NEW_FILENAME"
    done

    output=$("./sb" generate reality-keypair)
    private_key=$(echo "$output" | awk '/PrivateKey:/ {print $2}')
    public_key=$(echo "$output" | awk '/PublicKey:/ {print $2}')

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
          "short_id": ["123456"]
        }
      }
    }
  ],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
EOF

    green "Sing-box 安装完成！配置文件已生成：config.json"
}
