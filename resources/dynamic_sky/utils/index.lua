----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: utils/index.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Config, Math and Sky namespaces with the stage registry ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

Config = {}
Math = {}
Sky = { 
    stage = {} 
}


----------------
--[[ Stages ]]--
----------------

-- Registers a handler for a stage (init, update or draw), handlers run in the order their scripts are loaded.
-- The update stage gets a per-frame table (frame): dt, then what earlier handlers publish for the later ones,
-- cycle (timecycle values), light_left, cloud_grey, wind_dir, sun, moon, axis, angle, day_weight, key_dir, sun_energy,
-- night_energy, flash, camera_pos, daylight, precip_r / g / b and wind_x / z.
function Sky.on(stage, fn)
    Sky.stage[stage] = Sky.stage[stage] or {}
    Sky.stage[stage][#Sky.stage[stage] + 1] = fn
end

-- Runs every handler registered for a stage with the given arguments.
function Sky.run(stage, ...)
    for _, fn in ipairs(Sky.stage[stage] or {}) do fn(...) end
end

-- Resolves a command argument: "on" gives true, "off" gives false, nothing flips the current state.
-- Returns the new state.
function Sky.switch(arg, current)
    if arg == "on" then return true end
    if arg == "off" then return false end
    return not current
end


----------------
--[[ Math ]]--
----------------

local sin, cos = util.math.sin, util.math.cos

function Math.lerp(a, b, t) 
    return a + (b - a) * t
end

function Math.clamp(v, a, b) 
    if v < a then return a 
    elseif v > b then return b end 
    return v 
end

function Math.smoothstep(a, b, x) 
    local t = Math.clamp((x - a) / (b - a), 0, 1); 
    return t * t * (3 - 2 * t) 
end

function Math.lerp3(a, b, t) 
    return { Math.lerp(a[1], b[1], t), Math.lerp(a[2], b[2], t), Math.lerp(a[3], b[3], t) } 
end

function Math.dot(a, b) 
    return a[1]*b[1] + a[2]*b[2] + a[3]*b[3] 
end

function Math.cross(a, b) 
    return { a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3], a[1]*b[2]-a[2]*b[1] } 
end

function Math.norm(v) 
    local l = util.math.sqrt(v[1]*v[1] + v[2]*v[2] + v[3]*v[3])
    if l < 1e-6 then return {0,1,0} end 
    return { v[1]/l, v[2]/l, v[3]/l }
end

-- Rodrigues rotation of v around unit axis by ang
function Math.rotate(v, axis, ang)
    local c, s, k = cos(ang), sin(ang), Math.dot(axis, v)*(1 - cos(ang))
    local x = Math.cross(axis, v)
    return { v[1]*c + x[1]*s + axis[1]*k, v[2]*c + x[2]*s + axis[2]*k, v[3]*c + x[3]*s + axis[3]*k }
end
