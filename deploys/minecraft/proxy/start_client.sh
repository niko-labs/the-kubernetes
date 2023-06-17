OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')

if [ ${ARCH} = "x86_64" ]; then
  ARCH="amd64"
elif [ ${ARCH} = "armv7l" ]; then
  ARCH="arm"
elif [ ${ARCH} = "aarch64" ]; then
  ARCH="arm64"
fi

VERSION=0.49.0
DIRECTORY=./frp
SERVER_PROXY_IP=$SERVER_PROXY_IP
SERVER_PROXY_PORT=$SERVER_PROXY_PORT

URL="https://github.com/fatedier/frp/releases/download/v${VERSION}/frp_${VERSION}_${OS}_${ARCH}.tar.gz"

# PRINT VARIABLES
echo "OS: ${OS}"
echo "ARCH: ${ARCH}"
echo "VERSION: ${VERSION}"
echo "URL: ${URL}"

# CREATE DIRECTORY
mkdir -p ${DIRECTORY}/

# DOWNLOAD AND EXTRACT
curl https://github.com/fatedier/frp/releases/download/v${VERSION}/frp_${VERSION}_${OS}_${ARCH}.tar.gz -L | tar -xvz -C ./${DIRECTORY} --strip-components=1

# CHANGE DIRECTORY
cd ${DIRECTORY}/

# CREATE CONFIG FILE
cat > frpc_cfg.ini <<EOF
[common]
server_addr = ${SERVER_PROXY_IP}
server_port = ${SERVER_PROXY_PORT}
EOF

# CHANGE PERMISSIONS AND START
chmod +x ./${DIRECTORY}/frps
chmod +x ./${DIRECTORY}/frpc

./frpc -c ./frpc_cfg.ini | exit 1


git config --global http.sslVerify false
