----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/haze.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 18/11/2026
     Desc: Morning mist and heat haze settings ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

Config.use_mist       = true                  -- ground mist: thickest around sunrise, after rain and in fog, burns off towards noon
Config.mist_strength  = 1.0                   -- 0..1 strongest mist
Config.mist_evening   = 0.35                  -- share of the morning mist that forms again in the evening (0 = only in the morning)
Config.mist_density   = 0.006                 -- how thick the mist is at the ground at full strength (extinction per metre), higher = shorter view distance
Config.mist_height    = 30.0                  -- height of the mist layer above the ground (m)
Config.mist_scale     = 0.0016                -- size of the mist patches (uv per metre), lower = bigger patches
Config.mist_distance  = 600.0                 -- how far the mist is marched (m)
Config.mist_speed     = 0.5                   -- mist drift per unit of horizontal wind speed
Config.mist_color     = { 0.86, 0.90, 0.96 }  -- mist colour in full light
Config.mist_night     = { 0.14, 0.17, 0.28 }  -- ambient light the mist gets at night (moonlit), raise it to make the mist brighter after dark

Config.use_heat_haze  = true                  -- shimmer of the hot air over distant ground on hot, clear days
Config.heat_strength  = 1.0                   -- 0..1 strongest shimmer
Config.heat_distance  = 80.0                  -- the shimmer starts this far from the camera (m), full strength at 5x this
Config.heat_amplitude = 0.0012                -- strongest distortion (screen uv), higher = wobblier
Config.heat_scale     = 40.0                  -- ripples across the screen height
