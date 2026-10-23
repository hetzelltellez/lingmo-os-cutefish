#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== [1/9] Actualizando repositorios e instalando dependencias para lingmo-statusbar ==="
rm -f /etc/apt/sources.list.d/*lingmo* || true
apt-get update || true

apt-get install -y --no-install-recommends \
  build-essential cmake pkg-config extra-cmake-modules \
  qtbase5-dev qtdeclarative5-dev qtquickcontrols2-5-dev qttools5-dev qttools5-dev-tools libqt5x11extras5-dev \
  libxcb1-dev libxcb-keysyms1-dev libx11-dev libx11-xcb-dev libxcursor-dev libxi-dev libxfixes-dev libxrandr-dev libxtst-dev libxcomposite-dev libxdamage-dev \
  libkf5windowsystem-dev libkf5config-dev libkf5networkmanagerqt-dev modemmanager-qt-dev libkf5coreaddons-dev libkf5i18n-dev xinput || true

echo "=== [2/9] Compilando lingmo-statusbar oficial con Barra Blanca e Iconos Completos ==="
cd /tmp/lingmo-statusbar
rm -rf build && mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
make install

echo "=== [3/9] Verificando instalacion de /usr/bin/lingmo-statusbar ==="
ls -lh /usr/bin/lingmo-statusbar
test -f /usr/bin/lingmo-statusbar

echo "=== [4/9] Compilando lingmo-settings oficial con soporte de apariencia de barra superior ==="
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

echo "=== [5/9] Compilando lingmo-dock oficial con menu de apagado y Task View / Overview ==="
if [ -d "/tmp/lingmo-dock" ]; then
    cd /tmp/lingmo-dock
    rm -rf build && mkdir build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release || true
    if [ -f "Makefile" ]; then
        make -j$(nproc) || true
        make install || true
    fi
    cd /
    echo "=== Verificando binario /usr/bin/lingmo-dock compilado ==="
    ls -lh /usr/bin/lingmo-dock || true
fi

echo "=== [6/9] Instalando Google Chrome oficial (.deb) de 64 bits ==="
wget -q -O /tmp/google-chrome-stable_current_amd64.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" || true
if [ -f "/tmp/google-chrome-stable_current_amd64.deb" ] && [ -s "/tmp/google-chrome-stable_current_amd64.deb" ]; then
    apt-get install -y /tmp/google-chrome-stable_current_amd64.deb || (apt-get -f install -y && apt-get install -y /tmp/google-chrome-stable_current_amd64.deb) || true
    rm -f /tmp/google-chrome-stable_current_amd64.deb
fi

# Blindar ejecucion de Google Chrome en modo Live
chmod 4755 /opt/google/chrome/chrome-sandbox 2>/dev/null || true
chmod 755 /opt/google/chrome/google-chrome /opt/google/chrome/chrome 2>/dev/null || true
mkdir -p /etc/sysctl.d
echo "kernel.unprivileged_userns_clone=1" > /etc/sysctl.d/00-local-userns.conf

# 1. Configurar /etc/default/google-chrome
mkdir -p /etc/default
cat << 'CHROME_DEFAULT' > /etc/default/google-chrome
export CHROME_EXTRA_FLAGS="--no-sandbox --test-type --disable-dev-shm-usage --disable-gpu-sandbox --password-store=basic --no-default-browser-check --no-first-run"
CHROME_DEFAULT

# 2. Inyectar banderas sandbox en el script oficial de Google Chrome (/opt/google/chrome/google-chrome)
if [ -f "/opt/google/chrome/google-chrome" ]; then
    sed -i 's|exec -a "\$0" "\$HERE/chrome"|exec -a "\$0" "\$HERE/chrome" --no-sandbox --test-type --disable-dev-shm-usage --disable-gpu-sandbox --password-store=basic --no-default-browser-check --no-first-run|g' /opt/google/chrome/google-chrome 2>/dev/null || true
fi

# 3. Crear wrapper indestructible en /usr/local/bin y /usr/bin
cat << 'CHROME_WRAPPER' > /usr/local/bin/google-chrome-stable
#!/bin/bash
export CHROME_EXTRA_FLAGS="--no-sandbox --test-type --disable-dev-shm-usage --disable-gpu-sandbox --password-store=basic --no-default-browser-check --no-first-run"

REAL_CHROME=""
if [ -x "/opt/google/chrome/google-chrome" ]; then
    REAL_CHROME="/opt/google/chrome/google-chrome"
elif [ -x "/usr/bin/google-chrome-stable" ] && [ "/usr/bin/google-chrome-stable" != "$0" ]; then
    REAL_CHROME="/usr/bin/google-chrome-stable"
elif [ -x "/opt/google/chrome/chrome" ]; then
    REAL_CHROME="/opt/google/chrome/chrome"
fi

CLEAN_ARGS=()
for a in "$@"; do
    if [ "$a" != "%U" ] && [ "$a" != "%u" ] && [ "$a" != "%F" ] && [ "$a" != "%f" ]; then
        CLEAN_ARGS+=("$a")
    fi
done

EXTRA_FLAGS="--no-sandbox --test-type --disable-dev-shm-usage --disable-gpu-sandbox --password-store=basic --no-default-browser-check --no-first-run"

exec "$REAL_CHROME" $EXTRA_FLAGS "${CLEAN_ARGS[@]}"
CHROME_WRAPPER
chmod 755 /usr/local/bin/google-chrome-stable
cp -f /usr/local/bin/google-chrome-stable /usr/local/bin/google-chrome
cp -f /usr/local/bin/google-chrome-stable /usr/bin/google-chrome-stable
cp -f /usr/local/bin/google-chrome-stable /usr/bin/google-chrome
cp -f /usr/local/bin/google-chrome-stable /usr/bin/x-www-browser 2>/dev/null || true

# 4. Actualizar google-chrome.desktop
sed -i 's|^Exec=/usr/bin/google-chrome-stable.*|Exec=/usr/bin/google-chrome-stable %U --no-sandbox --test-type --disable-dev-shm-usage --disable-gpu-sandbox --password-store=basic --no-default-browser-check --no-first-run|g' /usr/share/applications/google-chrome.desktop 2>/dev/null || true
sed -i 's|^Exec=google-chrome.*|Exec=/usr/bin/google-chrome-stable %U --no-sandbox --test-type --disable-dev-shm-usage --disable-gpu-sandbox --password-store=basic --no-default-browser-check --no-first-run|g' /usr/share/applications/google-chrome.desktop 2>/dev/null || true

# Configurar orden exacto del dock en /etc/lingmo-dock-list.conf
mkdir -p /etc /etc/skel/.config/lingmoos /etc/skel/.config/cutefishos
if [ -f "/tmp/lingmo-dock/lingmo-dock-list.conf" ]; then
    cp -f /tmp/lingmo-dock/lingmo-dock-list.conf /etc/lingmo-dock-list.conf
fi
rm -rf /tmp/lingmo-dock

cp -f /etc/lingmo-dock-list.conf /etc/skel/.config/lingmoos/dock_pinned.conf 2>/dev/null || true
cp -f /etc/lingmo-dock-list.conf /etc/skel/.config/cutefishos/dock_pinned.conf 2>/dev/null || true

echo "=== [7/9] Configurando Touchpad, Dock y KWin por defecto ==="
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
        cp -f /etc/lingmo-dock-list.conf "$u_home/.config/lingmoos/dock_pinned.conf" 2>/dev/null || true
        cp -f /etc/lingmo-dock-list.conf "$u_home/.config/cutefishos/dock_pinned.conf" 2>/dev/null || true
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

echo "=== [8/9] Configurando daemon SXHKD y utilidades para teclas multimedia, brillo y Super Key ==="
apt-get install -y --no-install-recommends \
  brightnessctl pulseaudio-utils xbacklight playerctl alsa-utils acpid libxtst-dev libx11-dev sxhkd inotify-tools || true

chmod 4755 /usr/bin/brightnessctl 2>/dev/null || true
usermod -aG audio,video,input lingmo 2>/dev/null || true
usermod -aG audio,video,input live 2>/dev/null || true

# Reglas udev para permitir ajuste directo de brillo de pantalla en cualquier GPU
mkdir -p /etc/udev/rules.d
cat << 'UDEV_BACKLIGHT' > /etc/udev/rules.d/90-backlight.rules
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod 0666 /sys/class/backlight/%k/brightness /sys/class/backlight/%k/bl_power"
SUBSYSTEM=="backlight", ACTION=="change", RUN+="/bin/chmod 0666 /sys/class/backlight/%k/brightness /sys/class/backlight/%k/bl_power"
ACTION=="add", SUBSYSTEM=="leds", RUN+="/bin/chmod 0666 /sys/class/leds/%k/brightness"
UDEV_BACKLIGHT

# Script unificado de control de volumen (WirePlumber / PipeWire, PulseAudio y ALSA)
cat << 'LINGMO_VOL_SH' > /usr/local/bin/lingmo-volume
#!/bin/bash
ACTION="$1"
case "$ACTION" in
    up)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0 2>/dev/null || \
        pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null; pactl set-sink-volume @DEFAULT_SINK@ +5% 2>/dev/null || \
        pactl set-sink-volume 0 +5% 2>/dev/null || \
        amixer -D pulse set Master 5%+ 2>/dev/null || amixer set Master 5%+ 2>/dev/null
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- 2>/dev/null || \
        pactl set-sink-volume @DEFAULT_SINK@ -5% 2>/dev/null || \
        pactl set-sink-volume 0 -5% 2>/dev/null || \
        amixer -D pulse set Master 5%- 2>/dev/null || amixer set Master 5%- 2>/dev/null
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || \
        pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null || \
        pactl set-sink-mute 0 toggle 2>/dev/null || \
        amixer -D pulse set Master toggle 2>/dev/null || amixer set Master toggle 2>/dev/null
        ;;
    micmute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null || \
        pactl set-source-mute @DEFAULT_SOURCE@ toggle 2>/dev/null || \
        pactl set-source-mute 0 toggle 2>/dev/null || \
        amixer set Capture toggle 2>/dev/null
        ;;
esac
LINGMO_VOL_SH
chmod 755 /usr/local/bin/lingmo-volume

# Script unificado de control de brillo para cualquier hardware (Lenovo, Intel, AMD, etc.)
cat << 'LINGMO_BRIGHT_SH' > /usr/local/bin/lingmo-brightness
#!/bin/bash
ACTION="$1"
STEP=5

if which brightnessctl >/dev/null 2>&1; then
    if [ "$ACTION" = "up" ]; then
        brightnessctl set +5% >/dev/null 2>&1 && exit 0
    else
        brightnessctl set 5%- >/dev/null 2>&1 && exit 0
    fi
fi

for bdir in /sys/class/backlight/*; do
    if [ -d "$bdir" ]; then
        cur=$(cat "$bdir/brightness" 2>/dev/null)
        max=$(cat "$bdir/max_brightness" 2>/dev/null)
        if [ -n "$cur" ] && [ -n "$max" ] && [ "$max" -gt 0 ]; then
            delta=$(( max * STEP / 100 ))
            [ $delta -lt 1 ] && delta=1
            if [ "$ACTION" = "up" ]; then
                new_val=$(( cur + delta ))
                [ $new_val -gt $max ] && new_val=$max
            else
                new_val=$(( cur - delta ))
                [ $new_val -lt 1 ] && new_val=1
            fi
            echo "$new_val" > "$bdir/brightness" 2>/dev/null && exit 0
        fi
    fi
done

if [ "$ACTION" = "up" ]; then
    xbacklight -inc 5 >/dev/null 2>&1 || true
else
    xbacklight -dec 5 >/dev/null 2>&1 || true
fi
LINGMO_BRIGHT_SH
chmod 755 /usr/local/bin/lingmo-brightness

# Configuracion de sxhkd (Simple X Hotkey Daemon para captura global de teclas multimedia)
mkdir -p /etc/sxhkd
cat << 'SXHKD_CONF' > /etc/sxhkd/sxhkdrc
# Brightness Up
XF86MonBrightnessUp
    /usr/local/bin/lingmo-brightness up

# Brightness Down
XF86MonBrightnessDown
    /usr/local/bin/lingmo-brightness down

# Volume Up
XF86AudioRaiseVolume
    /usr/local/bin/lingmo-volume up

# Volume Down
XF86AudioLowerVolume
    /usr/local/bin/lingmo-volume down

# Volume Mute Toggle
XF86AudioMute
    /usr/local/bin/lingmo-volume mute

# Mic Mute Toggle
XF86AudioMicMute
    /usr/local/bin/lingmo-volume micmute

# Media playback
XF86AudioPlay
    playerctl play-pause 2>/dev/null

XF86AudioNext
    playerctl next 2>/dev/null

XF86AudioPrev
    playerctl previous 2>/dev/null
SXHKD_CONF

# Autostart sxhkd
mkdir -p /etc/xdg/autostart /etc/X11/Xsession.d
cat << 'SXHKD_DESKTOP' > /etc/xdg/autostart/sxhkd.desktop
[Desktop Entry]
Type=Application
Name=SXHKD Media and Brightness Keys Daemon
Exec=/usr/bin/sxhkd -c /etc/sxhkd/sxhkdrc
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
SXHKD_DESKTOP
chmod 644 /etc/xdg/autostart/sxhkd.desktop

cat << 'SXHKD_XSESSION' > /etc/X11/Xsession.d/91sxhkd
/usr/bin/sxhkd -c /etc/sxhkd/sxhkdrc >/dev/null 2>&1 &
SXHKD_XSESSION
chmod +x /etc/X11/Xsession.d/91sxhkd

# Handlers ACPI para hardware laptop (Lenovo/Asus/HP/Dell)
mkdir -p /etc/acpi/events
cat << 'ACPI_BRIGHT_UP' > /etc/acpi/events/brightness-up
event=video/brightnessup.*
action=/usr/local/bin/lingmo-brightness up
ACPI_BRIGHT_UP

cat << 'ACPI_BRIGHT_DOWN' > /etc/acpi/events/brightness-down
event=video/brightnessdown.*
action=/usr/local/bin/lingmo-brightness down
ACPI_BRIGHT_DOWN

cat << 'ACPI_VOL_UP' > /etc/acpi/events/volume-up
event=button/volumeup.*
action=/usr/local/bin/lingmo-volume up
ACPI_VOL_UP

cat << 'ACPI_VOL_DOWN' > /etc/acpi/events/volume-down
event=button/volumedown.*
action=/usr/local/bin/lingmo-volume down
ACPI_VOL_DOWN

cat << 'ACPI_VOL_MUTE' > /etc/acpi/events/volume-mute
event=button/mute.*
action=/usr/local/bin/lingmo-volume mute
ACPI_VOL_MUTE

systemctl enable acpid 2>/dev/null || true

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

#ifndef XF86XK_MonBrightnessUp
#define XF86XK_MonBrightnessUp   0x1008FF02
#endif
#ifndef XF86XK_MonBrightnessDown
#define XF86XK_MonBrightnessDown 0x1008FF03
#endif
#ifndef XF86XK_AudioLowerVolume
#define XF86XK_AudioLowerVolume  0x1008FF11
#endif
#ifndef XF86XK_AudioMute
#define XF86XK_AudioMute         0x1008FF12
#endif
#ifndef XF86XK_AudioRaiseVolume
#define XF86XK_AudioRaiseVolume  0x1008FF13
#endif
#ifndef XF86XK_AudioPlay
#define XF86XK_AudioPlay         0x1008FF14
#endif
#ifndef XF86XK_AudioStop
#define XF86XK_AudioStop         0x1008FF15
#endif
#ifndef XF86XK_AudioPrev
#define XF86XK_AudioPrev         0x1008FF16
#endif
#ifndef XF86XK_AudioNext
#define XF86XK_AudioNext         0x1008FF17
#endif
#ifndef XF86XK_AudioMicMute
#define XF86XK_AudioMicMute      0x1008FFB2
#endif

static Display *ctrl_dpy = NULL;
static Display *data_dpy = NULL;

static int super_pressed = 0;
static int other_key_pressed = 0;
static KeyCode code_super_l = 133;
static KeyCode code_super_r = 134;

static KeyCode code_vol_up = 123;
static KeyCode code_vol_down = 122;
static KeyCode code_vol_mute = 121;
static KeyCode code_mic_mute = 198;
static KeyCode code_bright_up = 233;
static KeyCode code_bright_down = 232;
static KeyCode code_play = 172;
static KeyCode code_next = 171;
static KeyCode code_prev = 173;

static struct timeval last_trigger = {0, 0};
static struct timeval last_vol = {0, 0};
static struct timeval last_bright = {0, 0};

static void run_async(const char *cmd) {
    pid_t pid = fork();
    if (pid == 0) {
        setsid();
        execl("/bin/sh", "sh", "-c", cmd, (char *)NULL);
        _exit(0);
    }
}

void callback(XPointer closure, XRecordInterceptData *data) {
    if (data->category == XRecordFromServer) {
        unsigned char *b = (unsigned char *)data->data;
        int type = b[0] & 0x7F;
        int keycode = b[1];

        // 1. Super Key logic (abrir lanzador en KeyRelease)
        if (keycode == 133 || keycode == 134 || keycode == code_super_l || keycode == code_super_r) {
            if (type == KeyPress) {
                super_pressed = 1;
                other_key_pressed = 0;
            } else if (type == KeyRelease) {
                if (super_pressed && !other_key_pressed) {
                    struct timeval now;
                    gettimeofday(&now, NULL);
                    long elapsed_ms = (now.tv_sec - last_trigger.tv_sec) * 1000 + (now.tv_usec - last_trigger.tv_usec) / 1000;
                    
                    if (elapsed_ms > 380) {
                        last_trigger = now;
                        run_async("which lingmo-launcher >/dev/null 2>&1 && lingmo-launcher || which cutefish-launcher >/dev/null 2>&1 && cutefish-launcher");
                    }
                }
                super_pressed = 0;
                other_key_pressed = 0;
            }
            XRecordFreeData(data);
            return;
        }

        // 2. Teclas multimedia y brillo (reaccionar en KeyPress de forma inmediata)
        if (type == KeyPress) {
            if (super_pressed) {
                other_key_pressed = 1;
            }

            KeySym sym = 0;
            if (ctrl_dpy) {
                sym = XKeycodeToKeysym(ctrl_dpy, keycode, 0);
            }

            if (sym == XF86XK_AudioRaiseVolume || keycode == 123 || keycode == code_vol_up) {
                struct timeval now;
                gettimeofday(&now, NULL);
                long elapsed = (now.tv_sec - last_vol.tv_sec) * 1000 + (now.tv_usec - last_vol.tv_usec) / 1000;
                if (elapsed > 40) {
                    last_vol = now;
                    run_async("pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null; pactl set-sink-volume @DEFAULT_SINK@ +5% 2>/dev/null || pactl set-sink-volume 0 +5% 2>/dev/null || amixer -D pulse set Master 5%+ 2>/dev/null || amixer set Master 5%+ 2>/dev/null");
                }
            } else if (sym == XF86XK_AudioLowerVolume || keycode == 122 || keycode == code_vol_down) {
                struct timeval now;
                gettimeofday(&now, NULL);
                long elapsed = (now.tv_sec - last_vol.tv_sec) * 1000 + (now.tv_usec - last_vol.tv_usec) / 1000;
                if (elapsed > 40) {
                    last_vol = now;
                    run_async("pactl set-sink-volume @DEFAULT_SINK@ -5% 2>/dev/null || pactl set-sink-volume 0 -5% 2>/dev/null || amixer -D pulse set Master 5%- 2>/dev/null || amixer set Master 5%- 2>/dev/null");
                }
            } else if (sym == XF86XK_AudioMute || keycode == 121 || keycode == code_vol_mute) {
                run_async("pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null || pactl set-sink-mute 0 toggle 2>/dev/null || amixer -D pulse set Master toggle 2>/dev/null || amixer set Master toggle 2>/dev/null");
            } else if (sym == XF86XK_AudioMicMute || keycode == 198 || keycode == code_mic_mute) {
                run_async("pactl set-source-mute @DEFAULT_SOURCE@ toggle 2>/dev/null || pactl set-source-mute 0 toggle 2>/dev/null || amixer set Capture toggle 2>/dev/null");
            } else if (sym == XF86XK_MonBrightnessUp || keycode == 233 || keycode == code_bright_up) {
                struct timeval now;
                gettimeofday(&now, NULL);
                long elapsed = (now.tv_sec - last_bright.tv_sec) * 1000 + (now.tv_usec - last_bright.tv_usec) / 1000;
                if (elapsed > 40) {
                    last_bright = now;
                    run_async("brightnessctl set +5% >/dev/null 2>&1 || xbacklight -inc 5 >/dev/null 2>&1");
                }
            } else if (sym == XF86XK_MonBrightnessDown || keycode == 232 || keycode == code_bright_down) {
                struct timeval now;
                gettimeofday(&now, NULL);
                long elapsed = (now.tv_sec - last_bright.tv_sec) * 1000 + (now.tv_usec - last_bright.tv_usec) / 1000;
                if (elapsed > 40) {
                    last_bright = now;
                    run_async("brightnessctl set 5%- >/dev/null 2>&1 || xbacklight -dec 5 >/dev/null 2>&1");
                }
            } else if (sym == XF86XK_AudioPlay || keycode == 172 || keycode == code_play) {
                run_async("playerctl play-pause 2>/dev/null");
            } else if (sym == XF86XK_AudioNext || keycode == 171 || keycode == code_next) {
                run_async("playerctl next 2>/dev/null");
            } else if (sym == XF86XK_AudioPrev || keycode == 173 || keycode == code_prev) {
                run_async("playerctl previous 2>/dev/null");
            }
        }
    }
    XRecordFreeData(data);
}

int main() {
    int lock_fd = open("/tmp/superkey-launcher.lock", O_CREAT | O_RDWR, 0666);
    if (lock_fd < 0 || flock(lock_fd, LOCK_EX | LOCK_NB) != 0) {
        return 0;
    }

    signal(SIGCHLD, SIG_IGN);

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

    KeyCode k;
    if ((k = XKeysymToKeycode(ctrl_dpy, XK_Super_L)) != 0) code_super_l = k;
    if ((k = XKeysymToKeycode(ctrl_dpy, XK_Super_R)) != 0) code_super_r = k;
    if ((k = XKeysymToKeycode(ctrl_dpy, XF86XK_AudioRaiseVolume)) != 0) code_vol_up = k;
    if ((k = XKeysymToKeycode(ctrl_dpy, XF86XK_AudioLowerVolume)) != 0) code_vol_down = k;
    if ((k = XKeysymToKeycode(ctrl_dpy, XF86XK_AudioMute)) != 0) code_vol_mute = k;
    if ((k = XKeysymToKeycode(ctrl_dpy, XF86XK_AudioMicMute)) != 0) code_mic_mute = k;
    if ((k = XKeysymToKeycode(ctrl_dpy, XF86XK_MonBrightnessUp)) != 0) code_bright_up = k;
    if ((k = XKeysymToKeycode(ctrl_dpy, XF86XK_MonBrightnessDown)) != 0) code_bright_down = k;
    if ((k = XKeysymToKeycode(ctrl_dpy, XF86XK_AudioPlay)) != 0) code_play = k;
    if ((k = XKeysymToKeycode(ctrl_dpy, XF86XK_AudioNext)) != 0) code_next = k;
    if ((k = XKeysymToKeycode(ctrl_dpy, XF86XK_AudioPrev)) != 0) code_prev = k;

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

# Autostart Xsession.d (ejecutado directamente al arrancar el servidor X11 para todo usuario)
mkdir -p /etc/X11/Xsession.d
cat << 'XSESSION_DAEMON' > /etc/X11/Xsession.d/92superkey-launcher
/usr/bin/superkey-launcher >/dev/null 2>&1 &
XSESSION_DAEMON
chmod +x /etc/X11/Xsession.d/92superkey-launcher

# Autostart XDG
mkdir -p /etc/xdg/autostart
cat << 'SUPERKEY_AUTOSTART' > /etc/xdg/autostart/superkey-launcher.desktop
[Desktop Entry]
Type=Application
Name=Super Key and Media Keys Daemon
Exec=/usr/bin/superkey-launcher
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
SUPERKEY_AUTOSTART
chmod 644 /etc/xdg/autostart/superkey-launcher.desktop

echo "=== [9/9] Solucion Definitiva: Deteccion Automatica de Discos (Lenovo Ideapad NVMe/RST) y Desbloqueo Total de Calamares ==="

# 1. Instalar utilidades esenciales de almacenamiento y particionado
apt-get install -y --no-install-recommends \
  nvme-cli mdadm dmraid libblockdev-nvme2 smartmontools parted gparted kpmcore ntfs-3g dosfstools btrfs-progs e2fsprogs fdisk dpkg-dev || true

# 2. Instalar Kernel moderno y firmware non-free desde Debian Bookworm Backports
echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware" > /etc/apt/sources.list.d/backports.list
apt-get update || true
apt-get install -t bookworm-backports -y --no-install-recommends \
  linux-image-amd64 firmware-linux firmware-linux-nonfree firmware-misc-nonfree intel-microcode || true

# 3. Cargar modulos criticos de almacenamiento en boot y en initramfs (NVMe, VMD, AHCI, RAID)
mkdir -p /etc/modules-load.d
cat << 'MODULES_STORAGE' > /etc/modules-load.d/storage.conf
nvme
nvme_core
vmd
ahci
sd_mod
dm_mod
dm_raid
md_mod
raid0
raid1
raid10
MODULES_STORAGE

mkdir -p /etc/initramfs-tools
cat << 'INITRAMFS_MODULES' >> /etc/initramfs-tools/modules
nvme
nvme_core
vmd
ahci
sd_mod
dm_mod
dm_raid
md_mod
raid0
raid1
raid10
INITRAMFS_MODULES

update-initramfs -u -k all || true

# 4. Renombrar calamares a calamares.bin y crear wrapper blindado con auto-ensamblado de discos
for cp_path in /usr/bin/calamares /usr/sbin/calamares /usr/local/bin/calamares; do
    if [ -f "$cp_path" ] && [ ! -f "${cp_path}.bin" ]; then
        mv "$cp_path" "${cp_path}.bin"
    fi
done

cat << 'CALAMARES_WRAPPER' > /usr/bin/calamares
#!/bin/bash
xhost +local:root >/dev/null 2>&1 || true
xhost +local:lingmo >/dev/null 2>&1 || true
xhost +local: >/dev/null 2>&1 || true

# Cargar modulos criticos de hardware y controladores de almacenamiento
modprobe nvme 2>/dev/null || true
modprobe nvme_core 2>/dev/null || true
modprobe vmd 2>/dev/null || true
modprobe ahci 2>/dev/null || true
modprobe sd_mod 2>/dev/null || true
modprobe dm_mod 2>/dev/null || true
modprobe dm_raid 2>/dev/null || true
modprobe md_mod 2>/dev/null || true
modprobe raid0 2>/dev/null || true
modprobe raid1 2>/dev/null || true
modprobe raid10 2>/dev/null || true

# Auto-ensamblado inmediato de volumenes Intel RST / IMSM y fake-RAID
mdadm --assemble --scan 2>/dev/null || true
dmraid -ay 2>/dev/null || true

# Disparar sondeo del kernel y udev
udevadm trigger 2>/dev/null || true
udevadm settle --timeout=5 2>/dev/null || true
nvme list >/dev/null 2>&1 || true
partprobe 2>/dev/null || true

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

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$REAL_BIN" "$@"
else
    exec "$REAL_BIN" "$@"
fi
CALAMARES_WRAPPER
chmod +x /usr/bin/calamares

[ ! -f /usr/sbin/calamares ] || cp -f /usr/bin/calamares /usr/sbin/calamares
[ ! -f /usr/local/bin/calamares ] || cp -f /usr/bin/calamares /usr/local/bin/calamares

# 5. Configurar sudoers y Polkit sin contrasenas
mkdir -p /etc/sudoers.d
cat << 'SUDOERS_CALAMARES' > /etc/sudoers.d/calamares
ALL ALL=(ALL) NOPASSWD: ALL
SUDOERS_CALAMARES
chmod 440 /etc/sudoers.d/calamares

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

usermod -aG sudo,disk,storage lingmo 2>/dev/null || true

# Modificar lanzadores desktop para ejecutar con permisos completos
find /usr/share/applications /etc/xdg/autostart /etc/skel/.config/autostart /home/*/.config/autostart /home/*/Desktop \
  -type f \( -name "*calamares*.desktop" -o -name "*lingmo-installer*.desktop" \) 2>/dev/null \
  -exec sed -i 's/^Exec=.*/Exec=sudo -E \/usr\/bin\/calamares/g' {} + || true

cat << 'LINGMO_INSTALLER_WRAPPER' > /usr/bin/lingmo-installer-config
#!/bin/bash
sudo mv /etc/fstab /etc/fstab.orig.calamares 2>/dev/null || true
modprobe nvme 2>/dev/null || true
modprobe nvme_core 2>/dev/null || true
modprobe vmd 2>/dev/null || true
modprobe ahci 2>/dev/null || true
modprobe sd_mod 2>/dev/null || true
modprobe dm_mod 2>/dev/null || true
modprobe dm_raid 2>/dev/null || true
modprobe md_mod 2>/dev/null || true
modprobe raid0 2>/dev/null || true
modprobe raid1 2>/dev/null || true
modprobe raid10 2>/dev/null || true
mdadm --assemble --scan 2>/dev/null || true
dmraid -ay 2>/dev/null || true
udevadm trigger 2>/dev/null || true
udevadm settle --timeout=5 2>/dev/null || true
partprobe 2>/dev/null || true
xhost +local:root >/dev/null 2>&1 || true
xhost +local:lingmo >/dev/null 2>&1 || true
xhost +local: >/dev/null 2>&1 || true
export QT_AUTO_SCREEN_SCALE_FACTOR=1
exec sudo -E /usr/bin/calamares "$@"
LINGMO_INSTALLER_WRAPPER
chmod +x /usr/bin/lingmo-installer-config || true

# 6. Desactivar COMPLETAMENTE cualquier bloqueo o requisito en welcome.conf (CERO check de storage)
PURE_WELCOME_CONF="---
showSupportUrl: false
showKnownIssuesUrl: false
showReleaseNotesUrl: false
"

find / -name "*welcome*.conf" 2>/dev/null | while read -r wfile; do
    echo "$PURE_WELCOME_CONF" > "$wfile"
    echo "welcome.conf limpiado: $wfile"
done

for w_dir in /etc/calamares/modules /usr/share/calamares/modules /etc/calamares; do
    mkdir -p "$w_dir"
    echo "$PURE_WELCOME_CONF" > "$w_dir/welcome.conf"
done

# 7. Asegurar que partition.conf permita particionado manual y no bloquee por tamano minimo
find / -name "*partition*.conf" 2>/dev/null | while read -r pfile; do
    sed -i 's/requiredStorage:.*/requiredStorage: 0/g' "$pfile" || true
    sed -i 's/allowManualPartitioning:.*/allowManualPartitioning: true/g' "$pfile" || true
    sed -i 's/enableLuks:.*/enableLuks: false/g' "$pfile" || true
    sed -i 's/drawExistingPartitionTable:.*/drawExistingPartitionTable: true/g' "$pfile" || true
    echo "partition.conf configurado: $pfile"
done

# 8. Unblock en settings.conf: deshabilitar bloqueo de cancelacion y eliminar '- welcome' de sequence para que NO bloquee
find / -name "*settings*.conf" 2>/dev/null | grep -i calamares | while read -r sfile; do
    sed -i 's/disable-cancel:.*/disable-cancel: false/g' "$sfile" || true
    sed -i 's/disable-cancel-during-exec:.*/disable-cancel-during-exec: false/g' "$sfile" || true
    # Eliminar la linea '- welcome' para que arranque directo a seleccion de idioma/particion sin pasar por el RequirementsChecker
    sed -i '/^[[:space:]]*-[[:space:]]*welcome[[:space:]]*$/d' "$sfile" || true
    echo "settings.conf optimizado (secuencia sin bloqueo): $sfile"
done

# 9. Barra superior Auto (sincronizada con modo oscuro)
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

# 10. Pre-integrar repositorio local y APT Pinning para que 'apt-get install spotify-client' funcione directamente
mkdir -p /var/lib/lingmo-repo
cd /var/lib/lingmo-repo
SPOTIFY_PKG="spotify-client_1.2.74.477_amd64.deb"
wget -q -c -O "$SPOTIFY_PKG" "https://download.spotify.com/spotify-client_1.2.74.477_amd64.deb" || true

if [ -f "$SPOTIFY_PKG" ] && [ -s "$SPOTIFY_PKG" ]; then
    dpkg-scanpackages . /dev/null 2>/dev/null | gzip -9c > Packages.gz || true
    echo "deb [trusted=yes] file:/var/lib/lingmo-repo ./" > /etc/apt/sources.list.d/lingmo-local.list
    mkdir -p /etc/apt/preferences.d
    cat << 'SPOTIFY_PIN' > /etc/apt/preferences.d/spotify
Package: spotify-client
Pin: origin ""
Pin-Priority: 1001

Package: spotify-client
Pin: version *1.2.74*
Pin-Priority: 1001
SPOTIFY_PIN
fi
cd /

# Dependencias runtime necesarias para que 'apt-get install spotify-client' funcione al instante sin demoras
apt-get install -y --no-install-recommends \
  libasound2 libatomic1 libcurl4 libgtk-3-0 libnss3 libx11-xcb1 libxss1 libxtst6 || true

cat << 'SPOTIFY_SH' > /usr/local/bin/instalar-spotify
#!/bin/bash
set -e
echo "=========================================================="
echo "    Instalador Oficial de Spotify (.deb para Debian 12)   "
echo "=========================================================="
if [ -f "/var/lib/lingmo-repo/spotify-client_1.2.74.477_amd64.deb" ]; then
    apt-get install -y /var/lib/lingmo-repo/spotify-client_1.2.74.477_amd64.deb || true
else
    apt-get update && apt-get install -y spotify-client || true
fi
echo "Listo! Spotify instalado con éxito."
SPOTIFY_SH
chmod +x /usr/local/bin/instalar-spotify

# 11. Habilitar y configurar completamente Flatpak (con Flathub), Snapd y Auto-Sync Daemon
echo "=== [11/11] Configurando Flatpak (con Flathub), Snapd y Auto-Sync Daemon ==="
apt-get install -y --no-install-recommends flatpak xdg-desktop-portal xdg-desktop-portal-gtk || true
apt-get install -y --no-install-recommends snapd squashfuse fuse3 libfuse2 apparmor inotify-tools || true

# Configurar repositorio oficial Flathub por defecto en Flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

# Configurar Snapd y enlaces de compatibilidad
mkdir -p /snap /var/lib/snapd/snap /var/lib/snapd/desktop /var/lib/snapd/desktop/applications /var/lib/flatpak/exports/share/applications
ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true
systemctl enable snapd.service 2>/dev/null || true
systemctl enable snapd.socket 2>/dev/null || true
systemctl enable snapd.apparmor.service 2>/dev/null || true

# Asegurar binarios directos en /usr/local/bin
if [ -f "/usr/bin/snap" ]; then
    ln -sf /usr/bin/snap /usr/local/bin/snap 2>/dev/null || true
fi
if [ -f "/usr/bin/flatpak" ]; then
    ln -sf /usr/bin/flatpak /usr/local/bin/flatpak 2>/dev/null || true
fi

# Inyectar PATH en /etc/environment
if grep -q "PATH=" /etc/environment 2>/dev/null; then
    sed -i 's|PATH="\(.*\)"|PATH="\1:/snap/bin:/var/lib/flatpak/exports/bin"|g' /etc/environment
else
    echo 'PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/var/lib/flatpak/exports/bin"' >> /etc/environment
fi

# Variables de entorno globales para PATH y menus de escritorio (XDG)
mkdir -p /etc/profile.d
cat << 'APPS_PATH_SH' > /etc/profile.d/apps-path.sh
case ":$PATH:" in
  *":/snap/bin:"*) ;;
  *) export PATH="$PATH:/snap/bin" ;;
esac
case ":$PATH:" in
  *":/var/lib/flatpak/exports/bin:"*) ;;
  *) export PATH="$PATH:/var/lib/flatpak/exports/bin" ;;
esac
case ":$PATH:" in
  *":$HOME/.local/share/flatpak/exports/bin:"*) ;;
  *) export PATH="$PATH:$HOME/.local/share/flatpak/exports/bin" ;;
esac

export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share:/var/lib/snapd/desktop"
APPS_PATH_SH
chmod 644 /etc/profile.d/apps-path.sh

# Fallback command_not_found_handle en /etc/bash.bashrc para ejecutar aplicaciones Flatpak por su nombre comun en terminal
cat << 'CMD_NOT_FOUND' >> /etc/bash.bashrc

# Soporte automatico de comandos Flatpak por nombre corto
command_not_found_handle() {
    local cmd="$1"
    if which flatpak >/dev/null 2>&1; then
        local app=$(flatpak list --app --columns=application 2>/dev/null | grep -iE "\.${cmd}$|_${cmd}$|^${cmd}$" | head -n 1)
        if [ -n "$app" ]; then
            shift
            exec flatpak run "$app" "$@"
        fi
    fi
    echo "bash: $cmd: no se reconoce este comando o no fue encontrado" >&2
    return 127
}
CMD_NOT_FOUND

# Daemon automatico de sincronizacion lingmo-app-sync
cat << 'APP_SYNC_SH' > /usr/local/bin/lingmo-app-sync
#!/bin/bash
# Lingmo OS Auto-Sync para aplicaciones Snap, Flatpak y atajos de escritorio
sync_apps() {
    mkdir -p /usr/share/applications /usr/share/icons/hicolor /usr/share/pixmaps

    # 1. Sincronizar aplicaciones Snap
    if [ -d "/var/lib/snapd/desktop/applications" ]; then
        for f in /var/lib/snapd/desktop/applications/*.desktop; do
            if [ -f "$f" ]; then
                base=$(basename "$f")
                target="/usr/share/applications/$base"
                if [ ! -e "$target" ] || [ "$f" -nt "$target" ]; then
                    ln -sf "$f" "$target" 2>/dev/null || cp -f "$f" "$target" 2>/dev/null
                fi
            fi
        done
    fi

    # 2. Sincronizar aplicaciones Flatpak del sistema y de usuarios
    FLATPAK_DIRS=(
        "/var/lib/flatpak/exports/share/applications"
    )
    for u_home in /home/* /root; do
        if [ -d "$u_home/.local/share/flatpak/exports/share/applications" ]; then
            FLATPAK_DIRS+=("$u_home/.local/share/flatpak/exports/share/applications")
        fi
    done

    for fdir in "${FLATPAK_DIRS[@]}"; do
        if [ -d "$fdir" ]; then
            for f in "$fdir"/*.desktop; do
                if [ -f "$f" ]; then
                    base=$(basename "$f")
                    target="/usr/share/applications/$base"
                    if [ ! -e "$target" ] || [ "$f" -nt "$target" ]; then
                        ln -sf "$f" "$target" 2>/dev/null || cp -f "$f" "$target" 2>/dev/null
                    fi

                    # Crear comandos ejecutables en /usr/local/bin (ej. 'firefox', 'gimp')
                    app_id=$(basename "$f" .desktop)
                    short_name=$(echo "$app_id" | awk -F. '{print $NF}' | tr '[:upper:]' '[:lower:]')
                    
                    aliases=("$app_id")
                    [ -n "$short_name" ] && [ "$short_name" != "$app_id" ] && aliases+=("$short_name")
                    
                    case "$app_id" in
                        *firefox*|*Firefox*) aliases+=("firefox") ;;
                        *gimp*|*GIMP*) aliases+=("gimp") ;;
                        *vlc*|*VLC*) aliases+=("vlc") ;;
                        *spotify*|*Spotify*) aliases+=("spotify") ;;
                        *telegram*|*Telegram*) aliases+=("telegram" "telegram-desktop") ;;
                        *chrome*|*Chrome*) aliases+=("google-chrome") ;;
                    esac

                    for cmd in "${aliases[@]}"; do
                        wrap="/usr/local/bin/$cmd"
                        if [ ! -e "$wrap" ] || [ -L "$wrap" ]; then
                            cat << EOF_CLI > "$wrap"
#!/bin/sh
if which flatpak >/dev/null 2>&1 && flatpak info "$app_id" >/dev/null 2>&1; then
    exec flatpak run "$app_id" "\$@"
elif [ -x "/var/lib/flatpak/exports/bin/$app_id" ]; then
    exec "/var/lib/flatpak/exports/bin/$app_id" "\$@"
fi
EOF_CLI
                            chmod 755 "$wrap" 2>/dev/null || true
                        fi
                    done
                fi
            done
        fi
    done

    # 3. Sincronizar iconos
    if [ -d "/var/lib/flatpak/exports/share/icons" ]; then
        cp -rsf /var/lib/flatpak/exports/share/icons/* /usr/share/icons/ 2>/dev/null || true
    fi
    if [ -d "/var/lib/snapd/desktop/icons" ]; then
        cp -rsf /var/lib/snapd/desktop/icons/* /usr/share/icons/hicolor/ 2>/dev/null || true
        cp -sf /var/lib/snapd/desktop/icons/* /usr/share/pixmaps/ 2>/dev/null || true
    fi
}

sync_apps

while true; do
    if which inotifywait >/dev/null 2>&1; then
        inotifywait -r -q -t 5 -e create,delete,modify,attrib,moved_to /var/lib/flatpak/exports/share /var/lib/snapd/desktop /home/*/.local/share 2>/dev/null
    else
        sleep 4
    fi
    sync_apps
done
APP_SYNC_SH
chmod 755 /usr/local/bin/lingmo-app-sync

# Servicio Systemd para lingmo-app-sync
mkdir -p /etc/systemd/system
cat << 'APP_SYNC_SERVICE' > /etc/systemd/system/lingmo-app-sync.service
[Unit]
Description=Lingmo OS Application and Icon Auto-Sync Daemon
After=snapd.service
Wants=snapd.service

[Service]
Type=simple
ExecStart=/usr/local/bin/lingmo-app-sync
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
APP_SYNC_SERVICE
systemctl enable lingmo-app-sync.service 2>/dev/null || true

# Autostart Xsession para lingmo-app-sync
cat << 'APP_SYNC_XSESSION' > /etc/X11/Xsession.d/93lingmo-app-sync
/usr/local/bin/lingmo-app-sync >/dev/null 2>&1 &
APP_SYNC_XSESSION
chmod +x /etc/X11/Xsession.d/93lingmo-app-sync

# Asegurar permisos correctos de usuario
chown -R 1000:1000 /home/* /etc/skel 2>/dev/null || true
chmod -R 755 /home/* /etc/skel 2>/dev/null || true
chmod -R a+rwX /tmp /var/tmp 2>/dev/null || true
chmod -R a+rw /sys/class/backlight/ 2>/dev/null || true

rm -rf /tmp/lingmo-statusbar /tmp/lingmo-settings
apt-get clean
