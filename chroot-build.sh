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

echo "=== [3.5/4] Compilando lingmo-settings oficial con soporte de apariencia de barra superior ==="
if [ -d "/tmp/lingmo-settings" ]; then
    apt-get install -y --no-install-recommends libicu-dev libcrypt-dev libfreetype6-dev libfontconfig1-dev || true
    cd /tmp/lingmo-settings
    rm -rf build && mkdir build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release || true
    if [ -f "Makefile" ]; then
        make -j$(nproc) || true
        make install || true
    fi
    cd /
    rm -rf /tmp/lingmo-settings
fi

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

echo "=== [5/6] Compilando daemon nativo en C para tecla Windows (Super Key Launcher) ==="
cat << 'SUPERKEY_C' > /tmp/superkey-launcher.c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <X11/Xlib.h>
#include <X11/keysym.h>
#include <X11/extensions/record.h>

static int super_pressed = 0;
static int other_key_pressed = 0;
static KeyCode code_super_l = 133;
static KeyCode code_super_r = 134;

void callback(XPointer closure, XRecordInterceptData *data) {
    if (data->category == XRecordFromServer) {
        unsigned char *b = (unsigned char *)data->data;
        int type = b[0] & 0x7F;
        int keycode = b[1];

        // Keycodes para Super_L (133) y Super_R (134) o detectados dinamicamente
        if (keycode == 133 || keycode == 134 || keycode == code_super_l || keycode == code_super_r) {
            if (type == KeyPress) {
                super_pressed = 1;
                other_key_pressed = 0;
            } else if (type == KeyRelease) {
                if (super_pressed && !other_key_pressed) {
                    // Pulsación solitaria de tecla Windows -> Abrir/Conmutar el lanzador
                    pid_t pid = fork();
                    if (pid == 0) {
                        setsid();
                        system("sh -c 'if which lingmo-launcher >/dev/null 2>&1; then lingmo-launcher; elif which cutefish-launcher >/dev/null 2>&1; then cutefish-launcher; else dbus-send --session --dest=com.lingmo.Launcher --type=method_call /Launcher com.lingmo.Launcher.toggle 2>/dev/null || dbus-send --session --dest=org.cutefish.Launcher --type=method_call /Launcher org.cutefish.Launcher.toggle 2>/dev/null; fi' >/dev/null 2>&1 &");
                        exit(0);
                    }
                }
                super_pressed = 0;
                other_key_pressed = 0;
            }
        } else {
            if (type == KeyPress && super_pressed) {
                other_key_pressed = 1; // Combinación como Windows+Tab o Windows+L
            }
        }
    }
    XRecordFreeData(data);
}

int main() {
    signal(SIGCHLD, SIG_IGN);

    Display *ctrl_dpy = NULL;
    Display *data_dpy = NULL;

    // Reintentar conexión con X11 hasta 30 segundos mientras inicia el servidor grafico
    for (int i = 0; i < 60; i++) {
        ctrl_dpy = XOpenDisplay(NULL);
        data_dpy = XOpenDisplay(NULL);
        if (ctrl_dpy && data_dpy) break;
        if (ctrl_dpy) { XCloseDisplay(ctrl_dpy); ctrl_dpy = NULL; }
        if (data_dpy) { XCloseDisplay(data_dpy); data_dpy = NULL; }
        usleep(500000);
    }

    if (!ctrl_dpy || !data_dpy) {
        return 1;
    }

    KeyCode kl = XKeysymToKeycode(ctrl_dpy, XK_Super_L);
    KeyCode kr = XKeysymToKeycode(ctrl_dpy, XK_Super_R);
    if (kl != 0) code_super_l = kl;
    if (kr != 0) code_super_r = kr;

    XRecordRange *range = XRecordAllocRange();
    range->device_events.first = KeyPress;
    range->device_events.last = KeyRelease;

    XRecordClientSpec spec = XRecordAllClients;
    XRecordContext ctx = XRecordCreateContext(ctrl_dpy, 0, &spec, 1, &range, 1);
    XFree(range);
    XSync(ctrl_dpy, False);

    XRecordEnableContext(data_dpy, ctx, callback, NULL);
    return 0;
}
SUPERKEY_C

gcc -O2 /tmp/superkey-launcher.c -lX11 -lXtst -o /usr/bin/superkey-launcher || true
chmod 755 /usr/bin/superkey-launcher || true
rm -f /tmp/superkey-launcher.c

mkdir -p /etc/xdg/autostart
cat << 'SUPERKEY_AUTOSTART' > /etc/xdg/autostart/superkey-launcher.desktop
[Desktop Entry]
Type=Application
Name=Super Key Launcher Daemon
Exec=/usr/bin/superkey-launcher
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
SUPERKEY_AUTOSTART
chmod 644 /etc/xdg/autostart/superkey-launcher.desktop

mkdir -p /etc/X11/Xsession.d
cat << 'XSESSION_SUPER' > /etc/X11/Xsession.d/92superkey-launcher
if [ -x /usr/bin/superkey-launcher ]; then
    /usr/bin/superkey-launcher &
fi
XSESSION_SUPER
chmod +x /etc/X11/Xsession.d/92superkey-launcher

echo "=== [6/6] Reparando Deteccion de Discos NVMe / SATA / RST en Calamares Installer ==="
# 1. Instalar utilidades esenciales de almacenamiento y detección de particiones
apt-get install -y --no-install-recommends \
  nvme-cli mdadm libblockdev-nvme2 smartmontools parted gparted kpmcore ntfs-3g dosfstools btrfs-progs e2fsprogs fdisk || true

# 2. Renombrar calamares a calamares.bin y crear wrapper con permisos root e inicialización de discos
for cp_path in /usr/bin/calamares /usr/sbin/calamares /usr/local/bin/calamares; do
    if [ -f "$cp_path" ] && [ ! -f "${cp_path}.bin" ]; then
        mv "$cp_path" "${cp_path}.bin"
    fi
done

cat << 'CALAMARES_WRAPPER' > /usr/bin/calamares
#!/bin/bash
# Habilitar acceso de root al display X11
xhost +local:root >/dev/null 2>&1 || true
xhost +local:lingmo >/dev/null 2>&1 || true
xhost +local: >/dev/null 2>&1 || true

# Cargar modulos criticos de almacenamiento y particiones
modprobe nvme 2>/dev/null || true
modprobe nvme_core 2>/dev/null || true
modprobe vmd 2>/dev/null || true
modprobe ahci 2>/dev/null || true
modprobe sd_mod 2>/dev/null || true
modprobe dm_mod 2>/dev/null || true

# Escaneo forzado de discos y particiones
nvme list >/dev/null 2>&1 || true
partprobe >/dev/null 2>&1 || true

REAL_BIN=""
for b in /usr/bin/calamares.bin /usr/sbin/calamares.bin /usr/local/bin/calamares.bin; do
    if [ -x "$b" ]; then
        REAL_BIN="$b"
        break
    fi
done

if [ -z "$REAL_BIN" ]; then
    REAL_BIN="/usr/bin/calamares.bin"
fi

# Ejecutar calamares como root real preservando el entorno de display
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$REAL_BIN" "$@"
else
    exec "$REAL_BIN" "$@"
fi
CALAMARES_WRAPPER
chmod +x /usr/bin/calamares

# Enlazar en /usr/sbin y /usr/local/bin si es necesario
[ ! -f /usr/sbin/calamares ] || cp -f /usr/bin/calamares /usr/sbin/calamares
[ ! -f /usr/local/bin/calamares ] || cp -f /usr/bin/calamares /usr/local/bin/calamares

# 3. Configurar sudoers para usuario lingmo sin contraseña
mkdir -p /etc/sudoers.d
cat << 'SUDOERS_CALAMARES' > /etc/sudoers.d/calamares
ALL ALL=(ALL) NOPASSWD: ALL
SUDOERS_CALAMARES
chmod 440 /etc/sudoers.d/calamares

# Agregar usuario lingmo a los grupos de administracion de discos
usermod -aG sudo,disk,storage lingmo 2>/dev/null || true

# 4. Modificar lanzadores desktop de calamares para ejecutar con permisos completos
find /usr/share/applications -name "*calamares*.desktop" -exec sed -i 's/^Exec=.*/Exec=sudo -E \/usr\/bin\/calamares/g' {} + || true

# 5. Cargar modulos de kernel en boot y en initramfs
mkdir -p /etc/modules-load.d
cat << 'MODULES_STORAGE' > /etc/modules-load.d/storage.conf
nvme
nvme_core
vmd
ahci
sd_mod
dm_mod
MODULES_STORAGE

mkdir -p /etc/initramfs-tools
cat << 'INITRAMFS_MODULES' >> /etc/initramfs-tools/modules
nvme
nvme_core
vmd
ahci
sd_mod
INITRAMFS_MODULES
update-initramfs -u || true

# 6. Desactivar bloqueo preventivo en welcome.conf de Calamares y habilitar particionado manual
find /etc/calamares /usr/share/calamares -name "welcome.conf" -exec sed -i '/- storage/d' {} + 2>/dev/null || true
find /etc/calamares /usr/share/calamares -name "welcome.conf" -exec sed -i '/- partitions/d' {} + 2>/dev/null || true
find /etc/calamares /usr/share/calamares -name "welcome.conf" -exec sed -i 's/requiredStorage:.*/requiredStorage: 1.0/g' {} + 2>/dev/null || true
find /etc/calamares /usr/share/calamares -name "partition.conf" -exec sed -i 's/allowManualPartitioning:.*/allowManualPartitioning: true/g' {} + 2>/dev/null || true

# 6. Configurar valores por defecto de la barra superior (Auto: sincronizada con modo oscuro)
mkdir -p /etc/skel/.config/lingmoos
cat << 'STATUSBAR_DEFAULT' > /etc/skel/.config/lingmoos/statusbar.conf
[General]
BarStyle=0
STATUSBAR_DEFAULT

for u_home in /home/* /root; do
    if [ -d "$u_home" ]; then
        mkdir -p "$u_home/.config/lingmoos"
        cp -f /etc/skel/.config/lingmoos/statusbar.conf "$u_home/.config/lingmoos/statusbar.conf" 2>/dev/null || true
    fi
done

# 7. Configurar comando helper para instalar Spotify oficial (.deb compatible con GLIBC 2.36)
cat << 'SPOTIFY_SH' > /usr/local/bin/instalar-spotify
#!/bin/bash
set -e
echo "=========================================================="
echo "    Instalador Oficial de Spotify (.deb para Debian 12)   "
echo "=========================================================="
echo "Descargando paquete oficial de Spotify compatible con GLIBC 2.36..."

TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

SPOTIFY_DEB="spotify-client_1.2.74.477.g00424584_amd64.deb"
wget -O "$SPOTIFY_DEB" "https://archive.org/download/spotify-client-1.2.74.477/$SPOTIFY_DEB" || \
wget -O "$SPOTIFY_DEB" "https://raw.githubusercontent.com/hetzelltellez/lingmo-os-cutefish/master/$SPOTIFY_DEB" || true

if [ -f "$SPOTIFY_DEB" ] && [ -s "$SPOTIFY_DEB" ]; then
    echo "Instalando Spotify..."
    apt-get update || true
    apt-get install -y "./$SPOTIFY_DEB" || dpkg -i "./$SPOTIFY_DEB" || apt-get install -f -y
    apt-mark hold spotify-client
    echo ""
    echo "=========================================================="
    echo "   Spotify ha sido instalado exitosamente en tu sistema!  "
    echo "=========================================================="
else
    echo "Error: No se pudo descargar el paquete .deb. Verifica tu conexion a internet."
fi

rm -rf "$TMP_DIR"
SPOTIFY_SH
chmod +x /usr/local/bin/instalar-spotify

rm -rf /tmp/lingmo-statusbar /tmp/lingmo-settings
apt-get clean
