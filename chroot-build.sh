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

echo "=== [3.6/4] Compilando lingmo-dock oficial con menu de apagado en launcher ==="
if [ -d "/tmp/lingmo-dock" ]; then
    cd /tmp/lingmo-dock
    rm -rf build && mkdir build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release || true
    if [ -f "Makefile" ]; then
        make -j$(nproc) || true
        make install || true
    fi
    cd /
    rm -rf /tmp/lingmo-dock
    echo "=== Verificando binario /usr/bin/lingmo-dock compilado ==="
    ls -lh /usr/bin/lingmo-dock || true
fi

echo "=== [4/4] Configurando Touchpad (Tap-to-Click y Natural Scrolling) y Dock/KWin por defecto ==="
mkdir -p /etc/X11/xorg.conf.d
cat << 'TOUCHPAD_EOF' > /etc/X11/xorg.conf.d/40-libinput.conf
Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "Tapping" "on"
        Option "TappingButtonMap" "lrm"
        Option "NaturalScrolling" "true"
        Option "ClickMethod" "buttonareas"
EndSection
TOUCHPAD_EOF

mkdir -p /etc/skel/.config/lingmoos /etc/skel/.config/cutefishos
cat << 'TOUCHPAD_CONF' > /etc/skel/.config/lingmoos/touchpad.conf
[General]
tapToClick=true
naturalScroll=true
TOUCHPAD_CONF
cp -f /etc/skel/.config/lingmoos/touchpad.conf /etc/skel/.config/cutefishos/touchpad.conf 2>/dev/null || true

# Configurar Dock por defecto en Smart Hide (Visibility=2)
cat << 'DOCK_CONF' > /etc/skel/.config/lingmoos/dock.conf
[General]
Visibility=2
DOCK_CONF
cp -f /etc/skel/.config/lingmoos/dock.conf /etc/skel/.config/cutefishos/dock.conf 2>/dev/null || true

# Configurar KWin por defecto con animacion Magic Lamp
mkdir -p /etc/xdg
cat << 'KWIN_PLUGINS' >> /etc/xdg/kwinrc
[Plugins]
magiclampEnabled=true
lingmo_squashEnabled=false
KWIN_PLUGINS

mkdir -p /etc/skel/.config
cat << 'KWIN_USER' >> /etc/skel/.config/kwinrc
[Plugins]
magiclampEnabled=true
lingmo_squashEnabled=false
KWIN_USER

cat << 'KCM_CONF' > /etc/skel/.config/kcminputrc
[Touchpad]
tapToClick=true
naturalScroll=true
KCM_CONF

for u_home in /home/* /root; do
    if [ -d "$u_home" ]; then
        mkdir -p "$u_home/.config/lingmoos" "$u_home/.config/cutefishos"
        cp -f /etc/skel/.config/lingmoos/touchpad.conf "$u_home/.config/lingmoos/touchpad.conf" 2>/dev/null || true
        cp -f /etc/skel/.config/cutefishos/touchpad.conf "$u_home/.config/cutefishos/touchpad.conf" 2>/dev/null || true
        cp -f /etc/skel/.config/lingmoos/dock.conf "$u_home/.config/lingmoos/dock.conf" 2>/dev/null || true
        cp -f /etc/skel/.config/cutefishos/dock.conf "$u_home/.config/cutefishos/dock.conf" 2>/dev/null || true
        mkdir -p "$u_home/.config"
        cp -f /etc/skel/.config/kcminputrc "$u_home/.config/kcminputrc" 2>/dev/null || true
        cp -f /etc/skel/.config/kwinrc "$u_home/.config/kwinrc" 2>/dev/null || true
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
        prop_nat=$(xinput list-props "$id" 2>/dev/null | grep -i "Natural Scrolling Enabled (" | head -n1 | grep -o -E '[0-9]+' | head -n1)
        if [ -n "$prop_nat" ]; then
            xinput set-prop "$id" "$prop_nat" 1 2>/dev/null || true
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
#include <fcntl.h>
#include <sys/file.h>
#include <sys/time.h>
#include <X11/Xlib.h>
#include <X11/keysym.h>
#include <X11/extensions/record.h>

static int super_pressed = 0;
static int other_key_pressed = 0;
static KeyCode code_super_l = 133;
static KeyCode code_super_r = 134;
static struct timeval last_trigger = {0, 0};

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
                    struct timeval now;
                    gettimeofday(&now, NULL);
                    long elapsed_ms = (now.tv_sec - last_trigger.tv_sec) * 1000 + (now.tv_usec - last_trigger.tv_usec) / 1000;
                    
                    // Debounce de 380ms para evitar dobles conmutaciones o trabas
                    if (elapsed_ms > 380) {
                        last_trigger = now;
                        pid_t pid = fork();
                        if (pid == 0) {
                            setsid();
                            system("sh -c 'which lingmo-launcher >/dev/null 2>&1 && lingmo-launcher || which cutefish-launcher >/dev/null 2>&1 && cutefish-launcher' >/dev/null 2>&1 &");
                            exit(0);
                        }
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
    // Garantizar instancia única con bloqueo de archivo
    int lock_fd = open("/tmp/superkey-launcher.lock", O_CREAT | O_RDWR, 0666);
    if (lock_fd < 0 || flock(lock_fd, LOCK_EX | LOCK_NB) != 0) {
        return 0; // Ya existe una instancia activa
    }

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

# Único inicio automático por Desktop Entry oficial (evita doble ejecución en Xsession)
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
rm -f /etc/X11/Xsession.d/92superkey-launcher || true

echo "=== [6/6] Reparando Deteccion de Discos NVMe / SATA / RST en Calamares Installer ==="
# 1. Instalar utilidades esenciales de almacenamiento y detección de particiones
apt-get install -y --no-install-recommends \
  nvme-cli mdadm libblockdev-nvme2 smartmontools parted gparted kpmcore ntfs-3g dosfstools btrfs-progs e2fsprogs fdisk dpkg-dev || true

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

# Configurar Polkit/pkexec para permitir ejecucion directa de Calamares y administracion de discos
mkdir -p /etc/polkit-1/localauthority/50-local.d
cat << 'POLKIT_CALAMARES' > /etc/polkit-1/localauthority/50-local.d/calamares.pkla
[Allow calamares and storage for all]
Identity=unix-user:*
Action=com.github.calamares.calamares;org.freedesktop.policykit.exec;org.freedesktop.udisks2.*
ResultAny=yes
ResultInactive=yes
ResultActive=yes
POLKIT_CALAMARES

mkdir -p /usr/share/polkit-1/rules.d
cat << 'POLKIT_RULES' > /usr/share/polkit-1/rules.d/90-calamares.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" || action.id.indexOf("calamares") !== -1 || action.id.indexOf("udisks2") !== -1) {
        return polkit.Result.YES;
    }
});
POLKIT_RULES

# Agregar usuario lingmo a los grupos de administracion de discos
usermod -aG sudo,disk,storage lingmo 2>/dev/null || true

# 4. Modificar lanzadores desktop e installer wrappers para ejecutar con permisos completos
find /usr/share/applications /etc/xdg/autostart /etc/skel/.config/autostart /home/*/.config/autostart /home/*/Desktop \
  -type f \( -name "*calamares*.desktop" -o -name "*lingmo-installer*.desktop" \) 2>/dev/null \
  -exec sed -i 's/^Exec=.*/Exec=sudo -E \/usr\/bin\/calamares/g' {} + || true

# Sobrescribir wrapper lingmo-installer-config para arrancar directo como root
cat << 'LINGMO_INSTALLER_WRAPPER' > /usr/bin/lingmo-installer-config
#!/bin/bash
sudo mv /etc/fstab /etc/fstab.orig.calamares 2>/dev/null || true
modprobe nvme 2>/dev/null || true
modprobe nvme_core 2>/dev/null || true
modprobe vmd 2>/dev/null || true
modprobe ahci 2>/dev/null || true
modprobe sd_mod 2>/dev/null || true
modprobe dm_mod 2>/dev/null || true
partprobe 2>/dev/null || true
xhost +local:root >/dev/null 2>&1 || true
xhost +local:lingmo >/dev/null 2>&1 || true
xhost +local: >/dev/null 2>&1 || true
export QT_AUTO_SCREEN_SCALE_FACTOR=1
exec sudo -E /usr/bin/calamares "$@"
LINGMO_INSTALLER_WRAPPER
chmod +x /usr/bin/lingmo-installer-config || true

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

# 6. Desactivar COMPLETAMENTE cualquier bloqueo de requerimientos en Calamares
SAFE_WELCOME_CONTENT="---
showSupportUrl: false
showKnownIssuesUrl: false
showReleaseNotesUrl: false

check: []
required: []

requirements:
    requiredStorage: 0
    requiredRam: 0
    check: []
    required: []
"

# Sobrescribir todos los archivos welcome.conf en el sistema
find / -name "*welcome*.conf" 2>/dev/null | while read -r wfile; do
    echo "$SAFE_WELCOME_CONTENT" > "$wfile"
    echo "welcome.conf blindado: $wfile"
done

for w_dir in /etc/calamares/modules /usr/share/calamares/modules /etc/calamares; do
    mkdir -p "$w_dir"
    echo "$SAFE_WELCOME_CONTENT" > "$w_dir/welcome.conf"
done

# Habilitar particionado manual en partition.conf
find / -name "*partition*.conf" 2>/dev/null | while read -r pfile; do
    sed -i 's/allowManualPartitioning:.*/allowManualPartitioning: true/g' "$pfile" || true
    sed -i 's/enableLuks:.*/enableLuks: false/g' "$pfile" || true
    sed -i 's/drawExistingPartitionTable:.*/drawExistingPartitionTable: true/g' "$pfile" || true
    echo "partition.conf blindado: $pfile"
done

# Habilitar botón Cancelar y flujo limpio en settings.conf
find / -name "*settings*.conf" 2>/dev/null | grep -i calamares | while read -r sfile; do
    sed -i 's/disable-cancel:.*/disable-cancel: false/g' "$sfile" || true
    sed -i 's/disable-cancel-during-exec:.*/disable-cancel-during-exec: false/g' "$sfile" || true
    echo "settings.conf blindado: $sfile"
done

# 7. Configurar valores por defecto de la barra superior (Auto: sincronizada con modo oscuro)
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

# 8. Pre-integrar repositorio local y APT Pinning para que 'apt-get install spotify-client' funcione directamente con los comandos oficiales
mkdir -p /var/lib/lingmo-repo
cd /var/lib/lingmo-repo
SPOTIFY_PKG="spotify-client_1.2.74.477.g00424584_amd64.deb"
wget -q -O "$SPOTIFY_PKG" "https://archive.org/download/spotify-client-1.2.74.477/$SPOTIFY_PKG" || \
wget -q -O "$SPOTIFY_PKG" "https://raw.githubusercontent.com/hetzelltellez/lingmo-os-cutefish/master/$SPOTIFY_PKG" || true

if [ -f "$SPOTIFY_PKG" ] && [ -s "$SPOTIFY_PKG" ]; then
    dpkg-scanpackages . /dev/null 2>/dev/null | gzip -9c > Packages.gz || true
    
    # Agregar repo local a sources.list.d
    echo "deb [trusted=yes] file:/var/lib/lingmo-repo ./" > /etc/apt/sources.list.d/lingmo-local.list
    
    # Fijar prioridad 1001 para que 'apt install spotify-client' use siempre esta version compatible y no falle por GLIBC
    mkdir -p /etc/apt/preferences.d
    cat << 'SPOTIFY_PIN' > /etc/apt/preferences.d/spotify
Package: spotify-client
Pin: version 1:1.2.74*
Pin-Priority: 1001
SPOTIFY_PIN
fi
cd /

# 9. Mantener también script helper /usr/local/bin/instalar-spotify
cat << 'SPOTIFY_SH' > /usr/local/bin/instalar-spotify
#!/bin/bash
set -e
echo "=========================================================="
echo "    Instalador Oficial de Spotify (.deb para Debian 12)   "
echo "=========================================================="
if [ -f "/var/lib/lingmo-repo/spotify-client_1.2.74.477.g00424584_amd64.deb" ]; then
    apt-get install -y /var/lib/lingmo-repo/spotify-client_1.2.74.477.g00424584_amd64.deb || true
else
    apt-get update && apt-get install -y spotify-client || true
fi
apt-mark hold spotify-client 2>/dev/null || true
echo "Listo! Spotify instalado."
SPOTIFY_SH
chmod +x /usr/local/bin/instalar-spotify

rm -rf /tmp/lingmo-statusbar /tmp/lingmo-settings
apt-get clean
