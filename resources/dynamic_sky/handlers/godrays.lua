----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/godrays.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: God rays through gaps in geometry ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local clamp, smoothstep = Math.clamp, Math.smoothstep


------------------
--[[ Handlers ]]--
------------------

-- strongest with a low sun and some haze, gone under heavy overcast, at night and in precipitation
Sky.on("update", function(frame)
    local low_sun = 1.0 - smoothstep(0.2, 0.8, frame.sun[2])  -- low sun = stronger shafts
    local sun_visible = smoothstep(-0.02, 0.10, frame.sun[2])
    local clear_sky = 1.0 - clamp(state.cur.dark * 1.6, 0.0, 1.0)
    local dry_air = 1.0 - clamp(state.cur.rain * 0.8 + state.cur.snow * 0.5, 0.0, 0.9)
    local strength = state.rays and Config.godray_strength * sun_visible * clear_sky * dry_air * (0.65 + 0.35 * low_sun) * (0.8 + 0.4 * clamp(state.cur.haze, 0.0, 1.0)) or 0.0
    local sun_rgb = state.sun_rgb or { 1.0, 0.88, 0.65 }
    state.shader:set_param("ray_color", { sun_rgb[1], sun_rgb[2] * 0.97, sun_rgb[3] * 0.85 })
    state.shader:set_param("ray_strength", clamp(strength, 0.0, 1.5))
    state.shader:set_param("ray_decay", 0.955 + 0.02 * low_sun)
end)


------------------
--[[ Commands ]]--
------------------

-- Toggles the crepuscular rays through gaps in trees and buildings
-- Usage: /sky_godrays [on|off]
util.input.register("sky_godrays", function(args)
    state.rays = Sky.switch(args[1], state.rays)
    core.engine.print("info", util.string.format("God rays %s", state.rays and "on" or "off"))
end)
