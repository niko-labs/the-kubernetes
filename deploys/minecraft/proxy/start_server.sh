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
cat > frps_cfg.ini <<EOF
[common]
bind_port = 7000
vhost_http_port = 80

admin_addr = 0.0.0.0
admin_port = 9999
admin_user = admin
admin_pwd = admin

dashboard_port = 7575
EOF

# CHANGE PERMISSIONS AND START
sudo chmod +x ./frps
sudo chmod +x ./frpc

sudo ./frps -c ./frps_cfg.ini
