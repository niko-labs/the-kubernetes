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
NAMESPACE=$NAMESPACE
LOCAL_IP=$LOCAL_IP
LOCAL_PORT=$LOCAL_PORT
REMOTE_PORT=$REMOTE_PORT
WITH_PRIVILEGE=$WITH_PRIVILEGE

URL="https://github.com/fatedier/frp/releases/download/v${VERSION}/frp_${VERSION}_${OS}_${ARCH}.tar.gz"

# PRINT VARIABLES
echo "OS: ${OS}"
echo "ARCH: ${ARCH}"
echo "VERSION: ${VERSION}"
echo "DIRECTORY: ${DIRECTORY}"
echo "WITH_PRIVILEGE: ${WITH_PRIVILEGE}"
echo "NAMESPACE: ${NAMESPACE}"
echo "LOCAL_IP: ${LOCAL_IP}"
echo "LOCAL_PORT: ${LOCAL_PORT}"
echo "SERVER_PROXY_IP: ${SERVER_PROXY_IP}"
echo "SERVER_PROXY_PORT: ${SERVER_PROXY_PORT}"

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

[${NAMESPACE}]
type = tcp
local_ip = ${LOCAL_IP}
local_port = ${LOCAL_PORT}
remote_port = ${REMOTE_PORT}
EOF

if [[ -n "${WITH_PRIVILEGE}" && ${WITH_PRIVILEGE} = "N" ]]; then
  echo "--> no sudo"
  chmod +x ./frpc
  chmod +x ./frps
  ./frpc -c ./frpc_cfg.ini
else
  echo "--> with sudo"
  sudo chmod +x ./frpc
  sudo chmod +x ./frps
  sudo ./frpc -c ./frpc_cfg.ini
fi
