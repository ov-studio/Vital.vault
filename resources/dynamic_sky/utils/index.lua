----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: utils/index.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Shared namespaces, stage registry and math helpers ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

Config = {}
Math = {}
Sky = { stage = { init = {}, update = {}, draw = {} } }


----------------
--[[ Stages ]]--
----------------

function Sky.on(stage, fn)
    local list = Sky.stage[stage]
    list[#list + 1] = fn
end

function Sky.run(stage, ...)
    for _, fn in ipairs(Sky.stage[stage]) do
        if fn(...) == false then return false end
    end
    return true
end

-- on | off | nothing (flip) -> the new state
function Sky.switch(arg, current)
    if arg == "on" then return true end
    if arg == "off" then return false end
    return not current
end


----------------
--[[ Math ]]--
----------------

local sin, cos = util.math.sin, util.math.cos

function Math.rad(d) 
    return d * util.math.pi / 180.0 
end

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
