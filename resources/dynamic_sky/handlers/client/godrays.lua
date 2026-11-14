----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/godrays.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Crepuscular rays through gaps in geometry ]]--
----------------------------------------------------------------

local S = Sky.state
local clamp, smoothstep = Math.clamp, Math.smoothstep


-- strongest with a low sun and some haze, gone under heavy overcast, at night and in precipitation
Sky.on("update", function(F)
    local el = F.sun[2]
    local low = 1.0 - smoothstep(0.2, 0.8, el)                      -- low sun = stronger shafts
    local up = smoothstep(-0.02, 0.10, el)
    local cloudy = 1.0 - clamp(S.cur.dark * 1.6, 0.0, 1.0)
    local precip = 1.0 - clamp(S.cur.rain * 0.8 + S.cur.snow * 0.5, 0.0, 0.9)
    local amt = S.rays and Config.godray_strength * up * cloudy * precip * (0.65 + 0.35 * low) * (0.8 + 0.4 * clamp(S.cur.haze, 0.0, 1.0)) or 0.0
    local rc = S.sun_rgb or { 1.0, 0.88, 0.65 }
    S.shader:set_param("ray_color", { rc[1], rc[2] * 0.97, rc[3] * 0.85 })
    S.shader:set_param("ray_strength", clamp(amt, 0.0, 1.5))
    S.shader:set_param("ray_decay", 0.955 + 0.02 * low)
end)


-----------------
--[[ Input ]]--
-----------------

-- sky_godrays [on|off] : crepuscular rays through gaps in trees / buildings
util.input.register("sky_godrays", function(args)
    S.rays = Sky.switch(args[1], S.rays)
    core.engine.print("info", "[dynamic_sky] god rays:", S.rays and "on" or "off")
end)
