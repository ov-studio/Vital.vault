----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/celestial.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Sun and moon positions, moon phase and key light ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local sin, cos, PI = util.math.sin, util.math.cos, util.math.pi
local lerp, clamp, smoothstep, norm, rotate = util.math.lerp, util.math.clamp, util.math.smoothstep, util.math.norm, util.math.rotate
local PHASES = {
    { "new_moon", 0.0 }, 
    { "waxing_crescent", 0.125 }, 
    { "first_quarter", 0.25 }, 
    { "waxing_gibbous", 0.375 },
    { "full_moon", 0.5 }, 
    { "waning_gibbous", 0.625 }, 
    { "last_quarter", 0.75 }, 
    { "waning_crescent", 0.875 }
}


---------------
--[[ Utils ]]--
---------------

local private = {}

-- Returns the name of a moon phase (0..1), 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter
function private.phase_name(p) 
    return PHASES[(util.math.round((p % 1.0) * 8) % 8) + 1][1] 
end

-- Returns how much of the moon disc is lit (0..1) for a moon phase (0..1)
function private.phase_lit(p) 
    return (1.0 - cos(p * 2 * PI)) * 0.5 
end

-- Sets the moon phase from a number (0..1) or a phase name, nil / "auto" follows the 29.5 day cycle again.
-- Returns false if the value is not recognised.
function private.set_moon_phase(v)
    if v == nil or v == "auto" then 
        state.moon_phase_manual = nil
        return true 
    end
    
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

-- Sets the apparent radius of the sun in degrees (0.05-15).
-- Returns false if the value is not a number.
function private.set_sun_size(deg)
    deg = tonumber(deg)
    if not deg then return false end

    state.sun_deg = clamp(deg, 0.05, 15.0)
    return true
end

-- Sets the apparent radius of the moon in degrees (0.05-15).
-- Returns false if the value is not a number.
function private.set_moon_size(deg)
    deg = tonumber(deg)
    if not deg then return false end

    state.moon_deg = clamp(deg, 0.05, 15.0)
    return true
end

-- Returns the sun and moon directions, the rotation axis and the angle of the sky for an hour and day.
-- The moon phase is manual or follows the day cycle, and is stored in state.phase.
function private.celestial(hour, day)
    local tilt = Config.sun_tilt_deg * PI / 180
    local axis = { 0, -sin(tilt), cos(tilt) }  -- rotation axis of the sky
    local angle = (hour - 6.0) / 24.0 * 2 * PI  -- 0 = east horizon (06:00)
    local sun = rotate({ 1, 0, 0 }, axis, angle)
    local phase = state.moon_phase_manual
    if phase == nil then
        phase = Config.moon_phase
        if Config.moon_phase_cycle then phase = (phase + day / 29.5) % 1.0 end
    end
    state.phase = phase
    local elongation = phase * 2 * PI  -- 0 new, 0.25 first quarter, 0.5 full
    local moon = rotate({ 1, 0, 0 }, axis, angle - elongation)
    moon = norm({ moon[1] + axis[1] * 0.09, moon[2] + axis[2] * 0.09, moon[3] + axis[3] * 0.09 })
    return norm(sun), moon, axis, angle
end


------------------
--[[ Handlers ]]--
------------------

-- Moves the sun and moon along the sky every frame, then picks the key light: the sun by day and the moon by night,
-- with the energy each one lights the scene (faded under storm clouds).
Sky.on("update", function(frame)
    frame.sun, frame.moon, frame.axis, frame.angle = private.celestial(state.time, state.day)
    frame.day_weight = smoothstep(-0.10, 0.14, frame.sun[2])
    frame.key_dir = norm({ lerp(frame.moon[1], frame.sun[1], frame.day_weight), lerp(frame.moon[2], frame.sun[2], frame.day_weight), lerp(frame.moon[3], frame.sun[3], frame.day_weight) })
    frame.sun_energy = frame.cycle.light_energy * frame.light_left
    frame.night_energy = Config.night_light.energy * smoothstep(-0.05, 0.2, frame.moon[2]) * (1.0 - frame.day_weight)
end)


-----------------
--[[ Exports ]]--
-----------------

-- Public API surface exposed to other resources: read the moon phase, set the sun / moon size
-- and set the moon phase (0..1, a phase name, or nil / "auto").
util.export.register("get_moon_phase", function() return state.phase or Config.moon_phase, private.phase_name(state.phase or Config.moon_phase) end)
util.export.register("set_sun_size", private.set_sun_size)
util.export.register("set_moon_size", private.set_moon_size)
util.export.register("set_moon_phase", private.set_moon_phase)


------------------
--[[ Commands ]]--
------------------

-- Sets the apparent radius of the sun, the glow scales with it
-- Usage: /sun_size <0.05-15> (real sun 0.27)
util.input.register("sun_size", function(args)
    if not private.set_sun_size(args[1]) then return core.engine.print("warn", util.string.format("Usage: sun_size <0.05-15> (real sun 0.27, current %.2f)", state.sun_deg)) end
    core.engine.print("info", util.string.format("Sun radius successfully set to %.2f deg", state.sun_deg))
end)

-- Sets the apparent radius of the moon
-- Usage: /moon_size <0.05-15> (real moon 0.26)
util.input.register("moon_size", function(args)
    if not private.set_moon_size(args[1]) then return core.engine.print("warn", util.string.format("Usage: moon_size <0.05-15> (real moon 0.26, current %.2f)", state.moon_deg)) end
    core.engine.print("info", util.string.format("Moon radius successfully set to %.2f deg", state.moon_deg))
end)

-- Shows or sets the moon phase, 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter, auto follows the 29.5 day cycle
-- Usage: /moon_phase [new|waxing_crescent|first_quarter|waxing_gibbous|full|waning_gibbous|last_quarter|waning_crescent|0-1|auto]
util.input.register("moon_phase", function(args)
    if args[1] and not private.set_moon_phase(args[1]) then return core.engine.print("warn", "Usage: moon_phase <new|waxing_crescent|first_quarter|waxing_gibbous|full|waning_gibbous|last_quarter|waning_crescent|0-1|auto>") end
    local p = state.phase or Config.moon_phase
    core.engine.print("info", util.string.format("Moon phase: %s, %d%% lit%s", private.phase_name(p), util.math.round(private.phase_lit(p) * 100), state.moon_phase_manual and " (manual)" or " (auto cycle)"))
end)
