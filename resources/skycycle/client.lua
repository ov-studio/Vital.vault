----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: client.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Dynamic sky, weather and surface weather ]]--
----------------------------------------------------------------


local cfg  = SkyConfig
local sin, cos, floor = util.math.sin, util.math.cos, util.math.floor
local PI = util.math.pi
local function rad(d) return d * PI / 180.0 end

-----------------
--[[ Helpers ]]--
-----------------
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function smoothstep(a, b, x) local t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t) end
local function lerp3(a, b, t) return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) } end
local function norm(v) local l = util.math.sqrt(v[1]*v[1] + v[2]*v[2] + v[3]*v[3]); if l < 1e-6 then return {0,1,0} end return { v[1]/l, v[2]/l, v[3]/l } end
local function cross(a, b) return { a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3], a[1]*b[2]-a[2]*b[1] } end
local function dot(a, b) return a[1]*b[1] + a[2]*b[2] + a[3]*b[3] end

-- Rodrigues rotation of v around unit axis by ang
local function rotate(v, axis, ang)
    local c, s, k = cos(ang), sin(ang), dot(axis, v) * (1 - cos(ang))
    local x = cross(axis, v)
    return { v[1]*c + x[1]*s + axis[1]*k, v[2]*c + x[2]*s + axis[2]*k, v[3]*c + x[3]*s + axis[3]*k }
end

---------------
--[[ State ]]--
---------------
local S = {
    time     = cfg.start_time,
    day      = 0,
    scale    = 1.0,
    weather  = cfg.default_weather,
    cur      = { coverage = 0.45, density = 0.004, type = 0.75, dark = 0.0, desat = 0.0, haze = 0.0,
                 rain = 0.0, snow = 0.0, fog = 0.0, wind = 1.0, lightning = 0.0, tr = 1.0, tg = 1.0, tb = 1.0 },  -- blended weather
    flash    = 0.0,             -- lightning flash 0..1
    base     = nil,             -- blended preset values before the manual multipliers (see S.over)
    wdir     = nil,             -- smoothed wind direction {x, z}
    wdir_t   = nil,             -- wind direction target
    bolt_cd  = 4.0,
    seed     = 12345,
    precip   = cfg.use_precipitation,
    wind     = { 0, 0, 0 },
    cloud_t  = 0.0,
    quality  = cfg.quality,
    clouds = true,
    sun_deg  = cfg.sun_radius_deg,
    moon_deg = cfg.moon_radius_deg,
    moon_phase_manual = nil,    -- set by the moon_phase command / the set_moon_phase export (nil = automatic)
    shader   = nil,
    snow_shader = nil, cshader = nil,   -- rain / snow particle shaders, surface weather shader
    snow_car = nil,                    -- particle emitters
    flt = 0.0,
    over = {},                                     -- manual weather overrides: rain, snow, wind, fog, lightning
    cover = 0.0, wet = 0.0, cover_manual = nil, cover_on = false,
    fog_on   = nil,      -- unknown until the first frame, so the level's own fog is switched off when the weather has none
    light    = nil,
    enabled  = true,
}

local WRAP = 5.0e6
S.base = {}
for k, v in pairs(S.cur) do S.base[k] = v end
S.wdir   = { cfg.wind_dir[1], cfg.wind_dir[2] }
S.wdir_t = { cfg.wind_dir[1], cfg.wind_dir[2] }

-- tiny deterministic PRNG (0..1), so we do not depend on a random() in the sandbox
local function rnd() S.seed = (S.seed * 1664525 + 1013904223) % 4294967296; return S.seed / 4294967296 end

----------------------------
--[[ Timecycle sampling ]]--
----------------------------
local FIELDS3 = { "zenith", "horizon", "ground", "glow", "sun_color", "light", "ambient_top", "ambient_bottom" }
local FIELDS1 = { "glow_strength", "light_energy", "stars", "exposure" }

local function sample_timecycle(hour)
    local tc = cfg.timecycle
    local a, b = tc[1], tc[#tc]
    for i = 1, #tc - 1 do
        if hour >= tc[i].hour and hour <= tc[i + 1].hour then a, b = tc[i], tc[i + 1]; break end
    end
    local span = b.hour - a.hour
    local t = span > 0 and (hour - a.hour) / span or 0
    t = t * t * (3 - 2 * t)
    local out = {}
    for _, f in ipairs(FIELDS3) do out[f] = lerp3(a[1][f], b[1][f], t) end
    for _, f in ipairs(FIELDS1) do out[f] = lerp(a[1][f], b[1][f], t) end
    return out
end

-----------------------------
--[[ Celestial positions ]]--
-----------------------------
local function celestial(hour, day)
    local tilt = cfg.sun_tilt_deg * PI / 180
    local axis = { 0, -sin(tilt), cos(tilt) }                   -- rotation axis of the sky
    local a = (hour - 6.0) / 24.0 * 2 * PI                      -- 0 = east horizon (06:00)
    local sun = rotate({ 1, 0, 0 }, axis, a)

    local phase = S.moon_phase_manual
    if phase == nil then
        phase = cfg.moon_phase
        if cfg.moon_phase_cycle then phase = (phase + day / 29.5) % 1.0 end
    end
    S.phase = phase
    -- the moon trails the sun's apparent motion: waxing moon (phase 0..0.5) sits EAST of the sun
    -- (earlier in the sky's east-to-west rotation), so it is highest at sunset around first quarter
    local elong = phase * 2 * PI                                -- 0 new, 0.25 first quarter, 0.5 full
    local moon = rotate({ 1, 0, 0 }, axis, a - elong)
    moon = norm({ moon[1] + axis[1] * 0.09, moon[2] + axis[2] * 0.09, moon[3] + axis[3] * 0.09 })
    return norm(sun), moon, axis, a
end

------------------------------------------
--[[ Init: shader, light, environment ]]--
------------------------------------------
local function aim_light(l, dir)
    -- light travels away from the sun / moon
    local up = (util.math.abs(dir[2]) > 0.98) and { 0, 0, 1 } or { 0, 1, 0 }
    l:look_at_from_position({ 0, 0, 0 }, { -dir[1] * 10, -dir[2] * 10, -dir[3] * 10 }, up)
end


-- Bloom: the sun disc is rendered HDR, so the engine's own glow (gfx.glow) blooms it. The glow works on the finished
-- picture, so geometry in front of the sun hides it and only the exposed part of the disc blooms (blurred over the edges).
-- The threshold is above normal scene brightness so nothing else lights up.
local function apply_glow(on)
    if not gfx.glow then return end
    pcall(function()
        gfx.glow.set_enabled(on)
        if not on then return end
        gfx.glow.set_hdr_bleed_threshold(cfg.glow_threshold)
        gfx.glow.set_hdr_bleed_scale(cfg.glow_scale)
        gfx.glow.set_hdr_luminance_cap(cfg.glow_cap)
        gfx.glow.set_intensity(cfg.glow_intensity)
        gfx.glow.set_strength(cfg.glow_strength)
        gfx.glow.set_bloom(0.0)
        gfx.glow.set_normalized(true)
        gfx.glow.set_blend_mode(gfx.glow.blend_mode.ADDITIVE)
        local lv = cfg.glow_levels
        for i = 1, #lv do gfx.glow.set_level_intensity(i - 1, lv[i]) end
    end)
end

local RIP_LIFE = 1.2      -- seconds a ripple lasts
local RIP_RADIUS = 0.35   -- metres: half size of one ring
local RIP_DEPTH = 64.0    -- metres covered by the depth channel of the ripple buffer (ripple_ring.gdshader)

-- rain and snow share this: the carrier emitter shows more or fewer particles in 8 steps (changing the amount restarts
-- the pool, so only step changes do it) and the shader's density smooths between the steps. Returns the density for
-- the shader, or nil (carrier hidden) when there is none.
local function precip_level(car, key, full, inten, on)
    local steps = 8.0
    local lvl = on and util.math.min(steps, floor(inten * steps) + 1) or 0
    if lvl <= 0 then
        if S[key] ~= 0 then S[key] = 0; pcall(function() car:set_visible(false); car:stop() end) end   -- a hidden emitter must not keep simulating
        return nil
    end
    if S[key] ~= lvl then
        S[key] = lvl
        pcall(function()
            car:set_amount(util.math.max(40, floor(full * lvl / steps)))
            car:set_visible(true)
            car:emit()
        end)
    end
    return clamp(inten * steps / lvl, 0.0, 1.0) ^ 0.8
end

-- the ripple buffer: a 3D rendertarget (a fraction of the screen, same aspect) that only sees the ring emitter. It is made
-- when the rain starts and rebuilt if the window changes size. A 3D rendertarget renders the world a second time every
-- frame, so it only exists while it rains.
local function ripple_buffer_free()
    local rt = S.rrt
    if not rt then return end
    S.rrt = nil
    pcall(function()
        S.cshader:set_param("screen_rip_on", 0.0)
        S.gpu_rip:set_visible(false)
        S.gpu_rip:set_layer()
        rt:destroy()
    end)
end

local function ripple_buffer()
    local res = core.display.get_resolution()
    local rx, ry = res[1] or res.x, res[2] or res.y
    if not (rx and ry and ry > 0) then return end
    if S.rrt and util.math.abs(rx - S.rrt_rx) <= 2 and util.math.abs(ry - S.rrt_ry) <= 2 then return end
    ripple_buffer_free()
    local div = cfg.ripple_rt_div
    local ok, err = pcall(function()
        local rt = core.rendertarget.create({ util.math.max(64, floor(rx / div)), util.math.max(64, floor(ry / div)) }, true, true)
        S.gpu_rip:set_layer(rt)
        S.gpu_rip:set_visible(true)
        S.cshader:set_param("screen_rip", rt)
        S.cshader:set_param("screen_rip_on", 1.0)
        S.rrt = rt
    end)
    S.rrt_rx, S.rrt_ry = rx, ry
    if not ok then
        core.engine.print("warn", "[dynamic_sky] ripple buffer unavailable, using procedural ripples: " .. tostring(err))
        S.rip_hook, S.rrt = false, nil
        S.cshader:set_param("screen_rip_on", 0.0)
        pcall(function() S.gpu_rip:set_visible(false) end)
    end
end

local function init()
    local shader = core.shader.create("shaders/sky.gdshader", core.shader.shader_mode.POST_PROCESS)
    if not shader then
        core.engine.print("error", "[dynamic_sky] sky shader failed to compile")
        S.enabled = false
        return
    end
    S.glow = cfg.use_engine_glow
    S.shader = shader
    if S.glow then apply_glow(true) end

    -- baked cloud noise (see tools/bake_cloud_noise.py), sampled instead of computing noise per pixel
    local ok, img = pcall(core.image.create, "textures/cloud_noise.png", true)
    if ok and img then
        S.noise = img                                   -- keep a reference alive
    else
        core.engine.print("error", "[dynamic_sky] textures/cloud_noise.png could not be loaded, clouds disabled")
    end

    -- world-space rain / snow particles + surface weather shader (all optional: the sky works without them)
    local function mk_shader(path)
        local ok, sh = pcall(core.shader.create, path, core.shader.shader_mode.SPATIAL)
        if ok and sh then return sh end
        core.engine.print("warn", "[dynamic_sky] " .. path .. " failed to compile")
        return nil
    end
    -- rain: real falling drops that collide with the world (they vanish on roofs and ground, so nothing rains indoors);
    -- every drop that lands spawns a small droplet burst through a sub-emitter. Needs the engine's particle collision API.
    S.rays = cfg.use_godrays
    S.splash_on = cfg.use_splash
    S.gpu_on = false
    if cfg.use_precipitation then
        local ok, err = pcall(function()
            local rr = mk_shader("shaders/rain_fall.gdshader")
            if not rr then error("shaders/rain_fall.gdshader failed to compile") end
            -- ripples exactly where each drop lands: the droplets spawn a flat ring emitter that is drawn into a screen-space buffer
            -- (needs particle:set_layer). Without it the puddles use procedural ripples.
            local ring_sh = cfg.use_surface_weather and mk_shader("shaders/ripple_ring.gdshader") or nil
            S.sdrop = (S.splash_on or ring_sh) and mk_shader("shaders/splash_drop.gdshader") or nil
            if not particle.gpu.set_world_collision then error("particle.gpu.set_world_collision is missing") end
            local life = 3.6
            S.gpu_rate = cfg.rain_real_rate
            S.gpu_full = floor(S.gpu_rate * life)
            S.gpu_burst = cfg.splash_gpu_burst
            S.rrshader = rr
            -- enough droplet slots for EVERY landing: landings per second x droplets per landing x droplet lifetime (+25%).
            -- A full budget silently drops new splashes, which looks like drops that hit the ground without splashing
            local sub = particle.gpu.create()                         -- the droplets: the engine spawns them where a drop lands
            sub:set_amount(util.math.max(cfg.splash_gpu_amount, floor(S.gpu_rate * S.gpu_burst * 0.46 * 1.25) + 16))
            sub:set_lifetime(0.46)
            sub:set_one_shot(false)
            sub:set_explosiveness(0.0)
            sub:set_randomness(0.6)
            sub:set_local_coords(false)
            sub:set_direction({ 0, 1, 0 })
            sub:set_spread(62)
            sub:set_gravity({ 0, -9.8, 0 })
            sub:set_param(particle.gpu.param.VELOCITY, 0.7, 3.0)
            sub:set_visibility_aabb({ -30, -10, -30 }, { 60, 40, 60 })
            if S.sdrop then sub:set_material(S.sdrop) end
            pcall(sub.set_fixed_fps, sub, 0)                          -- simulate every frame, not at 30 fps
            sub:set_visible(true)
            local rip = ring_sh and particle.gpu.create()                 -- one ring per droplet: stands still where it was spawned
            if rip and not rip.set_layer then rip:destroy(); rip = nil end
            if rip then
                rip:set_amount(floor(S.gpu_rate * S.gpu_burst * RIP_LIFE * 1.25) + 16)
                rip:set_lifetime(RIP_LIFE)
                rip:set_one_shot(false)
                rip:set_explosiveness(0.0)
                rip:set_randomness(0.0)
                rip:set_local_coords(false)
                rip:set_gravity({ 0, 0, 0 })
                rip:set_param(particle.gpu.param.VELOCITY, 0.0, 0.0)
                rip:set_visibility_aabb({ -30, -10, -30 }, { 60, 40, 60 })
                rip:set_material(ring_sh)
                ring_sh:set_param("ring_radius", RIP_RADIUS)
                ring_sh:set_param("share", 1.0 / S.gpu_burst)
                ring_sh:set_param("depth_scale", RIP_DEPTH)
                pcall(rip.set_fixed_fps, rip, 0)
                rip:set_visible(false)                                -- shown once its rendertarget exists (see ripple_buffer)
                sub:set_sub_emitter(rip, particle.gpu.sub_emitter_mode.AT_START, 1)
                S.gpu_rip = rip
            end
            local car = particle.gpu.create()                         -- the rain: real falling drops drawn by rain_fall.gdshader
            car:set_amount(S.gpu_full)
            car:set_lifetime(life)
            car:set_one_shot(false)
            car:set_explosiveness(0.0)
            car:set_randomness(0.0)
            car:set_local_coords(false)
            car:set_emission_shape(particle.gpu.emission_shape.BOX, { 17.0, 0.2, 17.0 })
            car:set_direction({ 0, -1, 0 })
            car:set_spread(0)
            car:set_gravity({ 0, 0, 0 })
            car:set_material(rr)
            car:set_visibility_aabb({ -30, -30, -30 }, { 60, 60, 60 })
            car:set_collision(particle.gpu.collision_mode.HIDE, 0.0, 1.0)
            if S.splash_on or rip then car:set_sub_emitter(sub, particle.gpu.sub_emitter_mode.AT_COLLISION, S.gpu_burst) end
            -- the rain simulates every frame: at the default 30 fps a drop falling 13 m/s moves 0.4 m per step and is only noticed
            -- below the surface, so its splash would start under the floor
            pcall(car.set_fixed_fps, car, 0)
            car:set_visible(false)
            S.gpu_sub, S.gpu_car, S.gpu_lvl = sub, car, -1
        end)
        S.gpu_on = ok
        if ok then core.engine.print("info", "[dynamic_sky] rain active (real colliding drops, splashes = " .. (S.splash_on and "on" or "off") .. ")") end
        if not ok then core.engine.print("warn", "[dynamic_sky] rain needs the engine with the particle collision API: " .. tostring(err)) end
    end
    -- snow: real falling flakes that collide with the world (they vanish on roofs and ground, nothing snows indoors)
    S.snow_on, S.snow_lvl = false, -1
    if cfg.use_precipitation then
        local sh = mk_shader("shaders/snow_fall.gdshader")
        if sh then
            local ok, err = pcall(function()
                local life = cfg.snow_life
                S.snow_rate = cfg.snow_rate
                S.snow_full = floor(S.snow_rate * life)
                local car = particle.gpu.create()
                car:set_amount(S.snow_full)
                car:set_lifetime(life)
                car:set_one_shot(false)
                car:set_explosiveness(0.0)
                car:set_randomness(0.0)
                car:set_local_coords(false)
                car:set_emission_shape(particle.gpu.emission_shape.BOX, { 17.0, 0.2, 17.0 })
                car:set_direction({ 0, -1, 0 })
                car:set_spread(0)
                car:set_gravity({ 0, 0, 0 })
                car:set_visibility_aabb({ -30, -30, -30 }, { 60, 60, 60 })
                car:set_material(sh)
                pcall(car.set_collision, car, particle.gpu.collision_mode.HIDE, 0.0, 1.0)      -- older engines: flakes just fall through
                car:set_visible(false)
                S.snow_car, S.snow_shader = car, sh
            end)
            S.snow_on = ok
            if not ok then core.engine.print("warn", "[dynamic_sky] snow particles unavailable: " .. tostring(err)) end
        end
    end
    if cfg.use_surface_weather then S.cshader = mk_shader("shaders/snow_cover.gdshader") end

    S.rip_hook = S.gpu_rip ~= nil and S.cshader ~= nil              -- ripples from the landed drops (else procedural ripples in the puddle layer)
    if S.cshader then
        S.cshader:set_param("ripple_gain", cfg.ripple_gain)
        S.cshader:set_param("screen_rip_depth", RIP_DEPTH)
        S.cshader:set_param("screen_rip_gamma", cfg.ripple_buffer_gamma)
    end

    -- NASA LROC moon colour map
    S.moon = core.image.create("textures/moon.png", true)       -- keep a reference so the texture is not freed while the shader uses it
    shader:set_param("moon_tex", S.moon)

    if cfg.control_environment then
        gfx.sky.set_mode(gfx.sky.sky_mode.PROCEDURAL)
        gfx.env.set_background_mode(gfx.env.background_mode.SKY)
        gfx.env.set_ambient_source(gfx.env.ambient_source.SKY)
        gfx.env.set_reflection_source(gfx.env.reflection_source.SKY)
        gfx.sky.procedural.set_sun_angle_max(0.0)
    end

    if cfg.control_light then
        S.light = light.directional.create()
        S.light:set_position({ 0, 5, 0 })
        S.light:set_shadow_enabled(cfg.shadows)
        S.light:set_sky_mode(light.directional.sky_mode.LIGHT_ONLY) -- our shader draws the sun disc
    end
    core.engine.print("info", "[dynamic_sky] sky shader created")
end

-------------------
--[[ Per frame ]]--
-------------------
local function update(dt)
    if not S.enabled or not S.shader then return end
    local sh = S.shader
    local csh = S.cloud_sh                                  -- the low resolution cloud pass uses the same cloud values
    local function cset(name, v)                           -- cloud values: only the cloud pass uses them
        if csh then csh:set_param(name, v) end
    end

    -- local clock (corrected by server syncs)
    if cfg.day_length_min > 0 and S.scale > 0 then
        S.time = S.time + dt * S.scale * (24.0 / (cfg.day_length_min * 60.0))
        if S.time >= 24 then S.time = S.time - 24; S.day = S.day + 1 end
    end

    -- weather blending
    local target = cfg.weather[S.weather] or cfg.weather.partly
    local k = clamp(dt * cfg.weather_blend_per_sec, 0, 1)
    local tint = target.tint or { 1.0, 1.0, 1.0 }
    local want = { rain = 0.0, snow = 0.0, fog = 0.0, wind = 1.0, lightning = 0.0, haze = 0.0,
                   tr = tint[1], tg = tint[2], tb = tint[3] }
    for key, v in pairs(target) do if key ~= "tint" then want[key] = v end end
    -- every key blends, so a key a preset does not mention returns to its neutral value
    for key, v in pairs(want) do S.base[key] = lerp(S.base[key], v, k) end
    -- effective values = blended preset + manual intensity (sky_rain / sky_snow / sky_fog / sky_lightning set the level
    -- reached WHILE the weather has that phenomenon, so clear weather still stops it; sky_wind is a multiplier)
    for key, v in pairs(S.base) do S.cur[key] = v end
    for key, v in pairs(S.over) do
        if key == "wind" then S.cur.wind = S.base.wind * v
        else S.cur[key] = v * clamp(S.base[key] / 0.3, 0.0, 1.0) end
    end

    -- wind / cloud evolution accumulate (changing the speed never makes clouds jump)
    do
        local kd = clamp(dt * 0.6, 0, 1)
        S.wdir[1] = lerp(S.wdir[1], S.wdir_t[1], kd); S.wdir[2] = lerp(S.wdir[2], S.wdir_t[2], kd)
    end
    local wd = norm({ S.wdir[1], 0, S.wdir[2] })
    for i = 1, 3 do S.wind[i] = (S.wind[i] + wd[i] * cfg.wind_speed * S.cur.wind * dt) % WRAP end
    S.cloud_t = (S.cloud_t + dt) % WRAP

    local tc = sample_timecycle(S.time)

    -- weather tints the whole sky: overcast greys it out and pulls the zenith toward the horizon
    -- colour (flat, bright, low contrast), storms darken it, haze washes out the horizon
    do
        local ds, dk = S.cur.desat, S.cur.dark
        local function grey_out(c, amt, dim)
            local l = c[1] * 0.2126 + c[2] * 0.7152 + c[3] * 0.0722
            local g = 1.0 - dim
            return { lerp(c[1], l, amt) * g, lerp(c[2], l, amt) * g, lerp(c[3], l, amt) * g }
        end
        tc.zenith = grey_out(lerp3(tc.zenith, tc.horizon, ds * 0.75), ds, dk * 0.55)
        local milk = clamp(tc.light_energy, 0, 1.2) * 0.38          -- haze colour follows daylight
        tc.horizon = grey_out(lerp3(tc.horizon, { milk, milk * 1.04, milk * 1.10 }, clamp(S.cur.haze * 0.35, 0.0, 0.85)), ds * 0.8, dk * 0.45)
        tc.ambient_top = grey_out(tc.ambient_top, ds * 0.7, 0)
        tc.glow_strength = tc.glow_strength * (1.0 - ds * 0.7)
        -- coloured air (sandstorm, smog, snow-light): multiply the sky and the light by the weather tint
        local tr, tg, tb = S.cur.tr, S.cur.tg, S.cur.tb
        local function tinted(c3, amt) return { lerp(c3[1], c3[1] * tr, amt), lerp(c3[2], c3[2] * tg, amt), lerp(c3[3], c3[3] * tb, amt) } end
        tc.zenith, tc.horizon, tc.ambient_top, tc.ambient_bottom = tinted(tc.zenith, 1.0), tinted(tc.horizon, 1.0), tinted(tc.ambient_top, 1.0), tinted(tc.ambient_bottom, 1.0)
        tc.glow, tc.light, tc.sun_color = tinted(tc.glow, 1.0), tinted(tc.light, 0.8), tinted(tc.sun_color, 0.8)
    end

    -- lightning: a real strike is a quick flicker of strokes (dim leader, one or two bright return strokes, a few
    -- weaker restrikes ~40-120 ms apart) followed by a slower afterglow while the cloud is lit from inside.
    -- Now and then it is a close strike (very bright, loud) and sometimes only distant sheet lightning (dim, wide).
    if S.cur.lightning > 0.3 then
        S.bolt_cd = S.bolt_cd - dt
        if S.bolt_cd <= 0 then
            local kind = rnd()
            local power = kind < 0.14 and 1.55 or (kind < 0.72 and (0.95 + 0.2 * rnd()) or (0.40 + 0.2 * rnd()))   -- close / normal / distant
            local n = 2 + util.math.floor(rnd() * 4.0)                      -- 2..5 strokes
            local t = 0.0
            S.strokes, S.stroke_t = {}, 0.0
            for i = 1, n do
                local amp
                if i == 1 then amp = power * (0.35 + 0.2 * rnd())             -- stepped leader
                elseif i == 2 then amp = power                                  -- main return stroke
                else amp = power * (0.35 + 0.5 * rnd()) end                     -- restrikes
                S.strokes[#S.strokes + 1] = { t = t, a = amp }
                t = t + 0.04 + 0.09 * rnd()
            end
            S.after_peak = power
            S.bolt_cd = (2.5 + rnd() * 9.0) / S.cur.lightning
        end
    end
    if S.strokes and #S.strokes > 0 then
        S.stroke_t = (S.stroke_t or 0.0) + dt
        local i = 1
        while i <= #S.strokes do
            if S.stroke_t >= S.strokes[i].t then
                S.fast = util.math.max(S.fast or 0.0, S.strokes[i].a)
                S.after = util.math.max(S.after or 0.0, (S.after_peak or 1.0) * 0.55)
                util.table.remove(S.strokes, i)
            else
                i = i + 1
            end
        end
        if #S.strokes == 0 then S.strokes, S.stroke_t = nil, 0.0 end
    end
    if not S.strokes then S.stroke_t = 0.0 end
    S.fast  = (S.fast or 0.0) * (0.00002 ^ dt)       -- each stroke dies in ~40 ms
    S.after = (S.after or 0.0) * (0.12 ^ dt)         -- the cloud glows for about a second
    if S.fast < 0.01 then S.fast = 0.0 end
    if S.after < 0.01 then S.after = 0.0 end
    S.flash = util.math.max(S.flash * (0.0004 ^ dt), 0.0)           -- manual skyFlash() decays on its own
    if S.flash < 0.01 then S.flash = 0.0 end
    local fl_boost = cfg.lightning_intensity
    local FL = S.flash + (S.fast + 0.32 * S.after) * fl_boost        -- effective flash used everywhere below (can exceed 1)
    local sun, moon, axis, ang = celestial(S.time, S.day)

    -- key light: sun by day, moon by night
    local day_w = smoothstep(-0.10, 0.14, sun[2])
    local key_dir = norm({
        lerp(moon[1], sun[1], day_w), lerp(moon[2], sun[2], day_w), lerp(moon[3], sun[3], day_w) })
    local dark = 1.0 - S.cur.dark
    local sun_energy = tc.light_energy * dark
    local moon_up = smoothstep(-0.05, 0.2, moon[2])
    local night_energy = cfg.night_light.energy * moon_up * (1.0 - day_w)

    local cloud_light = {
        tc.light[1] * sun_energy * 1.6 * day_w + cfg.night_light.color[1] * night_energy * 2.0,
        tc.light[2] * sun_energy * 1.6 * day_w + cfg.night_light.color[2] * night_energy * 2.0,
        tc.light[3] * sun_energy * 1.6 * day_w + cfg.night_light.color[3] * night_energy * 2.0,
    }
    local grey = 1.0 - S.cur.dark * 0.55          -- storm clouds look flatter / darker
    local q = cfg.qualities[S.quality] or cfg.qualities.medium

    -- shader uniforms
    sh:set_param("sun_dir", sun)
    sh:set_param("moon_dir", moon)
    sh:set_param("sun_size", rad(S.sun_deg))
    sh:set_param("moon_size", rad(S.moon_deg))
    sh:set_param("star_axis", axis)
    sh:set_param("star_angle", ang)
    sh:set_param("zenith_color", tc.zenith)
    sh:set_param("horizon_color", tc.horizon)
    cset("horizon_color", tc.horizon)
    sh:set_param("ground_color", tc.ground)
    sh:set_param("glow_color", tc.glow)
    sh:set_param("glow_strength", tc.glow_strength * dark)
    sh:set_param("horizon_falloff", util.math.max(3.5 - S.cur.haze * 1.6, 0.8))       -- haze widens the bright horizon band
    cset("haze_density", 0.000012 * (1.0 + S.cur.haze * 5.0))
    sh:set_param("sun_color", tc.sun_color)
    -- sunlight colour after travelling through the atmosphere (Kasten-Young air mass + Rayleigh-ish
    -- per-channel extinction): warm white high up, yellow, orange, then deep red at the horizon.
    -- haze/dust makes the path "longer", so hazy weather gives redder suns.
    do
        local sy = clamp(sun[2], 0.0, 1.0)
        local hrad = sy + sy * sy * sy / 6.0 + 0.075 * sy ^ 5          -- asin() without needing it
        local hdeg = hrad * 180.0 / PI
        local am = 1.0 / (sy + 0.50572 * (hdeg + 6.07995) ^ -1.6364) * (1.0 + 0.5 * S.cur.haze)
        local r, g, b = 2.718281828 ^ (-0.055 * am), 2.718281828 ^ (-0.105 * am), 2.718281828 ^ (-0.245 * am)
        local m = util.math.max(r, util.math.max(g, b))
        r, g, b = r / m * S.cur.tr, g / m * S.cur.tg, b / m * S.cur.tb
        m = util.math.max(r, util.math.max(g, b))
        sh:set_param("sun_phys", { r / m, g / m, b / m })
        S.sun_rgb = { r / m, g / m, b / m }
    end
    sh:set_param("sun_intensity", 25.0 * dark)
    sh:set_param("sun_hdr", cfg.sun_hdr)

    -- god rays: strongest with a low sun and some haze, gone under heavy overcast, at night and in precipitation
    do
        local el = sun[2]
        local low = 1.0 - smoothstep(0.2, 0.8, el)                      -- low sun = stronger shafts
        local up = smoothstep(-0.02, 0.10, el)
        local cloudy = 1.0 - clamp(S.cur.dark * 1.6, 0.0, 1.0)
        local precip = 1.0 - clamp(S.cur.rain * 0.8 + S.cur.snow * 0.5, 0.0, 0.9)
        local amt = S.rays and cfg.godray_strength * up * cloudy * precip * (0.65 + 0.35 * low) * (0.8 + 0.4 * clamp(S.cur.haze, 0.0, 1.0)) or 0.0
        local rc = S.sun_rgb or { 1.0, 0.88, 0.65 }
        sh:set_param("ray_color", { rc[1], rc[2] * 0.97, rc[3] * 0.85 })
        sh:set_param("ray_strength", clamp(amt, 0.0, 1.5))
        sh:set_param("ray_decay", 0.955 + 0.02 * low)
    end
    sh:set_param("moon_color", cfg.night_light.color)
    sh:set_param("star_visibility", tc.stars * (1.0 - S.cur.dark * 0.7))
    sh:set_param("exposure", tc.exposure * cfg.exposure * (1.0 + FL * 1.7))


    cset("light_dir", key_dir)
    cset("light_color", cloud_light)
    -- night: clouds still catch scattered moon / sky glow, so an overcast or rainy night is dim grey-blue, not pitch black
    local ng = cfg.night_cloud_glow
    local nk = clamp(tc.stars, 0.0, 1.0) * (0.35 + 0.65 * S.cur.dark)
    cset("cloud_ambient_top", { tc.ambient_top[1] * grey + ng[1] * nk + FL * 2.2, tc.ambient_top[2] * grey + ng[2] * nk + FL * 2.4, tc.ambient_top[3] * grey + ng[3] * nk + FL * 3.2 })
    cset("cloud_ambient_bottom", { tc.ambient_bottom[1] + ng[1] * nk * 0.6, tc.ambient_bottom[2] + ng[2] * nk * 0.6, tc.ambient_bottom[3] + ng[3] * nk * 0.6 })

    local coverage = (S.clouds and S.noise) and S.cur.coverage or 0.0
    sh:set_param("cloud_coverage", coverage)
    cset("cloud_coverage", coverage)
    cset("cloud_density", S.cur.density)
    cset("cloud_type", S.cur.type)
    cset("cloud_base", cfg.cloud_base)
    cset("cloud_thickness", cfg.cloud_thickness)
    cset("cloud_scale", cfg.cloud_scale)
    cset("cloud_detail", cfg.cloud_detail)
    cset("cloud_steps", q.steps)
    cset("cloud_light_steps", q.light)
    cset("wind_offset", S.wind)
    cset("cloud_time", S.cloud_t)

    -- real scene light + ambient
    if S.light then
        aim_light(S.light, key_dir)
        local lc = lerp3(cfg.night_light.color, tc.light, day_w)
        S.light:set_color({ lc[1], lc[2], lc[3], 1.0 })
        S.light:set_energy(sun_energy * day_w + night_energy * 3.0 + FL * 4.5)
    end
    if cfg.control_environment then
        local t, h, g = tc.ambient_top, tc.horizon, tc.ground
        -- shadow fill: lift the ambient by a daylight-scaled floor so shaded areas never go black
        -- (sky light bounces around; at sunset the sky colours alone are too dim for that)
        local fl = cfg.ambient_floor * clamp(tc.light_energy, 0.0, 1.0) ^ 0.5
        local nw = clamp(1.0 - clamp(tc.light_energy * 1.5, 0.0, 1.0) * (1.0 - clamp(tc.stars, 0.0, 1.0)), 0.0, 1.0)     -- 0 by day .. 1 at night, rising through twilight
        fl = fl + cfg.night_ambient_floor * nw     -- night: shadowed ground is dark blue, not pure black
        local fc = cfg.ambient_floor_color
        local function lift(c3, k) return { c3[1] + fc[1] * fl * k, c3[2] + fc[2] * fl * k, c3[3] + fc[3] * fl * k } end
        local t2, h2, g2 = lift(t, 1.0), lift(h, 0.8), lift(g, 0.7)
        gfx.sky.procedural.set_sky_top_color({ t2[1], t2[2], t2[3], 1.0 })
        gfx.sky.procedural.set_sky_horizon_color({ h2[1] * 0.8 * grey, h2[2] * 0.8 * grey, h2[3] * 0.8 * grey, 1.0 })
        gfx.sky.procedural.set_ground_horizon_color({ h2[1] * 0.6, h2[2] * 0.6, h2[3] * 0.6, 1.0 })
        gfx.sky.procedural.set_ground_bottom_color({ g2[1], g2[2], g2[3], 1.0 })
        gfx.env.set_ambient_energy(cfg.ambient_energy * (1.0 + cfg.night_ambient_boost * nw) * (1.0 + FL * 2.4))
    end

    -- scene fog from the weather (fog, rain, blizzard, sandstorm ...)
    if cfg.use_fog and gfx.fog then
        local fg = S.cur.fog
        local want = fg > 0.01
        if want ~= S.fog_on then
            pcall(gfx.fog.set_enabled, want)
            if want then pcall(gfx.fog.set_sky_affect, 0.0) end     -- our sky shader does its own haze
            S.fog_on = want
        end
        if want then
            -- the horizon colour already carries the time of day (dark blue at night), so it is used as is
            local h = tc.horizon
            local k = 0.85 * (1.0 - 0.35 * S.cur.dark)
            local fc = { h[1] * k, h[2] * k, h[3] * k }
            pcall(gfx.fog.set_density, fg * cfg.fog_density_max)
            pcall(gfx.fog.set_light_color, { fc[1], fc[2], fc[3], 1.0 })
            pcall(gfx.fog.set_light_energy, 1.0 + FL * 3.2)
        end
    end

    -- ---------------- world-space precipitation ----------------
    local cam = core.camera.get_active()
    local cpos = nil
    if cam then
        local ok, p = pcall(cam.get_global_position, cam)
        if ok and type(p) == "table" then cpos = p end
    end
    local daylight = clamp(0.10 + 0.80 * clamp(tc.light_energy, 0.0, 1.0) ^ 0.7, 0.08, 1.0) * (1.0 + FL * 3.0)
    local ph = tc.horizon
    local pmx = util.math.max(ph[1], util.math.max(ph[2], util.math.max(ph[3], 1e-3)))
    local pr, pg, pb = lerp(ph[1] / pmx, 1.0, 0.45), lerp(ph[2] / pmx, 1.0, 0.45), lerp(ph[3] / pmx, 1.0, 0.45)
    local gust = 1.0 + 0.25 * sin(S.cloud_t * 0.35) * sin(S.cloud_t * 0.113 + 1.7)
    local wmps = S.cur.wind * cfg.rain_wind_mps * gust          -- horizontal speed of the falling precipitation
    local wx, wz = wd[1] * wmps, wd[3] * wmps
    local R, SN = S.cur.rain, S.cur.snow
    local rfall = { wx * (0.75 + 0.5 * R), -(8.5 + 9.5 * R ^ 0.9), wz * (0.75 + 0.5 * R) }
    local rtint = { pr * daylight, pg * daylight, pb * daylight, (0.15 - 0.05 * clamp(R, 0, 1)) * cfg.rain_opacity }
    S.flt = (S.flt + dt) % 50.26548
    if S.snow_on then
        local car, sh = S.snow_car, S.snow_shader
        local dens = precip_level(car, "snow_lvl", S.snow_full, SN, S.precip and cpos ~= nil and SN > 0.02)
        if dens then
            local fx, fy, fz = wx * 0.85, -(0.9 + 0.7 * SN), wz * 0.85
            local fl = util.math.sqrt(fx * fx + fy * fy + fz * fz)
            pcall(function()
                car:set_global_position({ cpos[1], cpos[2] + 12.0, cpos[3] })
                car:set_direction({ fx / fl, fy / fl, fz / fl })
                car:set_param(particle.gpu.param.VELOCITY, fl * 0.8, fl * 1.2)
            end)
            -- flake colour against the open sky: the scene's colour (horizon tint), kept bright at night so flakes are not dark specks;
            -- in front of scenery the shader takes the colour of what is behind (the ground snow) instead
            local lf = 0.55 + 0.4 * clamp(daylight, 0.0, 1.0)
            sh:set_param("fall_vel", { fx, fy, fz })
            sh:set_param("flake_size", cfg.snow_size)
            sh:set_param("flutter_t", S.flt)
            sh:set_param("sway", 0.45 / (1.0 + util.math.max(S.cur.wind - 1.0, 0.0) * 0.6))
            sh:set_param("density", dens)
            sh:set_param("tint", { lerp(pr, 1.0, 0.6) * lf, lerp(pg, 1.0, 0.6) * lf, lerp(pb, 1.0, 0.6) * lf, 0.85 })
        end
    end

    -- ---------------- rain: real drops, the amount follows the weather ----------------
    if S.gpu_on then
        local stint = { pr * daylight, pg * daylight, pb * daylight, S.splash_on and (0.30 + 0.45 * clamp(R, 0, 1)) * cfg.splash_opacity or 0.0 }   -- same colour source as the rain
        if S.sdrop then S.sdrop:set_param("tint", stint) end
        local snowk = (S.cur.snow > 0.2) and (1.0 - clamp(S.cur.snow, 0.0, 1.0)) or 1.0
        local reff = clamp(R * snowk, 0.0, 1.0)
        local car = S.gpu_car
        local dens = precip_level(car, "gpu_lvl", S.gpu_full, reff, S.precip and cpos ~= nil and reff > 0.02)
        if dens then
            local fx, fy, fz = rfall[1], rfall[2], rfall[3]
            local fl = util.math.sqrt(fx * fx + fy * fy + fz * fz)
            pcall(function()
                car:set_global_position({ cpos[1], cpos[2] + 14.0, cpos[3] })
                S.gpu_sub:set_global_position({ cpos[1], cpos[2], cpos[3] })       -- their culling box follows the camera too
                if S.rip_hook then
                    S.gpu_rip:set_global_position({ cpos[1], cpos[2], cpos[3] })
                    ripple_buffer()
                end
                car:set_direction({ fx / fl, fy / fl, fz / fl })
                car:set_param(particle.gpu.param.VELOCITY, fl * 0.75, fl * 1.25)
            end)
            local sh = S.rrshader
            sh:set_param("fall_vel", { fx, fy, fz })
            sh:set_param("density", dens)
            sh:set_param("tint", rtint)
            sh:set_param("streak_len", 0.55 + 0.55 * R)
            sh:set_param("streak_w", 0.007 + 0.006 * R)
        end
    end

    -- no rain for a moment (the last rings have faded): drop the ripple buffer
    if S.rip_hook and S.rrt then
        S.rrt_idle = (S.gpu_lvl or 0) > 0 and 0.0 or (S.rrt_idle or 0.0) + dt
        if S.rrt_idle > RIP_LIFE + 1.0 then ripple_buffer_free() end
    end

    -- the world collider re-renders the level from above every time it moves, so it only exists while rain or snow is falling
    -- (and a few seconds after, for the last particles in the air)
    do
        local need = (S.gpu_lvl or 0) > 0 or (S.snow_lvl or 0) > 0
        S.col_idle = need and 0.0 or (S.col_idle or 0.0) + dt
        local want = need or S.col_idle < 8.0
        if want ~= (S.col_on or false) and particle.gpu.set_world_collision then
            S.col_on = want
            pcall(particle.gpu.set_world_collision, want, { 48, 60, 48 }, cfg.splash_gpu_res)
        end
    end

    -- ---------------- surface weather: snow settles / melts, ground gets wet ----------------
    if S.cshader then
        if S.cover_manual then
            S.cover = lerp(S.cover, S.cover_manual, clamp(dt * 1.5, 0, 1))
        else
            local up = cfg.snow_accum_sec
            local down = cfg.snow_melt_sec
            if SN > 0.2 then S.cover = util.math.min(1.0, S.cover + dt / up * SN)
            else S.cover = util.math.max(0.0, S.cover - dt / down * (1.0 + R * 3.0)) end
        end
        if R > 0.05 and S.cover < 0.3 then S.wet = util.math.min(1.0, S.wet + dt / 25.0 * R)
        else S.wet = util.math.max(0.0, S.wet - dt / (S.cover > 0.3 and 20.0 or cfg.dry_time)) end

        local active = (S.cover > 0.004 or S.wet > 0.01)
        if active ~= S.cover_on then
            S.cover_on = active
            if active then pcall(S.cshader.apply_to_material, S.cshader, "*", "*", "*", 0, true)   -- layered: drawn on top of the level's own materials
            else pcall(S.cshader.remove_from_material, S.cshader, "*", "*", "*") end
        end
        if active then
            S.cshader:set_param("snow_amount", S.cover)
            S.cshader:set_param("wet", S.wet)
            S.cshader:set_param("rain_amt", clamp(R, 0.0, 1.0))
            S.cshader:set_param("puddle_gloss", cfg.puddle_gloss)
            S.cshader:set_param("puddle_strength", cfg.puddle_strength)
            S.cshader:set_param("wet_fade_start", cfg.wet_fade_start)
            S.cshader:set_param("wet_fade_end", cfg.wet_fade_end)
            S.cshader:set_param("alpha_cut", cfg.surface_alpha_cut)
            -- light the ripples pick up from the sky (independent of sun/moon): horizon + ambient colour, with a night floor
            do
                local g, f = cfg.ripple_glow, 0.015 + FL * 0.8
                local h, a = tc.horizon, tc.ambient_top
                -- mostly the horizon colour: that is what a flat water surface mirrors at a grazing angle
                S.cshader:set_param("ripple_light", { (h[1] * 0.85 + a[1] * 0.15 + f * 0.8) * g, (h[2] * 0.85 + a[2] * 0.15 + f * 0.9) * g, (h[3] * 0.85 + a[3] * 0.15 + f * 1.2) * g })
            end
        end
    end
end

util.event.on("sandbox:process", update)

-- clouds: the volumetric clouds are marched into a small rendertarget (a fraction of the screen), blurred with two cheap
-- passes (horizontal, vertical) and sky.gdshader reads the result with one texture fetch per pixel.
-- The rendertargets are hdr (16 bit float): the cloud light is above 1 and 8 bits would band.
local function cloud_setup(rx, ry)
    local div = cfg.cloud_rt_div
    local w, h = util.math.max(64, util.math.floor(rx / div)), util.math.max(64, util.math.floor(ry / div))
    local ok, err = pcall(function()
        local mode = core.shader.shader_mode.CANVAS_ITEM
        if not S.cloud_sh then
            S.cloud_sh = core.shader.create("shaders/cloud_pass.gdshader", mode)
            S.cblur_h = core.shader.create("shaders/cloud_blur.gdshader", mode)
            S.cblur_v = core.shader.create("shaders/cloud_blur.gdshader", mode)
            if not (S.cloud_sh and S.cblur_h and S.cblur_v) then error("cloud shaders failed to compile") end
            S.cloud_sh:set_param("noise_tex", S.noise)
        end
        -- a resize makes new rendertargets, the old ones are freed
        for _, rt in ipairs({ S.crt_a or false, S.crt_b or false, S.crt_c or false }) do
            if rt then pcall(rt.destroy, rt) end
        end
        -- every rendertarget gets ONE draw per frame: it is rendered once, with everything drawn to it
        S.crt_a = core.rendertarget.create({ w, h }, true, true)
        S.crt_b = core.rendertarget.create({ w, h }, true, true)
        S.crt_c = core.rendertarget.create({ w, h }, true, true)
        if not S.crt_a:is_hdr() then error("needs the engine with hdr rendertargets (core.rendertarget.create third parameter)") end
        S.cblur_h:set_param("src", S.crt_a)
        S.cblur_h:set_param("step_uv", { 1.0 / w, 0.0 })
        S.cblur_v:set_param("src", S.crt_b)
        S.cblur_v:set_param("step_uv", { 0.0, 1.0 / h })
        S.shader:set_param("cloud_tex", cfg.cloud_blur and S.crt_c or S.crt_a)
        S.crt_w, S.crt_h, S.crt_rx, S.crt_ry = w, h, rx, ry
    end)
    if not ok then
        S.cloud_failed = true
        core.engine.print("error", "[dynamic_sky] clouds unavailable: " .. tostring(err))
    end
    return ok
end

local function vec3_of(v)
    return { v[1] or v.x, v[2] or v.y, v[3] or v.z }
end

local function cloud_pass()
    if not (S.enabled and S.shader and S.noise) or S.cloud_failed then return end
    local cam = core.camera.get_active()
    if not cam then return end
    local res = core.display.get_resolution()
    local rx, ry = res[1] or res.x, res[2] or res.y
    if not (rx and ry and ry > 0) then return end
    if not S.crt_a or util.math.abs(rx - S.crt_rx) > 2 or util.math.abs(ry - S.crt_ry) > 2 then
        if not cloud_setup(rx, ry) then return end
    end

    local ok, tr = pcall(cam.get_transform, cam)
    local okp, pos = pcall(cam.get_global_position, cam)
    local okf, fov = pcall(cam.get_fov, cam)
    if not (ok and okp and okf and type(tr) == "table" and tr.basis and type(pos) == "table" and type(fov) == "number") then return end
    local bx, by, bz = vec3_of(tr.basis.x), vec3_of(tr.basis.y), vec3_of(tr.basis.z)
    local okk, keep = pcall(cam.get_keep_aspect, cam)
    local t = util.math.tan(util.math.rad(fov) * 0.5)
    local aspect = rx / ry
    local tx, ty = t * aspect, t                            -- the field of view is vertical by default (keep height)
    if okk and keep == 0 then tx, ty = t, t / aspect end    -- keep width

    -- looking far down: no pixel of the screen can show sky, so nothing to march
    local pitch = util.math.asin(clamp(-bz[2], -1.0, 1.0))
    if pitch + util.math.atan(util.math.sqrt(tx * tx + ty * ty)) < -0.01 then return end

    local cs = S.cloud_sh
    cs:set_param("cam_x", bx)
    cs:set_param("cam_y", by)
    cs:set_param("cam_z", bz)
    cs:set_param("cam_pos", pos)
    cs:set_param("tan_xy", { tx, ty })

    local size = { S.crt_w, S.crt_h }
    core.rendertarget.set_active(S.crt_a, true)
    core.engine.draw_material({ 0, 0 }, size, cs, 0, { 0, 0 }, { 1, 1, 1, 1 })
    core.rendertarget.set_active(nil)
    if cfg.cloud_blur then
        core.rendertarget.set_active(S.crt_b, true)
        core.engine.draw_material({ 0, 0 }, size, S.cblur_h, 0, { 0, 0 }, { 1, 1, 1, 1 })
        core.rendertarget.set_active(nil)
        core.rendertarget.set_active(S.crt_c, true)
        core.engine.draw_material({ 0, 0 }, size, S.cblur_v, 0, { 0, 0 }, { 1, 1, 1, 1 })
        core.rendertarget.set_active(nil)
    end
end

-- draw the sky quad (same mechanism as a post process effect)
util.event.on("sandbox:draw", function()
    cloud_pass()
    if not S.enabled or not S.shader then return end
    local res = core.display.get_resolution()
    core.engine.draw_material({ 0, 0 }, res, S.shader, 0, { 0, 0 }, { 1, 1, 1, 1 })
end)

---------------------
--[[ Server sync ]]--
---------------------
util.event.on("dynamic_sky:sync", function(time, day, scale, weather)
    S.time, S.day, S.scale = time, day, scale
    if cfg.weather[weather] then S.weather = weather end
end)

----------------------------------------------------
--[[ Console commands (forwarded to the server) ]]--
----------------------------------------------------
local function request(kind, value) util.event.emit("dynamic_sky:request", { remote = true }, kind, value) end

-- time 18.5   or   time 18:30
util.input.register("time", function(args)
    local a = args[1]
    if not a then return core.engine.print("info", util.string.format("[dynamic_sky] time %.2f, weather %s", S.time, S.weather)) end
    local h, m = tostring(a):match("^(%d+):(%d+)$")
    local v = h and (tonumber(h) + tonumber(m) / 60) or tonumber(a)
    if not v then return core.engine.print("warn", "Usage: time <hour 0-24 | HH:MM>") end
    request("time", v)
end)

util.input.register("weather", function(args)
    if not args[1] or not cfg.weather[args[1]] then
        local names = {}
        for n in pairs(cfg.weather) do names[#names + 1] = n end
        return core.engine.print("warn", "Usage: weather <" .. util.table.concat(names, "|") .. ">")
    end
    request("weather", args[1])
end)

util.input.register("timescale", function(args)
    if not tonumber(args[1]) then return core.engine.print("warn", "Usage: timescale <multiplier, 0 = freeze>") end
    request("timescale", tonumber(args[1]))
end)

-- sky_quality low|medium|high|ultra   (client side, fps vs. cloud quality)
util.input.register("sky_quality", function(args)
    if not cfg.qualities[args[1] or ""] then return core.engine.print("warn", "Usage: sky_quality <low|medium|high|ultra>") end
    S.quality = args[1]
    core.engine.print("info", "[dynamic_sky] cloud quality", S.quality)
end)

-- sky_clouds on|off : toggle the clouds (no argument = flip)
util.input.register("sky_clouds", function(args)
    local m = args[1]
    if m == "on" then S.clouds = true elseif m == "off" then S.clouds = false else S.clouds = not S.clouds end
    core.engine.print("info", "[dynamic_sky] clouds:", S.clouds and "on" or "off")
end)

-- sun_size / moon_size <deg> : apparent radius of the sun / moon (glow scales with it)
local function set_sun_size(deg)
    deg = tonumber(deg); if not deg then return false end
    S.sun_deg = clamp(deg, 0.05, 15.0); return true
end
local function set_moon_size(deg)
    deg = tonumber(deg); if not deg then return false end
    S.moon_deg = clamp(deg, 0.05, 15.0); return true
end

util.input.register("sun_size", function(args)
    if not set_sun_size(args[1]) then
        return core.engine.print("info", util.string.format("[dynamic_sky] sun radius %.2f deg (usage: sun_size <0.05-15>, real sun 0.27)", S.sun_deg))
    end
    core.engine.print("info", util.string.format("[dynamic_sky] sun radius %.2f deg", S.sun_deg))
end)
util.input.register("moon_size", function(args)
    if not set_moon_size(args[1]) then
        return core.engine.print("info", util.string.format("[dynamic_sky] moon radius %.2f deg (usage: moon_size <0.05-15>, real moon 0.26)", S.moon_deg))
    end
    core.engine.print("info", util.string.format("[dynamic_sky] moon radius %.2f deg", S.moon_deg))
end)

-- moon phase ----------------------------------------------------------
local PHASES = {
    { "new_moon", 0.0 }, { "waxing_crescent", 0.125 }, { "first_quarter", 0.25 }, { "waxing_gibbous", 0.375 },
    { "full_moon", 0.5 }, { "waning_gibbous", 0.625 }, { "last_quarter", 0.75 }, { "waning_crescent", 0.875 },
}
local function phase_name(p) return PHASES[(floor((p % 1.0) * 8 + 0.5) % 8) + 1][1] end
local function phase_lit(p) return (1.0 - cos(p * 2 * PI)) * 0.5 end

local function set_moon_phase(v)
    if v == nil or v == "auto" then S.moon_phase_manual = nil; return true end
    local n = tonumber(v)
    if not n then
        local key = tostring(v):lower():gsub("[%s%-]", "_")
        for _, e in ipairs(PHASES) do
            if e[1] == key or e[1] == key .. "_moon" or e[1]:gsub("_moon", "") == key then n = e[2] end
        end
        if key == "full" then n = 0.5 elseif key == "new" then n = 0.0 end
    end
    if not n then return false end
    S.moon_phase_manual = n % 1.0
    return true
end

-- moon_phase                      show the current phase
-- moon_phase full | new | first_quarter | last_quarter | waxing_crescent | waxing_gibbous | waning_gibbous | waning_crescent
-- moon_phase 0.0-1.0              0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter
-- moon_phase auto                 follow the 29.5 day cycle again
local function cmd_moon_phase(args)
    if args[1] and not set_moon_phase(args[1]) then
        return core.engine.print("warn", "Usage: moon_phase <new|waxing_crescent|first_quarter|waxing_gibbous|full|waning_gibbous|last_quarter|waning_crescent|0-1|auto>")
    end
    local p = S.phase or cfg.moon_phase
    core.engine.print("info", util.string.format("[dynamic_sky] moon: %s, %d%% lit%s", phase_name(p), floor(phase_lit(p) * 100 + 0.5), S.moon_phase_manual and " (manual)" or " (auto cycle)"))
end
util.input.register("moon_phase", cmd_moon_phase)

-- sky_precip on|off : toggle the rain / snow particles (no argument = flip)
util.input.register("sky_precip", function(args)
    local m = args[1]
    if m == "on" then S.precip = true elseif m == "off" then S.precip = false else S.precip = not S.precip end
    core.engine.print("info", "[dynamic_sky] precipitation particles:", S.precip and "on" or "off")
end)

-- snowcover <0..1 | auto> : force how much snow lies on surfaces (auto = follows the weather)
local function cmd_snow_cover(args)
    local a = args[1]
    if not a then return core.engine.print("info", util.string.format("[dynamic_sky] snow cover %.2f, wet %.2f%s", S.cover, S.wet, S.cover_manual and " (manual)" or " (auto)")) end
    if a == "auto" then S.cover_manual = nil
    else
        local v = tonumber(a)
        if not v then return core.engine.print("warn", "Usage: snow_cover <0..1 | auto>") end
        S.cover_manual = clamp(v, 0.0, 1.0)
    end
    core.engine.print("info", "[dynamic_sky] snow cover:", S.cover_manual or "auto")
end
util.input.register("snow_cover", cmd_snow_cover)

-- sky_rain / sky_snow / sky_fog / sky_wind / sky_lightning <value | auto>
-- rain, snow, fog, lightning: 0..1 level reached WHILE the weather has it (clear weather still has none); wind: multiplier, 1 = preset
local function make_override(cmd, key, lo, hi)
    util.input.register(cmd, function(args)
        local a = args[1]
        if not a then return core.engine.print("info", util.string.format("[dynamic_sky] %s = %.2f%s", key, S.cur[key], S.over[key] and " (manual)" or " (auto)")) end
        if a == "auto" then S.over[key] = nil
        else
            local v = tonumber(a)
            if not v then return core.engine.print("warn", "Usage: " .. cmd .. " <" .. lo .. ".." .. hi .. " | auto>") end
            S.over[key] = clamp(v, lo, hi)
        end
        core.engine.print("info", "[dynamic_sky] " .. key .. ":", S.over[key] or "auto")
    end)
    util.export.register("set_" .. key, function(v) S.over[key] = tonumber(v) and clamp(tonumber(v), lo, hi) or nil end)
end
make_override("sky_rain", "rain", 0, 1)
make_override("sky_snow", "snow", 0, 1)
make_override("sky_fog", "fog", 0, 1)
make_override("sky_wind", "wind", 0, 6)

-- sky_winddir <deg>: direction the wind blows TOWARDS (0 = +Z, 90 = +X, 180 = -Z, 270 = -X); rain, snow and clouds follow
util.input.register("sky_winddir", function(args)
    local deg = tonumber(args[1])
    if not deg then
        return core.engine.print("info", util.string.format("[dynamic_sky] wind blows towards (%.2f, %.2f)", S.wdir_t[1], S.wdir_t[2]))
    end
    S.wdir_t = { sin(rad(deg)), cos(rad(deg)) }
    core.engine.print("info", "[dynamic_sky] wind direction:", deg, "deg")
end)
util.export.register("set_wind_dir", function(deg) deg = tonumber(deg) or 0; S.wdir_t = { sin(rad(deg)), cos(rad(deg)) } end)
make_override("sky_lightning", "lightning", 0, 1)

-- sky_glow [on|off] : bloom around the sun (uses the engine glow)
util.input.register("sky_glow", function(args)
    local m = args[1]
    S.glow = (m == "on") and true or ((m == "off") and false or not S.glow)
    apply_glow(S.glow)
    core.engine.print("info", "[dynamic_sky] sun bloom:", S.glow and "on" or "off")
end)

-- sky_godrays [on|off] : crepuscular rays through gaps in trees / buildings
util.input.register("sky_godrays", function(args)
    local m = args[1]
    S.rays = (m == "on") and true or ((m == "off") and false or not S.rays)
    core.engine.print("info", "[dynamic_sky] god rays:", S.rays and "on" or "off")
end)

-- sky_splash [on|off] : droplet splashes where rain hits the ground
util.input.register("sky_splash", function(args)
    local m = args[1]
    if not S.gpu_on then return core.engine.print("warn", "[dynamic_sky] rain is not active (needs the engine with the particle collision API)") end
    S.splash_on = (m == "on") and true or ((m == "off") and false or not S.splash_on)
    if not S.rip_hook then                                                     -- with the ripple hook the droplets keep spawning (the rings hang on them), they just stay invisible
        pcall(function()
            if S.splash_on then S.gpu_car:set_sub_emitter(S.gpu_sub, particle.gpu.sub_emitter_mode.AT_COLLISION, S.gpu_burst)
            else S.gpu_car:reset_sub_emitter() end
        end)
    end
    core.engine.print("info", "[dynamic_sky] rain splashes:", S.splash_on and "on" or "off")
end)

-- sky_toggle: switch the whole sky shader on/off
util.input.register("sky_toggle", function()
    S.enabled = not S.enabled
    core.engine.print("info", "[dynamic_sky] enabled:", S.enabled)
end)

init()

-----------------
--[[ Exports ]]--
-----------------

util.export.register("toggle", function() S.enabled = not S.enabled end)
util.export.register("get_time", function() return S.time end)
util.export.register("get_weather", function() return S.weather end)
util.export.register("set_snow_cover", function(v) S.cover_manual = tonumber(v) and clamp(tonumber(v), 0.0, 1.0) or nil end)
util.export.register("flash", function(v) S.flash = clamp(tonumber(v) or 1.0, 0.0, 1.0) end)     -- trigger a lightning flash by hand
util.export.register("set_sun_size", set_sun_size)                  -- apparent radius in deg
util.export.register("set_moon_size", set_moon_size)
util.export.register("set_moon_phase", set_moon_phase)              -- 0..1, a phase name, or nil/"auto"
util.export.register("get_moon_phase", function() return S.phase or cfg.moon_phase, phase_name(S.phase or cfg.moon_phase) end)
