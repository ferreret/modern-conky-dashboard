<div align="center">

# 🤖 Modern Conky Dashboard

### *Panel de control tipo cockpit para Linux, renderizado con Cairo sobre Conky*

![Conky](https://img.shields.io/badge/Conky-1.19%2B-00D8FF?style=for-the-badge&logo=linux&logoColor=white)
![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?style=for-the-badge&logo=lua&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-5%2B-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Cairo](https://img.shields.io/badge/Cairo-Graphics-FF4F8B?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

![Status](https://img.shields.io/badge/status-active-success)
![Platform](https://img.shields.io/badge/platform-Linux-blue)
![Resolution](https://img.shields.io/badge/display-4K%20ready-ff69b4)
![Design](https://img.shields.io/badge/design-organic%20%2F%20no%20grid-9f7aea)

`#conky` `#linux-desktop` `#cairo` `#lua` `#dashboard` `#rice` `#proxmox` `#obsidian` `#garmin` `#widgets` `#portfolio`

</div>

---

## ✨ ¿Qué es esto?

Un **dashboard de escritorio** que se dibuja como overlay transparente a pantalla completa sobre tu wallpaper, combinando monitorización local (CPU, RAM, GPU, red, discos), servicios remotos (Proxmox, Google Calendar) y fuentes personales (Obsidian, Garmin) en un único panel con estética *organic layout* — sin rejillas, sin cajas, fuentes grandes y formas curvas que respetan el protagonismo del fondo.

Diseñado para pantallas **4K** con escalado automático a cualquier resolución mediante un único parámetro `s = width / 3840`.

---

## 📸 Captura

![Modern Conky Dashboard](docs/screenshot.png)

> *Mazinger Z como protagonista · widgets fluyendo alrededor sin invadirle*

---

## 🎯 Características

- 🧭 **Overlay a pantalla completa** transparente, `own_window_type = desktop`, no roba foco.
- 📐 **Escalado responsive** — un único parámetro adapta todo el panel a cualquier resolución.
- 🎨 **Renderizado Cairo** — gauges circulares, sparklines, barras suaves, tipografía con sombra sutil para legibilidad sobre wallpapers complejos.
- ⚡ **Bajo consumo** — cachés inteligentes por widget (2s a 30min) y procesos cacheados en Lua.
- 🔌 **Arquitectura de 17 widgets** componibles vía funciones `draw_*` declaradas en `conky_main()`.
- 🌐 **Fuentes de datos heterogéneas** — Proxmox API, Google Calendar (gcalcli), Obsidian vault, Garmin (vía Obsidian), wttr.in, CAVA audio pipe, sensores hwmon, systemd, journalctl, git, docker…

---

## 🧩 Widgets incluidos

| # | Widget | Función | Fuente | Descripción |
|---|--------|---------|--------|-------------|
| 1 | 🕐 **Clock** | `draw_clock` | `${time}` | Reloj digital grande + fecha + mini weather |
| 2 | 📊 **Cluster** | `draw_cluster` | Conky built-in | Gauges circulares superpuestos CPU/RAM/GPU con dots por core |
| 3 | 🌡️ **Temps** | `draw_temps` | hwmon + nvidia | Termómetros CPU/GPU con heatmap por core |
| 4 | 💾 **Storage** | `draw_storage_gauges` | `df -h` | Anillos por partición (hasta 3) |
| 5 | 🌐 **Network Graphs** | `draw_net_graph` | Conky `${downspeed}` | Dual graph Down/Up con histórico 200 muestras |
| 6 | 🖥️ **System Info** | `draw_sysinfo` | `/etc/os-release`, lscpu | Hostname, kernel, IP, uptime + contador apt upgradables |
| 7 | ☁️ **Proxmox** | `draw_proxmox` | Proxmox REST API | Banner con CPU/MEM/DSK del nodo + guests running + storage |
| 8 | ❤️ **Garmin** | `draw_garmin` | Obsidian vault | Body Battery, HR, estrés, pasos parseados del daily note |
| 9 | 📅 **Calendar** | `draw_calendar` | gcalcli | Grid de eventos próximos 30 días |
| 10 | 📌 **Pending** | `draw_pending` | Obsidian | Lista de temas en curso / planificados |
| 11 | 🎵 **Now Playing** | `draw_np_vis` | MPRIS + CAVA | Título/artista + visualizador audio 64 barras |
| 12 | 📈 **CPU History** | `draw_cpu_history` | Conky | Gráfico de barras histórico carga CPU |
| 13 | ⚡ **Processes** | `draw_procs` | Conky `${top}` | Top 5 procesos por CPU con % MEM |
| 14 | 🎨 **Flow Lines** | `draw_flow_lines` | — | Líneas conectoras curvas Bezier entre elementos |
| 15 | 🩺 **Health** | `draw_sysstatus` | systemd, journalctl, docker | Unidades caídas, errores recientes, reboot-required, docker up/down/unhealthy |
| 16 | 🌳 **Git Multi-repo** | `draw_gitstatus` | `git` CLI | Branch + dirty + ahead/behind de repos configurables |
| 17 | ☀️ **Weather v2** | `draw_weather` | wttr.in JSON | Temp grande + sparkline 24h + barras de precipitación + UV + sunrise/sunset + forecast 3d |

### 💤 Widgets huérfanos (código listo, pendientes de activar)

- `draw_next_event` — cuenta atrás para el próximo evento del calendario.
- `draw_today` — tareas `focus` del daily note de Obsidian.

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                      conky.conf                         │
│  · Ventana transparente full-screen                     │
│  · lua_load draw.lua + lua_draw_hook_pre main           │
│  · ${execi N ...} lanza scripts periódicos              │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│                      draw.lua                           │
│                                                         │
│  Helpers: txt() arc() circ() ln() rrect() draw_ring()   │
│  Data:    get_weather() get_calendar() get_media()      │
│           get_sysstatus() get_gitstatus() get_disks()   │
│                                                         │
│  Components: 17 × draw_* functions                      │
│                                                         │
│  conky_main() — orquesta posiciones relativas a w, h    │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│                  scripts/*.sh  (caché → /tmp)           │
│  weather.sh    → wttr.in              (30 min)          │
│  calendar.sh   → gcalcli              (5 min)           │
│  garmin.sh     → Obsidian daily note  (5 min)           │
│  obsidian-*.sh → Vault parsing        (5 min)           │
│  proxmox.sh    → Proxmox REST API     (30 s)            │
│  sysstatus.sh  → systemd+journal+docker (2 min)         │
│  gitstatus.sh  → git CLI loop         (1 min)           │
│  media.sh      → playerctl            (3 s)             │
│  cava-pipe.sh  → CAVA audio           (continuo)        │
└─────────────────────────────────────────────────────────┘
```

**Flujo de datos:** los scripts escriben a `/tmp/conky-*.txt` en formato KV (`KEY=value\n`) o TSV. Lua lee con `read_kv()` cacheado en memoria otros 30 s, de modo que el redraw a 0.2 s no martillea disco.

**Escalado:** toda geometría se multiplica por `s = window_width / 3840`. Diseñado para 4K, verificado hasta 1080p.

---

## 🧰 Requisitos

### Obligatorios

- **Conky** ≥ 1.10 con soporte Lua + Cairo
- **Lua** 5.1+ (normalmente incluido con Conky)
- **Bash** 5+
- **curl** + **jq** (para scripts que consumen JSON)
- Una **Nerd Font** — el proyecto usa `DaddyTimeMono Nerd Font` (cambiar en `draw.lua` si quieres otra)

### Opcionales (habilitan widgets concretos)

| Dependencia | Habilita | Instalación |
|-------------|----------|-------------|
| `nvidia-smi` + driver | Gauges GPU, temp GPU | — |
| `cava` | Visualizador audio | `apt install cava` |
| `playerctl` | Now Playing | `apt install playerctl` |
| `gcalcli` | Calendar | `pipx install gcalcli` |
| `docker` | Docker stats | — |
| `git` | Git multi-repo | — |
| Proxmox con API token | Widget Proxmox | — |
| Obsidian vault con daily notes | Garmin / Today / Pending | — |

---

## 🚀 Instalación

```bash
# 1. Clonar en ~/.config/conky/modern
git clone https://github.com/ferreret/modern-conky-dashboard.git ~/.config/conky/modern
cd ~/.config/conky/modern

# 2. Dar permisos a los scripts
chmod +x start.sh scripts/*.sh

# 3. Instalar la fuente (si no la tienes)
#    https://github.com/ryanoasis/nerd-fonts/releases → DaddyTimeMono

# 4. Configurar integraciones opcionales (ver abajo)
cp .proxmox.env.example .proxmox.env
$EDITOR .proxmox.env
$EDITOR .gitrepos

# 5. Lanzar
./start.sh
```

### Arrancar al iniciar sesión

```bash
# XDG autostart
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/modern-conky.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Modern Conky
Exec=$HOME/.config/conky/modern/start.sh
X-GNOME-Autostart-enabled=true
EOF
```

---

## ⚙️ Configuración

### 🔐 Proxmox (`.proxmox.env`)

```bash
PVE_HOST=192.168.1.100
PVE_PORT=8006
PVE_TOKEN_ID=conky@pve!conky
PVE_TOKEN_SECRET=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
PVE_INSECURE=1
```

> 🔒 Crear un token de solo lectura en Proxmox con rol **PVEAuditor** — nunca uses credenciales de admin.

### 🌳 Git Multi-repo (`.gitrepos`)

Un path por línea. `~` expande a `$HOME`. Se admite alias con `|`:

```
# Dotfiles y config
~/.config/conky/modern

# Proyectos con alias
/media/data/proyecto-largo|MiProyecto
~/work/cliente-x/backend|Cliente-X API
```

### 📔 Obsidian

Los scripts `garmin.sh`, `obsidian-today.sh` y `obsidian-pending.sh` asumen:
- Vault en `$HOME/<NombreVault>` (ajustable en cada script)
- Daily notes en formato `YYYY-MM-DD.md` con campos estándar de Obsidian

### 📅 Google Calendar

Primera autenticación:

```bash
pipx install gcalcli
gcalcli list   # abre navegador para OAuth
```

El script `calendar.sh` consulta los próximos 30 días.

### 🎨 Colores y fuentes

Paleta definida al inicio de `draw.lua`:

```lua
local C = {
    cyan   = {0.00, 0.84, 0.98, 1.0},
    purple = {0.73, 0.53, 0.99, 1.0},
    coral  = {1.00, 0.42, 0.42, 1.0},
    green  = {0.30, 0.96, 0.68, 1.0},
    amber  = {1.00, 0.76, 0.28, 1.0},
    pink   = {1.00, 0.47, 0.78, 1.0},
    -- grises con alpha ajustado para fondos variados
    w70 = {1,1,1,0.85}, w50 = {1,1,1,0.68}, w35 = {1,1,1,0.52},
}
```

Fuente en `MONO` y `SANS`:

```lua
local MONO = "DaddyTimeMono Nerd Font"
local SANS = "DaddyTimeMono Nerd Font"
```

---

## 🎛️ Personalización de layout

Todas las posiciones se declaran en `conky_main()` con fracciones de `w` y `h`. Para mover un widget, edita la llamada:

```lua
-- Antes
draw_weather(cr, w*0.60, h*0.48, w*0.18, s)

-- Más abajo y más a la izquierda
draw_weather(cr, w*0.58, h*0.55, w*0.20, s)
```

**Convenciones:**
- `x, y` → posición de anclaje (normalmente esquina superior izquierda del widget).
- `pw` → ancho disponible (para widgets con contenido adaptativo).
- `s` → factor de escala global.

---

## 📂 Estructura del proyecto

```
modern/
├── conky.conf              Configuración de Conky (ventana + execi scripts)
├── draw.lua                ~1300 líneas, toda la lógica de render
├── start.sh                Launcher con pre-fetch de datos
├── cava.conf               Configuración del visualizador de audio
├── .proxmox.env.example    Plantilla de variables Proxmox
├── .gitrepos               Lista de repos a monitorizar
├── scripts/
│   ├── weather.sh          wttr.in → JSON → KV
│   ├── calendar.sh         gcalcli → TSV
│   ├── garmin.sh           Obsidian daily → KV
│   ├── obsidian-today.sh   Focus tasks del daily
│   ├── obsidian-pending.sh Temas en curso
│   ├── obsidian-inbox.sh   Contador inbox
│   ├── proxmox.sh          API REST → KV
│   ├── sysstatus.sh        systemd + journal + docker → KV
│   ├── gitstatus.sh        git loop → TSV
│   ├── media.sh            playerctl → KV
│   └── cava-pipe.sh        CAVA → pipe continuo
├── docs/                   Screenshots y docs
└── PROGRESS_*.md           Notas de sesión (changelog informal)
```

---

## 🩹 Troubleshooting

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| Pantalla negra sin widgets | Conky no arrancó | `journalctl --user -e` o lanzar sin `-d` para ver errores |
| Widget vacío | Script no escribió caché | `ls -la /tmp/conky-*.txt`, ejecutar script a mano |
| Texto cortado | Widget fuera de pantalla | Ajustar coordenadas en `conky_main()` |
| GPU/Nvidia no aparece | `nvidia-smi` no disponible | Comentar `draw_cluster` GPU section |
| Weather muestra "?" | Sin internet o wttr.in caído | `./scripts/weather.sh` manualmente |
| Proxmox UNREACHABLE | Token expirado o host inaccesible | Verificar `.proxmox.env` y `curl -k $URL/api2/json/nodes` |
| GIT no muestra nada | `.gitrepos` vacío | Añadir rutas (una por línea) |

---

## 🗺️ Roadmap

### ✅ Hecho
- [x] Arquitectura de widgets componibles
- [x] Escalado responsive (parámetro único)
- [x] Integración Proxmox con API token
- [x] Widget HEALTH (systemd, journal, reboot, docker)
- [x] Widget GIT multi-repo con alias
- [x] Weather v2 con sparkline 24h + UV + sun
- [x] Sombra de texto para legibilidad en wallpapers variados

### 🚧 Siguientes candidatos
- [ ] Activar `draw_next_event` y `draw_today` (código ya escrito)
- [ ] Proxmox deep-dive — backups, snapshots viejos, temps del nodo
- [ ] Obsidian extendido — streak daily notes + heatmap 90d, tags trending
- [ ] Garmin profundo — sleep score, HRV, training load
- [ ] Red avanzada — latencia sparkline + VPN/Tailscale status
- [ ] GitHub CLI — PRs, reviews, GH Actions
- [ ] Alertas AEMET oficiales
- [ ] Pomodoro visual
- [ ] Timeline horizontal del día (Calendar + focus blocks)
- [ ] RSS ticker

---

## 🎨 Filosofía de diseño

> *"Organic layout, large fonts, no grids"*

- Los widgets **fluyen** alrededor del wallpaper en lugar de apilarse en rejilla.
- Las fuentes son **grandes y legibles** incluso a distancia (diseñado para pantallas grandes).
- El color denota **semántica** (verde = OK, ámbar = aviso, coral = crítico).
- Las líneas curvas (`draw_flow_lines`) conectan grupos de información relacionada.
- Cada widget tiene **headline minimalista** + contenido denso.

---

## 🤝 Contribuir

Este es un proyecto personal pero las ideas son bienvenidas. Para proponer un widget nuevo:

1. Fork + rama `feat/mi-widget`
2. Añade `scripts/mi-widget.sh` (si necesitas fuente externa)
3. Añade `draw_mi_widget` en `draw.lua` siguiendo patrón existente
4. Cablea `execi` en `conky.conf` y llama al widget en `conky_main()`
5. PR con screenshot

---

## 📜 Licencia

MIT — ver `LICENSE`.

---

## 🙏 Créditos

- [Conky](https://github.com/brndnmtthws/conky) — el motor que lo hace posible
- [wttr.in](https://wttr.in/) — datos meteorológicos gratuitos y divertidos
- [gcalcli](https://github.com/insanum/gcalcli) — CLI para Google Calendar
- [CAVA](https://github.com/karlstav/cava) — visualizador de audio
- [Nerd Fonts](https://www.nerdfonts.com/) — DaddyTimeMono
- Inspiración: la comunidad r/unixporn y años mirando cockpits de aviones

---

<div align="center">

**Hecho con ☕ y un 4K de sobra**

*Si te gusta, deja una ⭐ al repo — y compártelo con tu rice favorito.*

</div>
