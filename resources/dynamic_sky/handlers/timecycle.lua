----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/timecycle.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Sky colours for the hour, tinted by the weather ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local lerp, lerp3, clamp = util.math.lerp, util.math.lerp3, util.math.clamp
local FIELDS3 = { "zenith", "horizon", "ground", "glow", "sun_color", "light", "ambient_top", "ambient_bottom" }
local FIELDS1 = { "glow_strength", "light_energy", "stars", "exposure" }


---------------
--[[ Utils ]]--
---------------

local private = {}

-- Returns the timecycle values (colours, light, stars...) for an hour, blended between the two nearest keyframes.
function private.sample(hour)
    local tc = Config.timecycle
    local first, last = tc[1], tc[#tc]
    local a, b, a_hour, b_hour = last, first, last.hour - 24, first.hour  -- before the first row: wrap from the last one
    if hour >= last.hour then
        a_hour, b_hour = last.hour, first.hour + 24  -- after the last row: wrap to the first one
    elseif hour >= first.hour then
        for i = 1, #tc - 1 do
            if hour <= tc[i + 1].hour then a, b, a_hour, b_hour = tc[i], tc[i + 1], tc[i].hour, tc[i + 1].hour; break end
        end
    end
    local span = b_hour - a_hour
    local blend = span > 0 and (hour - a_hour) / span or 0
    blend = blend * blend * (3 - 2 * blend)
    local out = {}
    for _, f in ipairs(FIELDS3) do out[f] = lerp3(a.template[f], b.template[f], blend) end
    for _, f in ipairs(FIELDS1) do out[f] = lerp(a.template[f], b.template[f], blend) end
    return out
end

-- Returns a colour multiplied by the weather tint (sandstorm, smog, snow-light), by amount (0..1).
function private.tint(color, amount)
    return { lerp(color[1], color[1] * state.cur.tr, amount), lerp(color[2], color[2] * state.cur.tg, amount), lerp(color[3], color[3] * state.cur.tb, amount) }
end

-- Returns a colour desaturated by amount (0..1) and darkened by dim (0..1).
function private.grey_out(color, amount, dim)
    local luma = color[1] * 0.2126 + color[2] * 0.7152 + color[3] * 0.0722
    local keep = 1.0 - dim
    return { lerp(color[1], luma, amount) * keep, lerp(color[2], luma, amount) * keep, lerp(color[3], luma, amount) * keep }
end


------------------
--[[ Handlers ]]--
------------------

-- Samples the timecycle for the current hour, applies the weather (overcast, storm, haze, coloured air) to it and
-- publishes the result for every other handler as frame.cycle, together with how much light is left under storm clouds.
Sky.on("update", function(frame)
    -- weather tints the whole sky: overcast greys it out and pulls the zenith toward the horizon
    -- colour (flat, bright, low contrast), storms darken it, haze washes out the horizon
    local cycle = private.sample(state.time)
    local desat, dark = state.cur.desat, state.cur.dark
    cycle.zenith = private.grey_out(lerp3(cycle.zenith, cycle.horizon, desat * 0.75), desat, dark * 0.55)
    local milk = clamp(cycle.light_energy, 0, 1.2) * 0.38  -- haze colour follows daylight
    cycle.horizon = private.grey_out(lerp3(cycle.horizon, { milk, milk * 1.04, milk * 1.10 }, clamp(state.cur.haze * 0.35, 0.0, 0.85)), desat * 0.8, dark * 0.45)
    cycle.ambient_top = private.grey_out(cycle.ambient_top, desat * 0.7, 0)
    cycle.glow_strength = cycle.glow_strength * (1.0 - desat * 0.7)

    -- coloured air (sandstorm, smog, snow-light): multiply the sky and the light by the weather tint
    cycle.zenith, cycle.horizon, cycle.ambient_top, cycle.ambient_bottom = private.tint(cycle.zenith, 1.0), private.tint(cycle.horizon, 1.0), private.tint(cycle.ambient_top, 1.0), private.tint(cycle.ambient_bottom, 1.0)
    cycle.glow, cycle.light, cycle.sun_color = private.tint(cycle.glow, 1.0), private.tint(cycle.light, 0.8), private.tint(cycle.sun_color, 0.8)
    frame.cycle = cycle
    frame.light_left = 1.0 - state.cur.dark  -- light left under storm clouds
    frame.cloud_grey = 1.0 - state.cur.dark * 0.55  -- storm clouds look flatter / darker
end)
