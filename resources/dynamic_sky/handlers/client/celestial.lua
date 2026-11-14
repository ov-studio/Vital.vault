----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/celestial.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Sun and moon positions, moon phase, key light and their commands ]]--
----------------------------------------------------------------

local state = Sky.state
local sin, cos, floor, PI = util.math.sin, util.math.cos, util.math.floor, util.math.pi
local lerp, clamp, smoothstep, norm, rotate = Math.lerp, Math.clamp, Math.smoothstep, Math.norm, Math.rotate


-----------------
--[[ Phases ]]--
-----------------

local PHASES = {
    { "new_moon", 0.0 }, { "waxing_crescent", 0.125 }, { "first_quarter", 0.25 }, { "waxing_gibbous", 0.375 },
    { "full_moon", 0.5 }, { "waning_gibbous", 0.625 }, { "last_quarter", 0.75 }, { "waning_crescent", 0.875 },
}
local function phase_name(p) return PHASES[(floor((p % 1.0) * 8 + 0.5) % 8) + 1][1] end
local function phase_lit(p) return (1.0 - cos(p * 2 * PI)) * 0.5 end

local function set_moon_phase(v)
    if v == nil or v == "auto" then state.moon_phase_manual = nil; return true end
    local n = tonumber(v)
    if not n then
        local key = tostring(v):lower():gsub("[%s%-]", "_")
        for _, e in ipairs(PHASES) do
            if e[1] == key or e[1] == key .. "_moon" or e[1]:gsub("_moon", "") == key then n = e[2] end
        end
        if key == "full" then n = 0.5 elseif key == "new" then n = 0.0 end
    end
    if not n then return false end
    state.moon_phase_manual = n % 1.0
    return true
end

local function set_sun_size(deg)
    deg = tonumber(deg); if not deg then return false end
    state.sun_deg = clamp(deg, 0.05, 15.0); return true
end

local function set_moon_size(deg)
    deg = tonumber(deg); if not deg then return false end
    state.moon_deg = clamp(deg, 0.05, 15.0); return true
end


-----------------
--[[ Update ]]--
-----------------

local function celestial(hour, day)
    local tilt = Config.sun_tilt_deg * PI / 180
    local axis = { 0, -sin(tilt), cos(tilt) }                   -- rotation axis of the sky
    local a = (hour - 6.0) / 24.0 * 2 * PI                      -- 0 = east horizon (06:00)
    local sun = rotate({ 1, 0, 0 }, axis, a)

    local phase = state.moon_phase_manual
    if phase == nil then
        phase = Config.moon_phase
        if Config.moon_phase_cycle then phase = (phase + day / 29.5) % 1.0 end
    end
    state.phase = phase
    -- the moon trails the sun's apparent motion: waxing moon (phase 0..0.5) sits EAST of the sun
    -- (earlier in the sky's east-to-west rotation), so it is highest at sunset around first quarter
    local elong = phase * 2 * PI                                -- 0 new, 0.25 first quarter, 0.5 full
    local moon = rotate({ 1, 0, 0 }, axis, a - elong)
    moon = norm({ moon[1] + axis[1] * 0.09, moon[2] + axis[2] * 0.09, moon[3] + axis[3] * 0.09 })
    return norm(sun), moon, axis, a
end

Sky.on("update", function(F)
    F.sun, F.moon, F.axis, F.ang = celestial(state.time, state.day)
    local sun, moon = F.sun, F.moon

    -- key light: sun by day, moon by night
    F.day_w = smoothstep(-0.10, 0.14, sun[2])
    F.key_dir = norm({
        lerp(moon[1], sun[1], F.day_w), lerp(moon[2], sun[2], F.day_w), lerp(moon[3], sun[3], F.day_w) })
    F.sun_energy = F.tc.light_energy * F.dark
    local moon_up = smoothstep(-0.05, 0.2, moon[2])
    F.night_energy = Config.night_light.energy * moon_up * (1.0 - F.day_w)
end)


-----------------
--[[ Input ]]--
-----------------

-- sun_size / moon_size <deg> : apparent radius of the sun / moon (glow scales with it)
util.input.register("sun_size", function(args)
    if not set_sun_size(args[1]) then
        return core.engine.print("info", util.string.format("[dynamic_sky] sun radius %.2f deg (usage: sun_size <0.05-15>, real sun 0.27)", state.sun_deg))
    end
    core.engine.print("info", util.string.format("[dynamic_sky] sun radius %.2f deg", state.sun_deg))
end)

util.input.register("moon_size", function(args)
    if not set_moon_size(args[1]) then
        return core.engine.print("info", util.string.format("[dynamic_sky] moon radius %.2f deg (usage: moon_size <0.05-15>, real moon 0.26)", state.moon_deg))
    end
    core.engine.print("info", util.string.format("[dynamic_sky] moon radius %.2f deg", state.moon_deg))
end)

-- moon_phase                      show the current phase
-- moon_phase full | new | first_quarter | last_quarter | waxing_crescent | waxing_gibbous | waning_gibbous | waning_crescent
-- moon_phase 0.0-1.0              0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter
-- moon_phase auto                 follow the 29.5 day cycle again
util.input.register("moon_phase", function(args)
    if args[1] and not set_moon_phase(args[1]) then
        return core.engine.print("warn", "Usage: moon_phase <new|waxing_crescent|first_quarter|waxing_gibbous|full|waning_gibbous|last_quarter|waning_crescent|0-1|auto>")
    end
    local p = state.phase or Config.moon_phase
    core.engine.print("info", util.string.format("[dynamic_sky] moon: %s, %d%% lit%s", phase_name(p), floor(phase_lit(p) * 100 + 0.5), state.moon_phase_manual and " (manual)" or " (auto cycle)"))
end)


------------------
--[[ Exports ]]--
------------------

util.export.register("get_moon_phase", function() return state.phase or Config.moon_phase, phase_name(state.phase or Config.moon_phase) end)

util.export.register("set_sun_size", set_sun_size)                  -- apparent radius in deg
util.export.register("set_moon_size", set_moon_size)
util.export.register("set_moon_phase", set_moon_phase)              -- 0..1, a phase name, or nil/"auto"
