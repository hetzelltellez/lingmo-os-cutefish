#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== [1/4] Actualizando repositorios e instalando dependencias para lingmo-statusbar ==="
rm -f /etc/apt/sources.list.d/*lingmo* || true
apt-get update || true

apt-get install -y --no-install-recommends \
  build-essential cmake pkg-config extra-cmake-modules \
  qtbase5-dev qtdeclarative5-dev qtquickcontrols2-5-dev qttools5-dev qttools5-dev-tools libqt5x11extras5-dev \
  libxcb1-dev libxcb-keysyms1-dev libx11-dev libx11-xcb-dev libxcursor-dev libxi-dev libxfixes-dev libxrandr-dev libxtst-dev libxcomposite-dev libxdamage-dev \
  libkf5windowsystem-dev libkf5config-dev libkf5networkmanagerqt-dev modemmanager-qt-dev libkf5coreaddons-dev libkf5i18n-dev xinput || true

echo "=== [2/4] Compilando lingmo-statusbar oficial con Barra Blanca e Iconos Completos ==="
cd /tmp/lingmo-statusbar
rm -rf build && mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
make install

echo "=== [3/4] Verificando instalacion de /usr/bin/lingmo-statusbar ==="
ls -lh /usr/bin/lingmo-statusbar
test -f /usr/bin/lingmo-statusbar

echo "=== [4/4] Configurando Tap-to-Click (tocar para hacer clic) por defecto en Trackpads de Laptops ==="
mkdir -p /etc/X11/xorg.conf.d
cat << 'TOUCHPAD_EOF' > /etc/X11/xorg.conf.d/40-libinput.conf
Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "Tapping" "on"
        Option "TappingButtonMap" "lrm"
        Option "NaturalScrolling" "false"
        Option "ClickMethod" "buttonareas"
EndSection
TOUCHPAD_EOF

mkdir -p /etc/skel/.config/lingmoos
cat << 'TOUCHPAD_CONF' > /etc/skel/.config/lingmoos/touchpad.conf
[General]
tapToClick=true
naturalScroll=false
TOUCHPAD_CONF

mkdir -p /etc/skel/.config
cat << 'KCM_CONF' > /etc/skel/.config/kcminputrc
[Touchpad]
tapToClick=true
KCM_CONF

for u_home in /home/* /root; do
    if [ -d "$u_home" ]; then
        mkdir -p "$u_home/.config/lingmoos"
        cp -f /etc/skel/.config/lingmoos/touchpad.conf "$u_home/.config/lingmoos/touchpad.conf" 2>/dev/null || true
        mkdir -p "$u_home/.config"
        cp -f /etc/skel/.config/kcminputrc "$u_home/.config/kcminputrc" 2>/dev/null || true
    fi
done

mkdir -p /etc/X11/Xsession.d
cat << 'XSESSION_TAP' > /etc/X11/Xsession.d/90touchpad-tap
if which xinput >/dev/null 2>&1; then
    for id in $(xinput list --id-only 2>/dev/null); do
        prop=$(xinput list-props "$id" 2>/dev/null | grep -i "Tapping Enabled (" | head -n1 | grep -o -E '[0-9]+' | head -n1)
        if [ -n "$prop" ]; then
            xinput set-prop "$id" "$prop" 1 2>/dev/null || true
        fi
    done
fi
XSESSION_TAP
chmod +x /etc/X11/Xsession.d/90touchpad-tap

echo "=== [5/5] Configurando tecla Windows (Super / Meta) para abrir el Lanzador de Aplicaciones ==="
apt-get install -y --no-install-recommends xcape || true

# 1. Configurar KWin ModifierOnlyShortcuts (nativo de KDE/KWin)
mkdir -p /etc/xdg
cat << 'KWINRC_EOF' >> /etc/xdg/kwinrc

[ModifierOnlyShortcuts]
Meta=com.lingmo.Launcher,/Launcher,com.lingmo.Launcher,toggle
KWINRC_EOF

# 2. Configurar kwinrc en /etc/skel/.config
mkdir -p /etc/skel/.config
cat << 'KWINRC_USER_EOF' > /etc/skel/.config/kwinrc
[ModifierOnlyShortcuts]
Meta=com.lingmo.Launcher,/Launcher,com.lingmo.Launcher,toggle
KWINRC_USER_EOF

# 3. Configurar lingmoglobalshortcutsrc en /etc/skel/.config (leído por lingmo-core chotkeys)
cat << 'LINGMO_SHORTCUTS_EOF' > /etc/skel/.config/lingmoglobalshortcutsrc
[Meta]
Comment=Launcher
Exec=lingmo-launcher

[Alt+F1]
Comment=Launcher
Exec=lingmo-launcher
LINGMO_SHORTCUTS_EOF

# 4. Configurar kglobalshortcutsrc en /etc/skel/.config
cat << 'KGLOBAL_EOF' > /etc/skel/.config/kglobalshortcutsrc
[lingmo-launcher.desktop]
_k_friendly_name=Lingmo Launcher
_launch=Alt+F1\tMeta,none,Lingmo Launcher
KGLOBAL_EOF

# 5. Autostart para lingmo-launcher para respuesta inmediata en segundo plano
mkdir -p /etc/xdg/autostart
cat << 'LAUNCHER_AUTOSTART_EOF' > /etc/xdg/autostart/lingmo-launcher.desktop
[Desktop Entry]
Type=Application
Name=Lingmo Launcher
Exec=lingmo-launcher
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
LAUNCHER_AUTOSTART_EOF

# 6. Fallback con xcape en sesión X11
mkdir -p /etc/X11/Xsession.d
cat << 'XSESSION_SUPER' > /etc/X11/Xsession.d/91super-launcher
if which xcape >/dev/null 2>&1; then
    xcape -e 'Super_L=Alt_L|F1' &
fi
XSESSION_SUPER
chmod +x /etc/X11/Xsession.d/91super-launcher

# Copiar configuraciones a todas las carpetas de usuario (/home/* y /root)
for u_home in /home/* /root; do
    if [ -d "$u_home" ]; then
        mkdir -p "$u_home/.config"
        cp -f /etc/skel/.config/kwinrc "$u_home/.config/kwinrc" 2>/dev/null || true
        cp -f /etc/skel/.config/lingmoglobalshortcutsrc "$u_home/.config/lingmoglobalshortcutsrc" 2>/dev/null || true
        cp -f /etc/skel/.config/kglobalshortcutsrc "$u_home/.config/kglobalshortcutsrc" 2>/dev/null || true
    fi
done

echo "=== [6/6] Reparando Deteccion de Discos NVMe / SATA / RST en Calamares Installer ==="
# 1. Instalar utilidades esenciales de almacenamiento y detección de particiones
apt-get install -y --no-install-recommends \
  nvme-cli mdadm libblockdev-nvme2 smartmontools parted gparted kpmcore || true

# 2. Cargar automáticamente módulos de kernel para NVMe, VMD (Intel RST) y SATA en el arranque
mkdir -p /etc/modules-load.d
cat << 'MODULES_STORAGE' > /etc/modules-load.d/storage.conf
nvme
nvme_core
vmd
ahci
sd_mod
dm_mod
MODULES_STORAGE

# 3. Incluir módulos en initramfs para detección temprana del disco
mkdir -p /etc/initramfs-tools
cat << 'INITRAMFS_MODULES' >> /etc/initramfs-tools/modules
nvme
nvme_core
vmd
ahci
sd_mod
INITRAMFS_MODULES
update-initramfs -u || true

# 4. Asegurar permisos de administrador para Calamares en el entorno Live
mkdir -p /etc/polkit-1/rules.d
cat << 'POLKIT_CALAMARES' > /etc/polkit-1/rules.d/49-calamares.rules
polkit.addRule(function(action, subject) {
    if ((action.id == "org.debian.pkexec.calamares" ||
         action.id == "com.github.calamares.calamares" ||
         action.id == "org.freedesktop.policykit.exec") &&
        (subject.isInGroup("sudo") || subject.user == "lingmo")) {
        return polkit.Result.YES;
    }
});
POLKIT_CALAMARES

# 5. Configurar bienvenida de Calamares para no bloquear por particiones previas
if [ -f /etc/calamares/modules/welcome.conf ]; then
    sed -i '/- partitions/d' /etc/calamares/modules/welcome.conf || true
fi

rm -rf /tmp/lingmo-statusbar
apt-get clean
