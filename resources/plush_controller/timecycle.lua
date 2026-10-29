----------------------------------------------------------------
--  Resource: timecycle
--  Script: timecycle.lua
--  Author: ov-studio / custom
--  Desc: Cinematic day/night cycle (directional light + procedural sky)
--
--  Console:
--    time / time 5 30 / daylength 600 / cycle [on|off] / sunyaw 45
----------------------------------------------------------------


local m_sin   = util.math.sin
local m_asin  = util.math.asin
local m_deg   = util.math.deg
local m_floor = util.math.floor
local m_abs   = util.math.abs
local m_pi    = util.math.pi


--------------------------------------------------
-- Config — polished cinematic mix
--------------------------------------------------

local TimeCycle = {
    time_of_day      = 12.0,
    day_length_sec   = 1200.0,
    auto_cycle       = true,

    sun_energy_day   = 1.12,
    sun_energy_night = 0.035,  -- a bit darker night
    sun_yaw          = 28.0,

    -- Warm daylight, rich golden hour, soft moon blue
    color_noon       = {0.95, 0.97, 1.00, 1.0},  -- cool / slight blue tint
    color_sunrise    = {1.00, 0.50, 0.26, 1.0},
    color_sunset     = {1.00, 0.36, 0.14, 1.0},
    color_night      = {0.28, 0.38, 0.72, 1.0},

    -- Clean sky blues / deeper night navy
    sky_top_day      = {0.22, 0.50, 0.92, 1.0},  -- clearer blue
    sky_horizon_day  = {0.62, 0.78, 0.95, 1.0},  -- cooler horizon
    sky_top_night    = {0.012, 0.02, 0.055, 1.0},
    sky_horizon_night= {0.035, 0.05, 0.11, 1.0},
    ground_day       = {0.14, 0.15, 0.16, 1.0},
    ground_night     = {0.012, 0.015, 0.03, 1.0},

    ambient_day      = 0.26,
    ambient_night    = 0.09,   -- darker fill, still readable

    sky_energy_day   = 0.92,
    sky_energy_night = 0.18,

    tonemap_exposure = 0.96,
    tonemap_white    = 5.5,

    sun = nil,
}


--------------------------------------------------
-- Helpers
--------------------------------------------------

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerp4(c1, c2, t)
    return {
        lerp(c1[1], c2[1], t),
        lerp(c1[2], c2[2], t),
        lerp(c1[3], c2[3], t),
        lerp(c1[4] or 1, c2[4] or 1, t),
    }
end

local function smooth(t)
    t = clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

-- Smoother ease for long transitions
local function smoother(t)
    t = clamp(t, 0, 1)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

local function to_hm(tod)
    local h = m_floor(tod) % 24
    local m = m_floor((tod - m_floor(tod)) * 60 + 0.5) % 60
    return h, m
end

local function format_time(tod)
    local h, m = to_hm(tod)
    return util.string.format("%02d:%02d", h, m)
end


--------------------------------------------------
-- Curves
--------------------------------------------------

local function sun_elevation(tod)
    local ang = (tod / 24.0) * m_pi * 2.0 - m_pi * 0.5
    local elev = m_deg(m_asin(clamp(m_sin(ang), -1, 1)))
    if elev < 0 then
        elev = elev * 0.60
    end
    return elev
end

local function day_factor(elev)
    -- Soft rise around horizon, full by mid-morning
    local d = smoother((elev + 6.0) / 22.0)
    return lerp(0.015, 1.0, d)
end

-- Wider, softer golden hour
local function golden_factor(elev)
    local d = m_abs(elev)
    if d > 22 then return 0 end
    return smoother(1.0 - d / 22.0)
end

local function is_morning(tod)
    return tod < 12.0
end


local function evaluate(tod)
    local elev    = sun_elevation(tod)
    local day     = day_factor(elev)
    local gold    = golden_factor(elev)
    local morning = is_morning(tod)

    local base      = lerp4(TimeCycle.color_night, TimeCycle.color_noon, day)
    local gold_col  = morning and TimeCycle.color_sunrise or TimeCycle.color_sunset
    local sun_color = lerp4(base, gold_col, gold * 0.72)

    local energy = lerp(TimeCycle.sun_energy_night, TimeCycle.sun_energy_day, day)
    energy = energy * (1.0 + gold * 0.30)

    local sky_top = lerp4(TimeCycle.sky_top_night, TimeCycle.sky_top_day, day)
    local sky_hor = lerp4(TimeCycle.sky_horizon_night, TimeCycle.sky_horizon_day, day)
    -- Horizon warms nicely in golden hour
    sky_hor = lerp4(sky_hor, gold_col, gold * 0.58)

    local ground     = lerp4(TimeCycle.ground_night, TimeCycle.ground_day, day)
    local ambient    = lerp(TimeCycle.ambient_night, TimeCycle.ambient_day, day)
    local sky_energy = lerp(TimeCycle.sky_energy_night, TimeCycle.sky_energy_day, day)

    -- Night ambient: soft blue; day: warm neutral
    local ambient_color = lerp4(
        {0.38, 0.48, 0.82, 1.0},
        {0.88, 0.92, 1.00, 1.0},  -- cool day ambient
        day
    )
    -- Extra warmth into ambient during golden hour
    ambient_color = lerp4(ambient_color, gold_col, gold * 0.25)

    return {
        elev          = elev,
        day           = day,
        energy        = energy,
        color         = sun_color,
        sky_top       = sky_top,
        sky_horizon   = sky_hor,
        ground        = ground,
        ambient       = ambient,
        ambient_color = ambient_color,
        sky_energy    = sky_energy,
    }
end


--------------------------------------------------
-- Apply
--------------------------------------------------

local function apply(state)
    local sun = TimeCycle.sun
    if not sun then return end

    sun:set_rotation({ -state.elev, TimeCycle.sun_yaw, 0 })
    sun:set_energy(state.energy)
    sun:set_color(state.color)

    if sun.set_shadow_enabled then
        sun:set_shadow_enabled(state.elev > 1.5)
    end

    if gfx and gfx.sky and gfx.sky.procedural then
        local p = gfx.sky.procedural
        if p.set_sky_top_color then p.set_sky_top_color(state.sky_top) end
        if p.set_sky_horizon_color then p.set_sky_horizon_color(state.sky_horizon) end
        if p.set_ground_bottom_color then p.set_ground_bottom_color(state.ground) end
        if p.set_ground_horizon_color then p.set_ground_horizon_color(state.sky_horizon) end
        if p.set_sky_energy_multiplier then p.set_sky_energy_multiplier(state.sky_energy) end
        if p.set_ground_energy_multiplier then p.set_ground_energy_multiplier(state.sky_energy * 0.55) end
        if p.set_energy_multiplier then p.set_energy_multiplier(state.sky_energy) end
        -- Soft sun disk in the procedural sky
        if p.set_sun_angle_max then p.set_sun_angle_max(lerp(2.0, 8.0, state.day)) end
        if p.set_sun_curve then p.set_sun_curve(0.12) end
    end

    if gfx and gfx.env then
        if gfx.env.set_ambient_energy then
            gfx.env.set_ambient_energy(state.ambient)
        end
        if gfx.env.set_ambient_color then
            gfx.env.set_ambient_color(state.ambient_color)
        end
        if gfx.env.set_tonemap_exposure then
            gfx.env.set_tonemap_exposure(TimeCycle.tonemap_exposure)
        end
        if gfx.env.set_tonemap_white then
            gfx.env.set_tonemap_white(TimeCycle.tonemap_white)
        end
    end

    if gfx and gfx.adjustment then
        if gfx.adjustment.set_brightness then
            gfx.adjustment.set_brightness(lerp(1.02, 0.98, state.day))
        end
        if gfx.adjustment.set_contrast then
            gfx.adjustment.set_contrast(lerp(1.10, 1.05, state.day))
        end
        if gfx.adjustment.set_saturation then
            -- Slightly richer day, soft cool night
            gfx.adjustment.set_saturation(lerp(0.90, 1.08, state.day))
        end
    end
end


--------------------------------------------------
-- Public API
--------------------------------------------------

function TimeCycle.setTime(hour, minute)
    hour   = tonumber(hour) or 0
    minute = tonumber(minute) or 0
    hour   = hour % 24
    minute = clamp(minute, 0, 59)
    TimeCycle.time_of_day = hour + minute / 60.0
    apply(evaluate(TimeCycle.time_of_day))
    core.engine.print("info", "[TimeCycle] Time set to", format_time(TimeCycle.time_of_day))
end

function TimeCycle.getTime()
    return TimeCycle.time_of_day, format_time(TimeCycle.time_of_day)
end

function TimeCycle.setDayLength(seconds)
    seconds = tonumber(seconds) or 1200
    if seconds < 10 then seconds = 10 end
    TimeCycle.day_length_sec = seconds
    core.engine.print("info", "[TimeCycle] Day length set to", seconds, "real seconds (",
        util.string.format("%.1f", seconds / 60), "min)")
end

function TimeCycle.setAuto(state)
    if type(state) ~= "boolean" then
        state = not TimeCycle.auto_cycle
    end
    TimeCycle.auto_cycle = state
    core.engine.print("info", "[TimeCycle] Auto cycle", state and "ON" or "OFF")
end

function TimeCycle.setSunYaw(yaw)
    yaw = tonumber(yaw) or TimeCycle.sun_yaw
    TimeCycle.sun_yaw = yaw
    apply(evaluate(TimeCycle.time_of_day))
    core.engine.print("info", "[TimeCycle] Sun yaw set to", yaw)
end


--------------------------------------------------
-- Init
--------------------------------------------------

local function init()
    if gfx and gfx.sky and gfx.sky.set_mode then
        gfx.sky.set_mode(gfx.sky.sky_mode.PROCEDURAL)
    end
    if gfx and gfx.env and gfx.env.set_background_mode then
        gfx.env.set_background_mode(gfx.env.background_mode.SKY)
    end

    if gfx and gfx.env and gfx.env.set_ambient_source then
        if gfx.env.ambient_source and gfx.env.ambient_source.COLOR then
            gfx.env.set_ambient_source(gfx.env.ambient_source.COLOR)
        end
    end

    TimeCycle.sun = light.directional.create()
    TimeCycle.sun:set_position({0, 50, 0})
    TimeCycle.sun:set_energy(TimeCycle.sun_energy_day)
    TimeCycle.sun:set_color(TimeCycle.color_noon)

    if TimeCycle.sun.set_shadow_enabled then
        TimeCycle.sun:set_shadow_enabled(true)
    end
    if TimeCycle.sun.set_shadow_mode then
        TimeCycle.sun:set_shadow_mode(light.directional.shadow_mode.PARALLEL_4_SPLITS)
    end
    if TimeCycle.sun.set_sky_mode then
        TimeCycle.sun:set_sky_mode(light.directional.sky_mode.LIGHT_AND_SKY)
    end

    apply(evaluate(TimeCycle.time_of_day))
    core.engine.print("info", "[TimeCycle] Ready – time", format_time(TimeCycle.time_of_day),
        "| auto", TimeCycle.auto_cycle and "ON" or "OFF",
        "| daylength", TimeCycle.day_length_sec, "s")
end


--------------------------------------------------
-- Update
--------------------------------------------------

util.event.on("sandbox:process", function(delta)
    if not TimeCycle.sun then return end

    if TimeCycle.auto_cycle and TimeCycle.day_length_sec > 0 then
        local hours_per_sec = 24.0 / TimeCycle.day_length_sec
        TimeCycle.time_of_day = (TimeCycle.time_of_day + delta * hours_per_sec) % 24.0
    end

    apply(evaluate(TimeCycle.time_of_day))
end)


--------------------------------------------------
-- Console
--------------------------------------------------

util.input.register("time", function(args)
    if not args[1] then
        local _, str = TimeCycle.getTime()
        core.engine.print("info", "[TimeCycle] Current time:", str,
            "| auto:", TimeCycle.auto_cycle and "ON" or "OFF",
            "| daylength:", TimeCycle.day_length_sec, "s")
        return
    end
    TimeCycle.setTime(args[1], args[2] or 0)
end)

util.input.register("daylength", function(args)
    if not args[1] then
        core.engine.print("warn", "Usage: daylength <seconds>")
        return
    end
    TimeCycle.setDayLength(args[1])
end)

util.input.register("cycle", function(args)
    if args[1] then
        local s = util.string.lower(tostring(args[1]))
        if s == "on" or s == "1" or s == "true" then
            TimeCycle.setAuto(true)
        elseif s == "off" or s == "0" or s == "false" then
            TimeCycle.setAuto(false)
        else
            core.engine.print("warn", "Usage: cycle [on|off]")
        end
    else
        TimeCycle.setAuto()
    end
end)

util.input.register("sunyaw", function(args)
    if not args[1] then
        core.engine.print("info", "[TimeCycle] Sun yaw:", TimeCycle.sun_yaw)
        return
    end
    TimeCycle.setSunYaw(args[1])
end)


init()

_G["timecycleSetTime"]      = TimeCycle.setTime
_G["timecycleGetTime"]      = TimeCycle.getTime
_G["timecycleSetDayLength"] = TimeCycle.setDayLength
_G["timecycleSetAuto"]      = TimeCycle.setAuto
_G["timecycleSetSunYaw"]    = TimeCycle.setSunYaw