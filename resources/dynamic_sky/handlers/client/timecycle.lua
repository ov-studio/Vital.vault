----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/timecycle.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Sky colours for the current hour, tinted by the weather ]]--
----------------------------------------------------------------

local S = Sky.state
local lerp, lerp3, clamp = Math.lerp, Math.lerp3, Math.clamp

local FIELDS3 = { "zenith", "horizon", "ground", "glow", "sun_color", "light", "ambient_top", "ambient_bottom" }
local FIELDS1 = { "glow_strength", "light_energy", "stars", "exposure" }

local function sample(hour)
    local tc = Config.timecycle
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

local function grey_out(c, amt, dim)
    local l = c[1] * 0.2126 + c[2] * 0.7152 + c[3] * 0.0722
    local g = 1.0 - dim
    return { lerp(c[1], l, amt) * g, lerp(c[2], l, amt) * g, lerp(c[3], l, amt) * g }
end

Sky.on("update", function(F)
    local tc = sample(S.time)

    -- weather tints the whole sky: overcast greys it out and pulls the zenith toward the horizon
    -- colour (flat, bright, low contrast), storms darken it, haze washes out the horizon
    local ds, dk = S.cur.desat, S.cur.dark
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

    F.tc = tc
    F.dark = 1.0 - S.cur.dark                       -- light left under storm clouds
    F.grey = 1.0 - S.cur.dark * 0.55                -- storm clouds look flatter / darker
end)
