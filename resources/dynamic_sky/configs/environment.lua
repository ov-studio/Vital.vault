----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/environment.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Scene light, ambient and fog ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

Config.control_light       = true                  -- drive a directional light (sun by day, moon at night)
Config.control_environment = true                  -- drive ambient / reflections through the procedural sky
Config.shadows             = true                  -- the scene light casts shadows
Config.ambient_energy      = 2.2                   -- strength of sky ambient light on the scene (raise = lighter shadows)
Config.ambient_floor       = 0.16                  -- extra daylight fill so shaded areas never turn black (0 = off)
Config.ambient_floor_color = { 0.60, 0.68, 0.90 }  -- tint of that fill (cool sky bounce)
Config.use_fog             = true                  -- Dynamic Sky owns the scene fog: off in clear weather, weather-coloured otherwise
Config.fog_density_max     = 0.016                 -- gfx.fog density at fog = 1 (set use_fog = false to leave scene fog alone)
