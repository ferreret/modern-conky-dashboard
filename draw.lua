--[[
  Modern Conky Dashboard - Cairo Renderer (Enhanced)
  Designed for 4K (3840x2160), auto-scales to any resolution
  Features: Clock, CPU/RAM/DISK/GPU gauges, System/Storage/Network info,
            Weather forecast, Calendar events, Top processes
]]

require 'cairo'

-- ==========================================================================
-- COLOR PALETTE
-- ==========================================================================
local C = {
    cyan     = {0.00, 0.84, 0.98, 1.0},
    purple   = {0.73, 0.53, 0.99, 1.0},
    coral    = {1.00, 0.42, 0.42, 1.0},
    green    = {0.30, 0.96, 0.68, 1.0},
    amber    = {1.00, 0.76, 0.28, 1.0},
    blue     = {0.40, 0.61, 1.00, 1.0},
    pink     = {1.00, 0.47, 0.78, 1.0},
    white    = {1.0, 1.0, 1.0, 0.93},
    white70  = {1.0, 1.0, 1.0, 0.70},
    white50  = {1.0, 1.0, 1.0, 0.50},
    white30  = {1.0, 1.0, 1.0, 0.30},
    white15  = {1.0, 1.0, 1.0, 0.15},
    white08  = {1.0, 1.0, 1.0, 0.08},
    bg       = {0.05, 0.05, 0.08, 0.55},
    bg_solid = {0.05, 0.05, 0.08, 0.75},
}

-- ==========================================================================
-- STATE & CACHE
-- ==========================================================================
local cache = {}
local ext = nil
local num_cores = nil

-- ==========================================================================
-- DRAWING HELPERS
-- ==========================================================================

local function init_ext()
    if not ext then
        ext = cairo_text_extents_t:create()
        if tolua and tolua.takeownership then tolua.takeownership(ext) end
    end
end

local function text(cr, str, x, y, font, size, color, bold, align)
    if not str or str == "" then return 0 end
    local weight = bold and CAIRO_FONT_WEIGHT_BOLD or CAIRO_FONT_WEIGHT_NORMAL
    cairo_select_font_face(cr, font, CAIRO_FONT_SLANT_NORMAL, weight)
    cairo_set_font_size(cr, size)
    cairo_text_extents(cr, str, ext)
    local tx = x
    if align == "c" then
        tx = x - ext.width / 2 - ext.x_bearing
    elseif align == "r" then
        tx = x - ext.width - ext.x_bearing
    end
    cairo_move_to(cr, tx, y)
    cairo_set_source_rgba(cr, color[1], color[2], color[3], color[4])
    cairo_show_text(cr, str)
    return ext.width
end

local function arc(cr, cx, cy, r, start_deg, end_deg, w, color)
    if start_deg >= end_deg then return end
    cairo_set_source_rgba(cr, color[1], color[2], color[3], color[4])
    cairo_set_line_width(cr, w)
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
    cairo_arc(cr, cx, cy, r, start_deg * math.pi / 180, end_deg * math.pi / 180)
    cairo_stroke(cr)
end

local function circle(cr, cx, cy, r, color)
    cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
    cairo_set_source_rgba(cr, color[1], color[2], color[3], color[4])
    cairo_fill(cr)
end

local function line(cr, x1, y1, x2, y2, w, color)
    cairo_set_source_rgba(cr, color[1], color[2], color[3], color[4])
    cairo_set_line_width(cr, w)
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
    cairo_move_to(cr, x1, y1)
    cairo_line_to(cr, x2, y2)
    cairo_stroke(cr)
end

local function rrect(cr, x, y, w, h, r, color)
    local pi = math.pi
    cairo_new_path(cr)
    cairo_arc(cr, x + r, y + r, r, pi, 1.5 * pi)
    cairo_arc(cr, x + w - r, y + r, r, 1.5 * pi, 2 * pi)
    cairo_arc(cr, x + w - r, y + h - r, r, 0, 0.5 * pi)
    cairo_arc(cr, x + r, y + h - r, r, 0.5 * pi, pi)
    cairo_close_path(cr)
    cairo_set_source_rgba(cr, color[1], color[2], color[3], color[4])
    cairo_fill(cr)
end

-- ==========================================================================
-- DATA HELPERS
-- ==========================================================================

local function cnum(var) return tonumber(conky_parse(var)) or 0 end
local function cstr(var) return conky_parse(var) or "" end
local function ctrim(var)
    local s = cstr(var)
    return s:match("^%s*(.-)%s*$") or s
end

local function static(key, var)
    if not cache[key] then cache[key] = cstr(var) end
    return cache[key]
end

local function get_iface()
    if not cache._iface then
        local f = io.popen("ip route get 1.1.1.1 2>/dev/null | head -1")
        local out = f and f:read("*l") or ""
        if f then f:close() end
        cache._iface = out:match("dev%s+(%S+)") or "eth0"
    end
    return cache._iface
end

local function get_cores()
    if not num_cores then
        local f = io.popen("nproc 2>/dev/null")
        num_cores = tonumber(f and f:read("*l")) or 4
        if f then f:close() end
    end
    return num_cores
end

--- Read key=value file with caching
local function read_kv_file(path, cache_key, ttl)
    ttl = ttl or 30
    if cache[cache_key] and cache[cache_key .. "_t"] and
       os.time() - cache[cache_key .. "_t"] < ttl then
        return cache[cache_key]
    end
    local data = {}
    local f = io.open(path, "r")
    if not f then return nil end
    for ln in f:lines() do
        local k, v = ln:match("^([%w_]+)=(.+)$")
        if k and v then data[k] = v end
    end
    f:close()
    if next(data) == nil then return nil end
    cache[cache_key] = data
    cache[cache_key .. "_t"] = os.time()
    return data
end

--- Get weather data from cached file
local function get_weather()
    return read_kv_file("/tmp/conky-weather.txt", "_weather", 30)
end

--- Get calendar events from cached file
local function get_calendar()
    if cache._cal and cache._cal_t and os.time() - cache._cal_t < 30 then
        return cache._cal
    end
    local events = {}
    local f = io.open("/tmp/conky-calendar.txt", "r")
    if not f then
        cache._cal = nil
        cache._cal_t = os.time()
        return nil
    end
    for ln in f:lines() do
        if ln == "NO_GCALCLI" then
            f:close()
            cache._cal = "NO_GCALCLI"
            cache._cal_t = os.time()
            return "NO_GCALCLI"
        end
        if ln == "NO_EVENTS" then
            f:close()
            cache._cal = "NO_EVENTS"
            cache._cal_t = os.time()
            return "NO_EVENTS"
        end
        if ln ~= "" then
            -- TSV: start_date \t start_time \t end_date \t end_time \t summary
            local fields = {}
            for field in (ln .. "\t"):gmatch("([^\t]*)\t") do
                table.insert(fields, field)
            end
            if #fields >= 5 then
                table.insert(events, {
                    date = fields[1],
                    time = (fields[2] ~= "") and fields[2] or "all day",
                    end_date = fields[3],
                    end_time = fields[4],
                    title = fields[5],
                })
            end
        end
    end
    f:close()
    cache._cal = (#events > 0) and events or "NO_EVENTS"
    cache._cal_t = os.time()
    return cache._cal
end

--- Get mounted filesystems
local function get_disks()
    if cache._disks and cache._disks_t and os.time() - cache._disks_t < 30 then
        return cache._disks
    end
    local disks = {}
    local f = io.popen("df -h --output=target,fstype,size,used,pcent -x tmpfs -x devtmpfs -x udev -x efivarfs -x squashfs 2>/dev/null | tail -n+2")
    if f then
        for ln in f:lines() do
            local mount, fstype, size, used, pct = ln:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%d+)%%")
            if mount and mount ~= "/boot/efi" and mount ~= "/boot" then
                local label = mount
                if mount:match("^/media/.+/(.+)$") then
                    label = mount:match("^/media/.+/(.+)$")
                elseif mount == "/" then
                    label = "Root"
                end
                table.insert(disks, {
                    mount = mount, label = label, fstype = fstype,
                    size = size, used = used, pct = tonumber(pct) or 0,
                })
            end
        end
        f:close()
    end
    cache._disks = disks
    cache._disks_t = os.time()
    return disks
end

-- ==========================================================================
-- PANEL HELPERS
-- ==========================================================================

--- Standard panel header with title and separator
local function panel_header(cr, x, y, pw, title, color, s)
    local pad = 24 * s
    text(cr, title, x + pad, y + 34 * s, "Inter", 17 * s, color, true, "l")
    line(cr, x + pad, y + 48 * s, x + pw - pad, y + 48 * s, 1 * s, C.white08)
    return y + 72 * s  -- first content y
end

--- Key-value row in a panel
local function panel_row(cr, lx, rx, y, label, value, label_color, value_color, s)
    text(cr, label, lx, y, "Inter", 14 * s, label_color or C.white30, false, "l")
    text(cr, value, rx, y, "Inter", 14 * s, value_color or C.white70, false, "r")
end

-- ==========================================================================
-- COMPONENTS
-- ==========================================================================

--- Large digital clock with seconds ring and weather temp
local function draw_clock(cr, cx, cy, s)
    local hours = cstr("${time %H}")
    local mins  = cstr("${time %M}")
    local secs  = tonumber(cstr("${time %S}")) or 0

    -- Seconds ring
    local ring_r = 170 * s
    arc(cr, cx, cy - 12 * s, ring_r, -90, 270, 2 * s, C.white08)
    if secs > 0 then
        arc(cr, cx, cy - 12 * s, ring_r, -90, -90 + (secs / 60) * 360, 2.5 * s, C.cyan)
        local a = (-90 + (secs / 60) * 360) * math.pi / 180
        circle(cr, cx + ring_r * math.cos(a), cy - 12 * s + ring_r * math.sin(a),
               4 * s, C.cyan)
    end

    -- Time
    local colon_a = 0.35 + 0.60 * math.abs(math.cos(secs * math.pi))
    text(cr, hours, cx - 20 * s, cy + 8 * s, "Inter", 150 * s, C.white, true, "r")
    text(cr, ":", cx, cy - 8 * s, "Inter", 125 * s, {1, 1, 1, colon_a}, false, "c")
    text(cr, mins, cx + 20 * s, cy + 8 * s, "Inter", 150 * s, C.white, true, "l")

    -- Date
    local date_str = string.upper(cstr("${time %A, %d %B}"))
    text(cr, date_str, cx, cy + 68 * s, "Inter", 26 * s, C.white50, false, "c")

    -- Weather summary next to clock
    local w = get_weather()
    if w and w.TEMP then
        local temp_str = w.TEMP .. "°C"
        local desc = w.DESC or ""
        text(cr, temp_str, cx + 250 * s, cy - 60 * s, "Inter", 30 * s, C.amber, true, "l")
        text(cr, desc, cx + 250 * s, cy - 30 * s, "Inter", 16 * s, C.white50, false, "l")
        if w.LOCATION then
            text(cr, w.LOCATION, cx + 250 * s, cy - 8 * s, "Inter", 13 * s, C.white30, false, "l")
        end
    end
end

--- Circular gauge
local function draw_gauge(cr, cx, cy, r, w, pct, label, detail1, detail2, base_color, s)
    local start = 135
    local stop  = 405
    local span  = stop - start
    local val_stop = start + span * math.min(pct / 100, 1.0)

    -- Background ring
    arc(cr, cx, cy, r, start, stop, w, C.white08)

    -- Tick marks
    for i = 0, 10 do
        local ta = (start + span * i / 10) * math.pi / 180
        local tr1 = r - w / 2 - 4 * s
        local tr2 = r - w / 2 - 10 * s
        line(cr, cx + tr1 * math.cos(ta), cy + tr1 * math.sin(ta),
                 cx + tr2 * math.cos(ta), cy + tr2 * math.sin(ta), 1.5 * s, C.white15)
    end

    if pct > 0 then
        -- Glow
        arc(cr, cx, cy, r, start, val_stop, w + 12 * s,
            {base_color[1], base_color[2], base_color[3], 0.10})
        -- Value arc
        arc(cr, cx, cy, r, start, val_stop, w, base_color)
        -- Endpoint dot
        local ea = val_stop * math.pi / 180
        circle(cr, cx + r * math.cos(ea), cy + r * math.sin(ea),
               w / 2 + 3 * s, base_color)
    end

    -- Percentage text
    text(cr, string.format("%.0f", pct), cx, cy + 8 * s,
         "JetBrainsMono Nerd Font", r * 0.40, C.white, true, "c")
    text(cr, "%", cx, cy + 8 * s + r * 0.22,
         "Inter", r * 0.16, C.white30, false, "c")

    -- Label
    text(cr, label, cx, cy + r + 36 * s,
         "Inter", 20 * s, C.white70, true, "c")

    -- Details
    if detail1 and detail1 ~= "" then
        text(cr, detail1, cx, cy + r + 58 * s, "Inter", 14 * s, C.white50, false, "c")
    end
    if detail2 and detail2 ~= "" then
        text(cr, detail2, cx, cy + r + 76 * s, "Inter", 14 * s, C.white30, false, "c")
    end
end

--- CPU core activity dots around gauge
local function draw_core_dots(cr, cx, cy, r, s)
    local n = get_cores()
    local shown = math.min(n, 24)
    local start, span = 135, 270
    for i = 1, shown do
        local ci = (n > 24) and math.floor((i - 1) * n / shown) + 1 or i
        local pct = cnum("${cpu cpu" .. ci .. "}")
        local a = (start + span * ((i - 0.5) / shown)) * math.pi / 180
        local dr = r + 22 * s
        local alpha = 0.08 + 0.92 * (pct / 100)
        circle(cr, cx + dr * math.cos(a), cy + dr * math.sin(a),
               3.5 * s, {C.cyan[1], C.cyan[2], C.cyan[3], alpha})
    end
end

--- SWAP indicator arc inside RAM gauge
local function draw_swap_arc(cr, cx, cy, r, s)
    local swap_pct = cnum("${swapperc}")
    local swap_used = ctrim("${swap}")
    local swap_max  = ctrim("${swapmax}")
    if swap_pct > 0 then
        local sr = r - 22 * s
        local start, stop = 135, 405
        local val = start + (stop - start) * math.min(swap_pct / 100, 1)
        arc(cr, cx, cy, sr, start, stop, 4 * s, C.white08)
        arc(cr, cx, cy, sr, start, val, 4 * s,
            {C.amber[1], C.amber[2], C.amber[3], 0.7})
    end
    -- Show SWAP text below RAM details
    if swap_used ~= "" and swap_max ~= "" then
        text(cr, "SWAP " .. swap_used .. " / " .. swap_max, cx, cy + r + 94 * s,
             "Inter", 12 * s, C.amber, false, "c")
    end
end

--- Hub circle with hostname and system load
local function draw_hub(cr, cx, cy, r, s)
    circle(cr, cx, cy, r + 4 * s, {C.cyan[1], C.cyan[2], C.cyan[3], 0.06})
    circle(cr, cx, cy, r, C.bg_solid)
    arc(cr, cx, cy, r, 0, 360, 2 * s, C.cyan)

    -- Load ring
    local cpu = cnum("${cpu cpu0}")
    local mem = cnum("${memperc}")
    local load_pct = (cpu + mem) / 2
    if load_pct > 0 then
        arc(cr, cx, cy, r - 7 * s, -90, -90 + 360 * load_pct / 100, 2 * s,
            {C.cyan[1], C.cyan[2], C.cyan[3], 0.3})
    end

    local hostname = static("hostname", "${nodename}")
    text(cr, hostname, cx, cy + 5 * s, "Inter", 14 * s, C.cyan, true, "c")
end

--- Connection lines hub -> gauges
local function draw_connections(cr, hx, hy, positions, s)
    for _, p in ipairs(positions) do
        line(cr, hx, hy, p.x, p.y, 1.2 * s, C.white08)
        circle(cr, p.x, p.y, 3.5 * s, C.white15)
    end
    circle(cr, hx, hy, 5 * s, {C.cyan[1], C.cyan[2], C.cyan[3], 0.4})
end

--- System info panel
local function draw_sys_panel(cr, x, y, pw, ph, s)
    rrect(cr, x, y, pw, ph, 16 * s, C.bg)
    local ly = panel_header(cr, x, y, pw, "S Y S T E M", C.cyan, s)
    local pad = 24 * s
    local lx, rx = x + pad, x + pw - pad
    local gap = 28 * s

    local cpu_model = static("cpu_model",
        "${exec grep 'model name' /proc/cpuinfo | head -1 | sed 's/.*: //'}")
    local distro = static("distro",
        "${exec lsb_release -ds 2>/dev/null || (. /etc/os-release 2>/dev/null && echo $PRETTY_NAME) || echo Linux}")
    local gpu_model = static("gpu_model",
        "${exec nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'N/A'}")

    local rows = {
        {"CPU",       cpu_model},
        {"GPU",       gpu_model},
        {"OS",        distro},
        {"Kernel",    cstr("${kernel}")},
        {"Uptime",    cstr("${uptime_short}")},
        {"Processes", cstr("${running_processes}") .. " / " .. cstr("${processes}")},
        {"Load Avg",  cstr("${loadavg 1}") .. "  " .. cstr("${loadavg 2}") .. "  " .. cstr("${loadavg 3}")},
    }

    for i, row in ipairs(rows) do
        panel_row(cr, lx, rx, ly + gap * (i - 1), row[1], row[2], nil, nil, s)
    end
end

--- Storage panel with mounted disks and I/O
local function draw_storage_panel(cr, x, y, pw, ph, s)
    rrect(cr, x, y, pw, ph, 16 * s, C.bg)
    local ly = panel_header(cr, x, y, pw, "S T O R A G E", C.coral, s)
    local pad = 24 * s
    local lx, rx = x + pad, x + pw - pad
    local bar_h = 6 * s
    local gap = 44 * s

    -- Mounted disks with bars
    local disks = get_disks()
    if disks then
        for i, d in ipairs(disks) do
            if i > 4 then break end
            local ry = ly + gap * (i - 1)
            text(cr, d.label, lx, ry, "Inter", 14 * s, C.white70, false, "l")
            text(cr, d.used .. " / " .. d.size, rx - 70 * s, ry,
                 "Inter", 13 * s, C.white50, false, "r")
            text(cr, d.pct .. "%", rx, ry, "JetBrainsMono Nerd Font", 13 * s, C.coral, false, "r")
            -- Progress bar
            local bar_y = ry + 8 * s
            local bar_w = pw - pad * 2
            rrect(cr, lx, bar_y, bar_w, bar_h, bar_h / 2, C.white08)
            if d.pct > 0 then
                local fill_color = d.pct > 85 and C.coral or d.pct > 65 and C.amber or C.green
                rrect(cr, lx, bar_y, bar_w * d.pct / 100, bar_h, bar_h / 2, fill_color)
            end
        end
    end

    -- Disk I/O at bottom
    local io_y = ly + gap * math.min(#(disks or {}), 4) + 8 * s
    line(cr, lx, io_y - 8 * s, rx, io_y - 8 * s, 1 * s, C.white08)
    local dio_r = ctrim("${diskio_read}")
    local dio_w = ctrim("${diskio_write}")
    text(cr, "Read", lx, io_y + 20 * s, "Inter", 13 * s, C.white30, false, "l")
    text(cr, dio_r, lx + 70 * s, io_y + 20 * s, "JetBrainsMono Nerd Font", 13 * s, C.green, false, "l")
    text(cr, "Write", rx - 130 * s, io_y + 20 * s, "Inter", 13 * s, C.white30, false, "l")
    text(cr, dio_w, rx, io_y + 20 * s, "JetBrainsMono Nerd Font", 13 * s, C.coral, false, "r")
end

--- Network panel with external IP
local function draw_net_panel(cr, x, y, pw, ph, s)
    rrect(cr, x, y, pw, ph, 16 * s, C.bg)
    local ly = panel_header(cr, x, y, pw, "N E T W O R K", C.purple, s)
    local pad = 24 * s
    local lx, rx = x + pad, x + pw - pad
    local gap = 28 * s
    local iface = get_iface()

    local ext_ip = ctrim("${execi 3600 wget -q -O- https://ipecho.net/plain 2>/dev/null || echo N/A}")

    local rows = {
        {"Download",  ctrim("${downspeed " .. iface .. "}"),  C.green},
        {"Upload",    ctrim("${upspeed " .. iface .. "}"),    C.coral},
        {"Interface", iface,                                   C.white70},
        {"Local IP",  ctrim("${addr " .. iface .. "}"),       C.white70},
        {"External",  ext_ip,                                  C.white70},
        {"Total D/U", ctrim("${totaldown " .. iface .. "}") .. " / " .. ctrim("${totalup " .. iface .. "}"), C.white50},
    }

    for i, row in ipairs(rows) do
        text(cr, row[1], lx, ly + gap * (i - 1), "Inter", 14 * s, C.white30, false, "l")
        text(cr, row[2], rx, ly + gap * (i - 1),
             "JetBrainsMono Nerd Font", 14 * s, row[3], false, "r")
    end
end

--- Weather forecast panel
local function draw_weather_panel(cr, x, y, pw, ph, s)
    rrect(cr, x, y, pw, ph, 16 * s, C.bg)
    local ly = panel_header(cr, x, y, pw, "W E A T H E R", C.amber, s)
    local pad = 24 * s
    local lx, rx = x + pad, x + pw - pad
    local gap = 28 * s

    local w = get_weather()
    if not w then
        text(cr, "Loading weather data...", lx, ly + 20 * s,
             "Inter", 14 * s, C.white30, false, "l")
        return
    end

    -- Current conditions
    text(cr, (w.TEMP or "?") .. "°C", lx, ly,
         "Inter", 28 * s, C.amber, true, "l")
    text(cr, w.DESC or "", lx + 90 * s, ly,
         "Inter", 16 * s, C.white70, false, "l")

    local cy = ly + 32 * s
    text(cr, "Feels " .. (w.FEELS or "?") .. "°C", lx, cy,
         "Inter", 13 * s, C.white50, false, "l")
    text(cr, "Humidity " .. (w.HUMIDITY or "?") .. "%", lx + 130 * s, cy,
         "Inter", 13 * s, C.white50, false, "l")
    text(cr, "Wind " .. (w.WIND or "?") .. " km/h " .. (w.WIND_DIR or ""),
         lx + 280 * s, cy, "Inter", 13 * s, C.white50, false, "l")

    local cy2 = cy + 18 * s
    text(cr, "UV " .. (w.UV or "?"), lx, cy2,
         "Inter", 13 * s, C.white30, false, "l")
    text(cr, "Pressure " .. (w.PRESSURE or "?") .. " hPa", lx + 80 * s, cy2,
         "Inter", 13 * s, C.white30, false, "l")
    text(cr, "Visibility " .. (w.VISIBILITY or "?") .. " km", lx + 260 * s, cy2,
         "Inter", 13 * s, C.white30, false, "l")

    -- Separator
    line(cr, lx, cy2 + 14 * s, rx, cy2 + 14 * s, 1 * s, C.white08)

    -- 3-day forecast
    local fy = cy2 + 36 * s
    for i = 0, 2 do
        local prefix = "F" .. i .. "_"
        local day  = w[prefix .. "DAY"] or ""
        local desc = w[prefix .. "DESC"] or ""
        local hi   = w[prefix .. "MAX"] or "?"
        local lo   = w[prefix .. "MIN"] or "?"

        if i == 0 then day = "Today" end

        local row_y = fy + gap * i
        text(cr, day, lx, row_y, "Inter", 14 * s, C.white70, false, "l")
        text(cr, desc, lx + 130 * s, row_y, "Inter", 13 * s, C.white50, false, "l")
        text(cr, hi .. " / " .. lo .. "°C", rx, row_y,
             "JetBrainsMono Nerd Font", 13 * s, C.amber, false, "r")
    end
end

--- Calendar events panel
local function draw_calendar_panel(cr, x, y, pw, ph, s)
    rrect(cr, x, y, pw, ph, 16 * s, C.bg)
    local ly = panel_header(cr, x, y, pw, "C A L E N D A R", C.pink, s)
    local pad = 24 * s
    local lx, rx = x + pad, x + pw - pad
    local gap = 26 * s

    local cal = get_calendar()

    if cal == "NO_GCALCLI" or cal == nil then
        text(cr, "gcalcli not installed", lx, ly + 10 * s,
             "Inter", 14 * s, C.white30, false, "l")
        text(cr, "pip install gcalcli", lx, ly + 36 * s,
             "JetBrainsMono Nerd Font", 13 * s, C.pink, false, "l")
        text(cr, "Then run: gcalcli init", lx, ly + 58 * s,
             "Inter", 13 * s, C.white30, false, "l")
        return
    end

    if cal == "NO_EVENTS" then
        text(cr, "No upcoming events", lx, ly + 10 * s,
             "Inter", 14 * s, C.white30, false, "l")
        return
    end

    -- Show events
    local today = os.date("%Y-%m-%d")
    local prev_date = ""
    local row_i = 0

    for _, ev in ipairs(cal) do
        if row_i >= 8 then break end
        local ry = ly + gap * row_i

        -- Date header if different day
        if ev.date ~= prev_date then
            if row_i > 0 then
                row_i = row_i + 0.3
                ry = ly + gap * row_i
            end
            local day_label = (ev.date == today) and "Today" or ev.date
            text(cr, day_label, lx, ry, "Inter", 12 * s, C.pink, true, "l")
            prev_date = ev.date
            row_i = row_i + 1
            ry = ly + gap * row_i
        end

        -- Time + title
        local time_short = ev.time:sub(1, 5)
        text(cr, time_short, lx, ry, "JetBrainsMono Nerd Font", 13 * s, C.white50, false, "l")
        text(cr, ev.title, lx + 65 * s, ry, "Inter", 13 * s, C.white70, false, "l")
        -- Dot indicator
        circle(cr, rx - 4 * s, ry - 4 * s, 3 * s, C.pink)
        row_i = row_i + 1
    end
end

--- Top processes panel (CPU + MEM + I/O)
local function draw_procs_panel(cr, x, y, pw, ph, s)
    rrect(cr, x, y, pw, ph, 16 * s, C.bg)
    local pad = 24 * s
    local col_w = (pw - pad * 2) / 3
    local n = 6

    -- Headers
    local c1 = x + pad
    local c2 = x + pad + col_w + 10 * s
    local c3 = x + pad + col_w * 2 + 20 * s

    text(cr, "T O P  C P U", c1, y + 34 * s, "Inter", 16 * s, C.cyan, true, "l")
    text(cr, "T O P  M E M O R Y", c2, y + 34 * s, "Inter", 16 * s, C.purple, true, "l")
    text(cr, "T O P  I / O", c3, y + 34 * s, "Inter", 16 * s, C.coral, true, "l")

    line(cr, x + pad, y + 48 * s, x + pw - pad, y + 48 * s, 1 * s, C.white08)
    -- Vertical dividers
    line(cr, c2 - 10 * s, y + 48 * s, c2 - 10 * s, y + ph - pad, 1 * s, C.white08)
    line(cr, c3 - 10 * s, y + 48 * s, c3 - 10 * s, y + ph - pad, 1 * s, C.white08)

    local ly = y + 72 * s
    local gap = 26 * s
    local bar_w = 60 * s
    local bar_h = 4 * s

    for i = 1, n do
        local ry = ly + gap * (i - 1)

        -- CPU
        local cpu_name = ctrim("${top name " .. i .. "}")
        local cpu_val  = tonumber(ctrim("${top cpu " .. i .. "}")) or 0
        text(cr, cpu_name, c1, ry, "JetBrainsMono Nerd Font", 12 * s, C.white70, false, "l")
        rrect(cr, c1 + col_w - bar_w - 55 * s, ry - bar_h - 2 * s, bar_w, bar_h, 2 * s, C.white08)
        if cpu_val > 0 then
            rrect(cr, c1 + col_w - bar_w - 55 * s, ry - bar_h - 2 * s,
                  bar_w * math.min(cpu_val / 100, 1), bar_h, 2 * s, C.cyan)
        end
        text(cr, string.format("%.1f%%", cpu_val), c1 + col_w - 10 * s, ry,
             "JetBrainsMono Nerd Font", 12 * s, C.cyan, false, "r")

        -- Memory
        local mem_name = ctrim("${top_mem name " .. i .. "}")
        local mem_val  = tonumber(ctrim("${top_mem mem " .. i .. "}")) or 0
        text(cr, mem_name, c2, ry, "JetBrainsMono Nerd Font", 12 * s, C.white70, false, "l")
        rrect(cr, c2 + col_w - bar_w - 55 * s, ry - bar_h - 2 * s, bar_w, bar_h, 2 * s, C.white08)
        if mem_val > 0 then
            rrect(cr, c2 + col_w - bar_w - 55 * s, ry - bar_h - 2 * s,
                  bar_w * math.min(mem_val / 100, 1), bar_h, 2 * s, C.purple)
        end
        text(cr, string.format("%.1f%%", mem_val), c2 + col_w - 10 * s, ry,
             "JetBrainsMono Nerd Font", 12 * s, C.purple, false, "r")

        -- I/O
        local io_name  = ctrim("${top_io name " .. i .. "}")
        local io_read  = ctrim("${top_io io_read " .. i .. "}")
        local io_write = ctrim("${top_io io_write " .. i .. "}")
        text(cr, io_name, c3, ry, "JetBrainsMono Nerd Font", 12 * s, C.white70, false, "l")
        text(cr, io_read .. " / " .. io_write, c3 + col_w - 30 * s, ry,
             "JetBrainsMono Nerd Font", 11 * s, C.coral, false, "r")
    end
end

--- Decorative elements
local function draw_decorations(cr, w, h, s)
    -- Separator under clock
    local sep_y = h * 0.205
    line(cr, w * 0.12, sep_y, w * 0.88, sep_y, 1 * s, C.white08)
    -- Center diamond
    local dx, dy = w * 0.5, sep_y
    cairo_new_path(cr)
    cairo_move_to(cr, dx, dy - 5 * s)
    cairo_line_to(cr, dx + 5 * s, dy)
    cairo_line_to(cr, dx, dy + 5 * s)
    cairo_line_to(cr, dx - 5 * s, dy)
    cairo_close_path(cr)
    cairo_set_source_rgba(cr, C.cyan[1], C.cyan[2], C.cyan[3], 0.3)
    cairo_fill(cr)

    -- Corner accents
    local m = 35 * s
    local corner_len = 30 * s
    -- Top-left
    line(cr, m, m, m + corner_len, m, 1.5 * s, C.white15)
    line(cr, m, m, m, m + corner_len, 1.5 * s, C.white15)
    -- Top-right
    line(cr, w - m, m, w - m - corner_len, m, 1.5 * s, C.white15)
    line(cr, w - m, m, w - m, m + corner_len, 1.5 * s, C.white15)
    -- Bottom-left
    line(cr, m, h - m, m + corner_len, h - m, 1.5 * s, C.white15)
    line(cr, m, h - m, m, h - m - corner_len, 1.5 * s, C.white15)
    -- Bottom-right
    line(cr, w - m, h - m, w - m - corner_len, h - m, 1.5 * s, C.white15)
    line(cr, w - m, h - m, w - m, h - m - corner_len, 1.5 * s, C.white15)

    -- Bottom center line
    line(cr, w * 0.35, h * 0.96, w * 0.65, h * 0.96, 1 * s, C.white08)
end

-- ==========================================================================
-- MAIN ENTRY POINT
-- ==========================================================================
function conky_main()
    if conky_window == nil then return end

    local w = conky_window.width
    local h = conky_window.height
    if w < 200 or h < 200 then return end

    local s = w / 3840
    init_ext()

    local cs = cairo_xlib_surface_create(
        conky_window.display, conky_window.drawable,
        conky_window.visual, w, h)
    local cr = cairo_create(cs)

    -- ── Layout ──
    local cx = w / 2
    local gr = 120 * s     -- gauge radius
    local gw = 12 * s      -- gauge width
    local gauge_y = h * 0.31

    local g = {
        cpu  = {x = w * 0.13, y = gauge_y},
        ram  = {x = w * 0.37, y = gauge_y},
        disk = {x = w * 0.63, y = gauge_y},
        gpu  = {x = w * 0.87, y = gauge_y},
    }

    -- Panel grid: 3 columns, 2 rows
    local pw = w * 0.24
    local pgap = (w - pw * 3) / 4
    local cols = {pgap, pgap * 2 + pw, pgap * 3 + pw * 2}
    local row1_y = h * 0.485
    local row2_y = h * 0.665
    local ph1 = 270 * s
    local ph2 = 280 * s

    -- ── Decorations ──
    draw_decorations(cr, w, h, s)

    -- ── Clock + Weather Summary ──
    draw_clock(cr, cx, h * 0.11, s)

    -- ── Connections ──
    local gauge_list = {g.cpu, g.ram, g.disk, g.gpu}
    draw_connections(cr, cx, gauge_y, gauge_list, s)

    -- ── Hub ──
    draw_hub(cr, cx, gauge_y, 45 * s, s)

    -- ── CPU Gauge ──
    local cpu_pct  = cnum("${cpu cpu0}")
    local cpu_temp = ctrim("${hwmon 4 temp 1}")
    local cpu_freq = ctrim("${freq_g}")
    local cpu_model_short = static("cpu_short",
        "${exec grep 'model name' /proc/cpuinfo | head -1 | sed 's/.*\\(i[0-9]-[^ ]*\\).*/\\1/'}")
    local t_str = (cpu_temp ~= "") and (cpu_temp .. "°C  ") or ""
    local f_str = (cpu_freq ~= "") and (cpu_freq .. " GHz") or ""
    draw_gauge(cr, g.cpu.x, g.cpu.y, gr, gw, cpu_pct,
               "C P U", t_str .. f_str, cpu_model_short, C.cyan, s)
    draw_core_dots(cr, g.cpu.x, g.cpu.y, gr, s)

    -- ── RAM Gauge + SWAP ──
    local mem_pct   = cnum("${memperc}")
    local mem_used  = ctrim("${mem}")
    local mem_total = ctrim("${memmax}")
    draw_gauge(cr, g.ram.x, g.ram.y, gr, gw, mem_pct,
               "R A M", mem_used .. " / " .. mem_total, nil, C.purple, s)
    draw_swap_arc(cr, g.ram.x, g.ram.y, gr, s)

    -- ── DISK Gauge ──
    local disk_pct   = cnum("${fs_used_perc /}")
    local disk_used  = ctrim("${fs_used /}")
    local disk_total = ctrim("${fs_size /}")
    draw_gauge(cr, g.disk.x, g.disk.y, gr, gw, disk_pct,
               "D I S K", disk_used .. " / " .. disk_total, nil, C.coral, s)

    -- ── GPU Gauge ──
    local gpu_pct  = cnum("${nvidia gpuutil}")
    local gpu_temp = ctrim("${nvidia gputemp}")
    local gpu_fan  = ctrim("${nvidia fanlevel}")
    local gpu_mem  = ctrim("${nvidia memused}")
    local gpu_mt   = ctrim("${nvidia memtotal}")
    local gpu_name = static("gpu_short",
        "${exec nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | sed 's/NVIDIA //'}")
    local gpu_d1 = ""
    if gpu_temp ~= "" and gpu_temp ~= "0" then gpu_d1 = gpu_temp .. "°C" end
    if gpu_fan ~= "" and gpu_fan ~= "0" then
        gpu_d1 = gpu_d1 .. (gpu_d1 ~= "" and "  Fan " or "Fan ") .. gpu_fan .. "%"
    end
    local gpu_d2 = ""
    if gpu_mem ~= "" and gpu_mt ~= "" then gpu_d2 = gpu_mem .. " / " .. gpu_mt .. " MiB" end
    draw_gauge(cr, g.gpu.x, g.gpu.y, gr, gw, gpu_pct,
               "G P U", gpu_d1, gpu_name ~= "" and gpu_name or gpu_d2, C.green, s)

    -- ── Row 1: System | Storage | Network ──
    draw_sys_panel(cr, cols[1], row1_y, pw, ph1, s)
    draw_storage_panel(cr, cols[2], row1_y, pw, ph1, s)
    draw_net_panel(cr, cols[3], row1_y, pw, ph1, s)

    -- ── Row 2: Weather | Processes | Calendar ──
    draw_weather_panel(cr, cols[1], row2_y, pw, ph2, s)
    draw_procs_panel(cr, cols[2], row2_y, pw, ph2, s)
    draw_calendar_panel(cr, cols[3], row2_y, pw, ph2, s)

    -- Cleanup
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
