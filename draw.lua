--[[
  Modern Conky Dashboard v6
  Organic circular design with transparent floating elements
]]

require 'cairo'

local C = {
    cyan   = {0.00, 0.84, 0.98, 1.0},
    purple = {0.73, 0.53, 0.99, 1.0},
    coral  = {1.00, 0.42, 0.42, 1.0},
    green  = {0.30, 0.96, 0.68, 1.0},
    amber  = {1.00, 0.76, 0.28, 1.0},
    pink   = {1.00, 0.47, 0.78, 1.0},
    white  = {1, 1, 1, 0.95},
    w70    = {1, 1, 1, 0.70},
    w50    = {1, 1, 1, 0.50},
    w35    = {1, 1, 1, 0.35},
    w20    = {1, 1, 1, 0.20},
    w10    = {1, 1, 1, 0.10},
    w05    = {1, 1, 1, 0.05},
    bg     = {0.03, 0.03, 0.06, 0.40},
}

local MONO = "DaddyTimeMono Nerd Font"
local SANS = "DaddyTimeMono Nerd Font"

local function rainbow(t)
    local S = {{0,C.cyan},{0.2,C.green},{0.4,C.amber},{0.6,C.coral},{0.8,C.purple},{1,C.pink}}
    t = math.max(0, math.min(1, t))
    for j = 1, #S-1 do if t <= S[j+1][1] then
        local f = (t-S[j][1])/(S[j+1][1]-S[j][1]); local a,b = S[j][2],S[j+1][2]
        return a[1]+(b[1]-a[1])*f, a[2]+(b[2]-a[2])*f, a[3]+(b[3]-a[3])*f
    end end; return C.pink[1],C.pink[2],C.pink[3]
end

local cache, ext, num_cores, frame = {}, nil, nil, 0
-- Network history for graphs
local net_hist_down, net_hist_up = {}, {}
local NET_HIST_LEN = 60

local function init_ext()
    if not ext then ext = cairo_text_extents_t:create()
        if tolua and tolua.takeownership then tolua.takeownership(ext) end end
end

local function txt(cr, s, x, y, font, sz, col, bold, align)
    if not s or s == "" then return 0 end
    cairo_select_font_face(cr, font, CAIRO_FONT_SLANT_NORMAL,
        bold and CAIRO_FONT_WEIGHT_BOLD or CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, sz)
    cairo_text_extents(cr, s, ext)
    local tx = x
    if align == "c" then tx = x - ext.width/2 - ext.x_bearing
    elseif align == "r" then tx = x - ext.width - ext.x_bearing end
    cairo_move_to(cr, tx, y)
    cairo_set_source_rgba(cr, col[1], col[2], col[3], col[4])
    cairo_show_text(cr, s); return ext.width
end

local function arc(cr, cx, cy, r, sd, ed, w, col)
    if sd >= ed then return end
    cairo_set_source_rgba(cr, col[1], col[2], col[3], col[4])
    cairo_set_line_width(cr, w); cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
    cairo_arc(cr, cx, cy, r, sd*math.pi/180, ed*math.pi/180); cairo_stroke(cr)
end

local function circ(cr, cx, cy, r, col)
    cairo_arc(cr, cx, cy, r, 0, 2*math.pi)
    cairo_set_source_rgba(cr, col[1], col[2], col[3], col[4]); cairo_fill(cr)
end

local function ln(cr, x1, y1, x2, y2, w, col)
    cairo_set_source_rgba(cr, col[1], col[2], col[3], col[4])
    cairo_set_line_width(cr, w); cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
    cairo_move_to(cr, x1, y1); cairo_line_to(cr, x2, y2); cairo_stroke(cr)
end

local function rrect(cr, x, y, w, h, r, col)
    cairo_new_path(cr)
    cairo_arc(cr, x+r,y+r,r,math.pi,1.5*math.pi); cairo_arc(cr, x+w-r,y+r,r,1.5*math.pi,2*math.pi)
    cairo_arc(cr, x+w-r,y+h-r,r,0,0.5*math.pi); cairo_arc(cr, x+r,y+h-r,r,0.5*math.pi,math.pi)
    cairo_close_path(cr); cairo_set_source_rgba(cr, col[1], col[2], col[3], col[4]); cairo_fill(cr)
end

-- Data
local function cnum(v) return tonumber(conky_parse(v)) or 0 end
local function cstr(v) return conky_parse(v) or "" end
local function ctrim(v) local s = cstr(v); return s:match("^%s*(.-)%s*$") or s end
local function stc(k, v) if not cache[k] then cache[k] = cstr(v) end; return cache[k] end

local function get_iface()
    if not cache._if then local f = io.popen("ip route get 1.1.1.1 2>/dev/null | head -1")
        cache._if = (f and f:read("*l") or ""):match("dev%s+(%S+)") or "eth0"
        if f then f:close() end end; return cache._if
end
local function get_cores()
    if not num_cores then local f = io.popen("nproc 2>/dev/null")
        num_cores = tonumber(f and f:read("*l")) or 4; if f then f:close() end end; return num_cores
end

local function read_kv(path, ck, ttl)
    if cache[ck] and cache[ck.."t"] and os.time()-cache[ck.."t"]<(ttl or 30) then return cache[ck] end
    local d,f = {},io.open(path,"r"); if not f then return nil end
    for l in f:lines() do local k,v=l:match("^([%w_]+)=(.+)$"); if k then d[k]=v end end
    f:close(); if not next(d) then return nil end; cache[ck]=d; cache[ck.."t"]=os.time(); return d
end
local function get_weather() return read_kv("/tmp/conky-weather.txt","_w") end
local function get_media()   return read_kv("/tmp/conky-media.txt","_m",1) end

local function get_calendar()
    if cache._cal and cache._ct and os.time()-cache._ct<30 then return cache._cal end
    local ev,f = {},io.open("/tmp/conky-calendar.txt","r")
    if not f then cache._cal=nil; cache._ct=os.time(); return nil end
    for l in f:lines() do
        if l=="NO_GCALCLI" then f:close(); cache._cal="NO_GCALCLI"; cache._ct=os.time(); return "NO_GCALCLI" end
        if l=="NO_EVENTS"  then f:close(); cache._cal="NO_EVENTS";  cache._ct=os.time(); return "NO_EVENTS" end
        if l~="" then local flds={}; for fld in (l.."\t"):gmatch("([^\t]*)\t") do flds[#flds+1]=fld end
            if #flds>=5 then ev[#ev+1]={date=flds[1], time=flds[2]~="" and flds[2] or "all day", title=flds[5]} end
        end
    end; f:close(); cache._cal=#ev>0 and ev or "NO_EVENTS"; cache._ct=os.time(); return cache._cal
end

local function get_disks()
    if cache._dk and cache._dkt and os.time()-cache._dkt<30 then return cache._dk end
    local dk,f = {},io.popen("df -h --output=target,fstype,size,used,pcent -x tmpfs -x devtmpfs -x udev -x efivarfs -x squashfs 2>/dev/null | tail -n+2")
    if f then for l in f:lines() do local m,_,sz,u,p=l:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%d+)%%")
        if m and m~="/boot/efi" and m~="/boot" then
            dk[#dk+1]={label=m:match("^/media/.+/(.+)$") or (m=="/" and "Root" or m), size=sz, used=u, pct=tonumber(p) or 0} end
    end; f:close() end; cache._dk=dk; cache._dkt=os.time(); return dk
end

local function get_vis(n)
    local f = io.open("/tmp/conky-cava.txt","r")
    if f then local l=f:read("*l"); f:close()
        if l and l~="" then local b={}; for v in l:gmatch("(%d+)") do b[#b+1]=tonumber(v); if #b>=n then break end end
            if #b>=n then return b end end end
    local t=frame*0.12; local media=get_media()
    local amp=(media and media.STATUS=="Playing") and 1.0 or 0.06
    local b={}; for i=1,n do local x=i/n
        b[i]=math.max(1,math.min(98,math.max(0.05,1-math.abs(x-0.45)*1.5)*amp*(
            30+24*math.sin(t+i*0.3)+16*math.sin(t*1.8+i*0.5)+12*math.cos(t*0.7+i*0.9))))
    end; return b
end

--- Parse net speed string to number (KB)
local function parse_speed(s)
    if not s or s == "" then return 0 end
    local n = tonumber(s:match("([%d%.]+)")) or 0
    if s:match("[Mm]") then n = n * 1024
    elseif s:match("[Gg]") then n = n * 1048576 end
    return n
end

--- Update network history
local function update_net_hist()
    local ifc = get_iface()
    cache._nsd_down = ctrim("${downspeed "..ifc.."}")
    cache._nsd_up   = ctrim("${upspeed "..ifc.."}")
    cache._nsd_td   = ctrim("${totaldown "..ifc.."}")
    cache._nsd_tu   = ctrim("${totalup "..ifc.."}")
    local d = parse_speed(cache._nsd_down)
    local u = parse_speed(cache._nsd_up)
    -- Only add to history once per second (frame % 5)
    if frame % 5 == 0 then
        net_hist_down[#net_hist_down+1] = d
        net_hist_up[#net_hist_up+1] = u
        while #net_hist_down > NET_HIST_LEN do table.remove(net_hist_down, 1) end
        while #net_hist_up   > NET_HIST_LEN do table.remove(net_hist_up, 1) end
    end
end

-- ======================================================================
-- COMPONENTS
-- ======================================================================

--- Ring gauge (no number inside, just the arc)
local function draw_ring(cr, cx, cy, r, w, pct, st, sp, col, s)
    local vs = st + (sp-st)*math.min(pct/100,1)
    arc(cr, cx, cy, r, st, sp, w, C.w05)
    if pct > 0 then
        arc(cr, cx, cy, r, st, vs, w+6*s, {col[1],col[2],col[3],0.06})
        arc(cr, cx, cy, r, st, vs, w, col)
        local ea = vs*math.pi/180
        circ(cr, cx+r*math.cos(ea), cy+r*math.sin(ea), w/2+1.5*s, col)
    end
end

--- Overlapping gauge cluster (bigger, no CPU number)
local function draw_cluster(cr, ox, oy, s)
    -- CPU: outer ring (LARGE)
    local cpu = cnum("${cpu cpu0}")
    draw_ring(cr, ox, oy, 240*s, 14*s, cpu, 150, 390, C.cyan, s)
    for i = 0, 8 do
        local a = (150+240*i/8)*math.pi/180; local r1,r2 = 240*s-18*s, 240*s-10*s
        ln(cr, ox+r1*math.cos(a),oy+r1*math.sin(a), ox+r2*math.cos(a),oy+r2*math.sin(a), 1*s, C.w10)
    end
    txt(cr, "CPU", ox, oy-10*s, SANS, 24*s, C.cyan, true, "c")

    -- Core dots
    local nc = get_cores(); local sh = math.min(nc, 16)
    for i = 1, sh do
        local ci = nc>16 and math.floor((i-1)*nc/sh)+1 or i
        local p = cnum("${cpu cpu"..ci.."}")
        local a = (150+240*((i-0.5)/sh))*math.pi/180
        circ(cr, ox+(240*s+22*s)*math.cos(a), oy+(240*s+22*s)*math.sin(a),
             4*s, {C.cyan[1],C.cyan[2],C.cyan[3], 0.06+0.94*p/100})
    end

    -- RAM: offset ring (LARGE)
    local ram = cnum("${memperc}")
    local rx, ry = ox+160*s, oy+180*s
    draw_ring(cr, rx, ry, 170*s, 12*s, ram, 160, 380, C.purple, s)
    txt(cr, string.format("%.0f%%", ram), rx, ry+6*s, MONO, 46*s, C.white, false, "c")
    txt(cr, "RAM", rx, ry+38*s, SANS, 18*s, C.purple, true, "c")
    local sw = cnum("${swapperc}")
    if sw > 0 then arc(cr, rx, ry, 135*s, 160, 160+220*math.min(sw/100,1), 3*s, {C.amber[1],C.amber[2],C.amber[3],0.5}) end

    -- GPU: ring (upper-right, LARGE)
    local gpu = cnum("${nvidia gpuutil}")
    local gx, gy = ox+280*s, oy-80*s
    draw_ring(cr, gx, gy, 110*s, 10*s, gpu, 180, 360, C.green, s)
    txt(cr, string.format("%.0f%%", gpu), gx, gy+6*s, MONO, 34*s, C.white, false, "c")
    txt(cr, "GPU", gx, gy+28*s, SANS, 16*s, C.green, true, "c")
end

--- Temperature gauges (BIGGER arcs)
local function draw_temps(cr, x, y, s)
    local ct = ctrim("${hwmon 4 temp 1}")
    local gt = ctrim("${nvidia gputemp}")
    local cpu_t = tonumber(ct) or 0
    local gpu_t = tonumber(gt) or 0

    local r = 60*s
    local col_cpu = cpu_t > 80 and C.coral or (cpu_t > 60 and C.amber or C.green)
    arc(cr, x, y, r, 180, 360, 7*s, C.w05)
    arc(cr, x, y, r, 180, 180+180*math.min(cpu_t/100,1), 7*s, col_cpu)
    txt(cr, ct.."°", x, y-14*s, MONO, 28*s, col_cpu, false, "c")
    txt(cr, "CPU", x, y+28*s, SANS, 15*s, C.w35, false, "c")

    local gx = x + 155*s
    local col_gpu = gpu_t > 80 and C.coral or (gpu_t > 60 and C.amber or C.green)
    arc(cr, gx, y, r, 180, 360, 7*s, C.w05)
    arc(cr, gx, y, r, 180, 180+180*math.min(gpu_t/100,1), 7*s, col_gpu)
    txt(cr, gt.."°", gx, y-14*s, MONO, 28*s, col_gpu, false, "c")
    txt(cr, "GPU", gx, y+28*s, SANS, 15*s, C.w35, false, "c")
end

--- Storage as gauge rings (BIGGER)
local function draw_storage_gauges(cr, x, y, s)
    local disks = get_disks()
    if not disks then return end
    local spacing = 150*s
    for i, d in ipairs(disks) do
        if i > 3 then break end
        local dx = x + (i-1)*spacing
        local r = 55*s
        local col = d.pct > 85 and C.coral or (d.pct > 65 and C.amber or C.green)
        arc(cr, dx, y, r, 135, 405, 8*s, C.w05)
        arc(cr, dx, y, r, 135, 135+270*d.pct/100, 8*s, col)
        txt(cr, d.pct.."%", dx, y+6*s, MONO, 22*s, C.white, false, "c")
        txt(cr, d.label, dx, y+r+22*s, SANS, 15*s, C.w50, false, "c")
        txt(cr, d.used.."/"..d.size, dx, y+r+40*s, MONO, 12*s, C.w35, false, "c")
    end
end

--- Network speed graph (area chart)
local function draw_net_graph(cr, x, y, gw, gh, hist, col, label, speed_str, s)
    -- Find max for scaling
    local mx = 1
    for _, v in ipairs(hist) do if v > mx then mx = v end end

    -- Draw as thin vertical bars (newest on right)
    if #hist > 0 then
        local bw = 3 * s
        local gap = 0.5 * s
        for i, v in ipairs(hist) do
            local idx = #hist - i  -- reverse: newest on right
            local bh = (v / mx) * gh
            if bh < 1 then bh = 1 end
            local bx = x + gw - (idx + 1) * (bw + gap)
            local by = y + gh - bh
            rrect(cr, bx, by, bw, bh, 1 * s, {col[1], col[2], col[3], 0.15 + 0.40 * (v / mx)})
        end
    end

    -- Label and speed
    txt(cr, label, x, y-8*s, SANS, 16*s, col, false, "l")
    txt(cr, speed_str, x+gw, y-8*s, MONO, 16*s, col, false, "r")
end

--- Clock (top-right corner with margins)
local function draw_clock(cr, rx, y, s)
    local hrs, mns = cstr("${time %H}"), cstr("${time %M}")
    local sec = tonumber(cstr("${time %S}")) or 0

    -- Large time
    txt(cr, hrs..":"..mns, rx, y, MONO, 190*s, C.white, false, "r")

    -- Seconds arc (small, separate from day)
    local sr = 18*s
    local sx, sy = rx - 510*s, y - 70*s
    arc(cr, sx, sy, sr, -90, 270, 1.5*s, C.w05)
    arc(cr, sx, sy, sr, -90, -90+sec/60*360, 2*s, {C.cyan[1],C.cyan[2],C.cyan[3],0.5})

    -- Date on line below
    local day_name = string.lower(cstr("${time %A}"))
    local day_num = cstr("${time %d}")
    local month = string.lower(cstr("${time %B}"))
    local year = cstr("${time %Y}")
    txt(cr, day_name.."  "..day_num.." "..month.." "..year, rx, y+48*s, SANS, 28*s, C.w50, false, "r")

    -- Weather
    local w = get_weather()
    if w and w.TEMP then
        txt(cr, w.TEMP.."°C  "..(w.DESC or "").."  Hum "..(w.HUMIDITY or "?").."%",
            rx, y+78*s, SANS, 22*s, C.amber, false, "r")
        -- Forecast
        for i = 1, 2 do
            local p = "F"..i.."_"
            local day = w[p.."DAY"] or ""
            if #day > 3 then day = day:sub(1,3) end
            txt(cr, day.."  "..(w[p.."MAX"] or "?").."/"..(w[p.."MIN"] or "?").."°  "..(w[p.."DESC"] or ""),
                rx, y+(78+30*i)*s, SANS, 18*s, C.w35, false, "r")
        end
    end
end

--- Calendar (floating, transparent, narrower, bigger font)
local function draw_calendar(cr, x, y, pw, ph, s)
    -- Accent left border only (no background panel)
    rrect(cr, x, y+10*s, 3*s, ph-20*s, 1.5*s, {C.pink[1],C.pink[2],C.pink[3],0.30})

    local p, gap = 20*s, 28*s
    local lx = x+p
    local ly = y + 30*s

    txt(cr, "CALENDAR", lx, ly, SANS, 22*s, C.pink, true, "l")
    ln(cr, lx, ly+14*s, lx+130*s, ly+14*s, 1*s, {C.pink[1],C.pink[2],C.pink[3],0.25})
    ly = ly + 42*s

    local cal = get_calendar()
    if cal == "NO_GCALCLI" or cal == nil then
        txt(cr, "pip install gcalcli", lx, ly, MONO, 18*s, C.w35, false, "l"); return end
    if cal == "NO_EVENTS" then
        txt(cr, "No upcoming events", lx, ly, MONO, 18*s, C.w35, false, "l"); return end

    local today = os.date("%Y-%m-%d")
    local tomorrow = os.date("%Y-%m-%d", os.time()+86400)
    local prev, ri = "", 0
    local max_ri = math.floor((ph-80*s)/gap)

    for _, ev in ipairs(cal) do
        if ri >= max_ri then break end
        local ry = ly + gap*ri
        if ev.date ~= prev then
            if ri > 0 then ri = ri+0.5; ry = ly+gap*ri end
            local dl
            if ev.date == today then dl = "Today"
            elseif ev.date == tomorrow then dl = "Tomorrow"
            else local y2,m2,d2 = ev.date:match("(%d+)-(%d+)-(%d+)")
                if y2 then dl = os.date("%A %d", os.time({year=tonumber(y2),month=tonumber(m2),day=tonumber(d2)}))
                else dl = ev.date end
            end
            circ(cr, lx-12*s, ry-5*s, 4*s, C.pink)
            txt(cr, dl, lx, ry, SANS, 20*s, C.pink, true, "l")
            prev = ev.date; ri = ri+1; ry = ly+gap*ri
        end
        local ts = ev.time=="all day" and "ALL DAY" or ev.time:sub(1,5)
        txt(cr, ts, lx, ry, MONO, 17*s, C.w50, false, "l")
        local title = ev.title or ""
        txt(cr, title, lx+90*s, ry, MONO, 16*s, C.w70, false, "l")
        ri = ri+1
    end
end

--- Top processes (floating, cached at 2s)
local function draw_procs(cr, x, y, s)
    -- Cache process data every 2 seconds
    if not cache._procs or not cache._procs_t or os.time() - cache._procs_t >= 2 then
        local p = {}
        for i = 1, 12 do
            local name = ctrim("${top name "..i.."}")
            if name ~= "" then
                p[#p+1] = { name=name, cpu=ctrim("${top cpu "..i.."}"), mem=ctrim("${top mem "..i.."}") }
            end
        end
        cache._procs = p; cache._procs_t = os.time()
    end

    local gap = 22*s
    txt(cr, "PROCESSES", x, y, SANS, 22*s, C.cyan, true, "l")
    ln(cr, x, y+14*s, x+140*s, y+14*s, 1*s, {C.cyan[1],C.cyan[2],C.cyan[3],0.2})
    local ly = y + 42*s

    txt(cr, "NAME", x, ly, MONO, 14*s, C.w35, false, "l")
    txt(cr, "CPU", x+240*s, ly, MONO, 14*s, C.w35, false, "r")
    txt(cr, "MEM", x+310*s, ly, MONO, 14*s, C.w35, false, "r")
    ly = ly + gap

    for i, p in ipairs(cache._procs or {}) do
        txt(cr, p.name, x, ly+gap*(i-1), MONO, 16*s, C.w50, false, "l")
        txt(cr, p.cpu.."%", x+240*s, ly+gap*(i-1), MONO, 16*s, C.cyan, false, "r")
        txt(cr, p.mem.."%", x+310*s, ly+gap*(i-1), MONO, 16*s, C.purple, false, "r")
    end
end

--- Now Playing + compact visualizer
local function draw_np_vis(cr, x, y, vis_w, s)
    local media = get_media()
    local playing = media and media.STATUS == "Playing"
    local paused  = media and media.STATUS == "Paused"

    -- Status dot
    if playing then circ(cr, x, y, 5*s, C.green); circ(cr, x, y, 12*s, {C.green[1],C.green[2],C.green[3],0.06})
    elseif paused then circ(cr, x, y, 5*s, C.amber)
    else circ(cr, x, y, 4*s, C.w10) end

    if media and media.TITLE and media.TITLE ~= "" then
        local t = media.TITLE; if #t>55 then t=t:sub(1,53)..".." end
        txt(cr, t, x+22*s, y+6*s, SANS, 17*s, C.white, false, "l")
        if media.ARTIST and media.ARTIST ~= "" then
            txt(cr, media.ARTIST, x+22*s, y+28*s, SANS, 14*s, C.w50, false, "l")
        end
    else txt(cr, "No media playing", x+22*s, y+6*s, SANS, 15*s, C.w35, false, "l") end

    -- Rainbow visualizer below (taller, more bars)
    local vy = y + 45*s
    local vh = 90*s
    local nb = 64
    local bars = get_vis(nb)
    local bg2 = 2*s; local bw = (vis_w-bg2*(nb-1))/nb

    for i, val in ipairs(bars) do
        local bh = vh*val/100
        local bx = x + (i-1)*(bw+bg2)
        local by = vy+vh-bh
        local r,g,b = rainbow((i-1)/(nb-1))
        local a = playing and (0.40+0.60*val/100) or (paused and 0.10 or 0.03)
        rrect(cr, bx, by, bw, bh, 1.5*s, {r,g,b,a})
        -- Reflection
        rrect(cr, bx, vy+vh+2*s, bw, bh*0.15, 1*s, {r,g,b,a*0.06})
    end
end

--- Decorations
local function draw_deco(cr, w, h, s)
    local m, cl = 22*s, 18*s
    for _, c in ipairs({{m,m},{w-m,m},{m,h-m},{w-m,h-m}}) do
        local sx = c[1]<w/2 and 1 or -1; local sy = c[2]<h/2 and 1 or -1
        ln(cr, c[1],c[2], c[1]+cl*sx,c[2], 1*s, C.w10)
        ln(cr, c[1],c[2], c[1],c[2]+cl*sy, 1*s, C.w10)
    end
    circ(cr, w*0.50, h*0.12, 30*s, {C.cyan[1],C.cyan[2],C.cyan[3],0.012})
    circ(cr, w*0.85, h*0.70, 22*s, {C.purple[1],C.purple[2],C.purple[3],0.012})
end

-- ======================================================================
-- MAIN
-- ======================================================================
function conky_main()
    if conky_window == nil then return end
    local w, h = conky_window.width, conky_window.height
    if w < 200 or h < 200 then return end
    local s = w / 3840
    frame = frame + 1
    init_ext()

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, w, h)
    local cr = cairo_create(cs)

    local margin = w * 0.06
    local r_margin = w * 0.04

    update_net_hist()

    draw_deco(cr, w, h, s)

    -- ── Clock (top-right with margin) ──
    -- Clock right-aligned with calendar right edge
    local cal_right = w - w*0.06
    draw_clock(cr, cal_right, h*0.13, s)

    -- ── Gauge cluster (left, big) ──
    draw_cluster(cr, w*0.14, h*0.25, s)

    -- ── Temperature gauges (below cluster) ──
    draw_temps(cr, w*0.08, h*0.56, s)

    -- ── Storage gauges (next to temps) ──
    draw_storage_gauges(cr, w*0.24, h*0.56, s)

    -- ── Network graphs (below temps/storage) ──
    local ifc = get_iface()
    local ng_x, ng_y = margin, h*0.65
    local ng_w = w*0.28
    local nd = cache._nsd_down or ctrim("${downspeed "..ifc.."}")
    local nu = cache._nsd_up   or ctrim("${upspeed "..ifc.."}")
    local ntd = cache._nsd_td  or ctrim("${totaldown "..ifc.."}")
    local ntu = cache._nsd_tu  or ctrim("${totalup "..ifc.."}")
    draw_net_graph(cr, ng_x, ng_y, ng_w, 45*s, net_hist_down, C.green, "DOWNLOAD", nd, s)
    txt(cr, "Total "..ntd, ng_x+ng_w+12*s, ng_y+35*s, MONO, 16*s, C.w35, false, "l")
    draw_net_graph(cr, ng_x, ng_y+65*s, ng_w, 45*s, net_hist_up, C.coral, "UPLOAD", nu, s)
    txt(cr, "Total "..ntu, ng_x+ng_w+12*s, ng_y+100*s, MONO, 16*s, C.w35, false, "l")

    -- ── Calendar (right side) ──
    local cal_w = w*0.14
    local cal_h = h*0.55
    local cal_x = w - w*0.06 - cal_w
    draw_calendar(cr, cal_x, h*0.38, cal_w, cal_h, s)

    -- ── Processes (next to gauge cluster) ──
    draw_procs(cr, w*0.28, h*0.22, s)

    -- ── Now Playing + Visualizer (bottom-left) ──
    draw_np_vis(cr, margin, h*0.84, w*0.22, s)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
