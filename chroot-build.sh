#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== [1/3] Actualizando repositorios e instalando dependencias para lingmo-statusbar ==="
rm -f /etc/apt/sources.list.d/*lingmo* || true
apt-get update || true

apt-get install -y --no-install-recommends \
  build-essential cmake pkg-config extra-cmake-modules \
  qtbase5-dev qtdeclarative5-dev qtquickcontrols2-5-dev qttools5-dev qttools5-dev-tools libqt5x11extras5-dev \
  libxcb1-dev libxcb-keysyms1-dev libx11-dev libx11-xcb-dev libxcursor-dev libxi-dev libxfixes-dev libxrandr-dev libxtst-dev libxcomposite-dev libxdamage-dev \
  libkf5windowsystem-dev libkf5config-dev libkf5networkmanagerqt-dev modemmanager-qt-dev libkf5coreaddons-dev libkf5i18n-dev || true

echo "=== [2/3] Compilando lingmo-statusbar oficial con Barra Blanca Cutefish ==="
cd /tmp/lingmo-statusbar
rm -rf build && mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
make install

echo "=== [3/3] Verificando instalacion de /usr/bin/lingmo-statusbar ==="
ls -lh /usr/bin/lingmo-statusbar
test -f /usr/bin/lingmo-statusbar

rm -rf /tmp/lingmo-statusbar
apt-get clean
