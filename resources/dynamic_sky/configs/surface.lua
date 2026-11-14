----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/surface.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Snow cover, wet surfaces and puddles ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

Config.use_surface_weather = true   -- snow cover + wet surfaces: drawn as a translucent layer on top of every model's material (needs apply_to_material layered support)
Config.snow_accum_sec      = 150.0  -- seconds of full snowfall until the ground is fully covered
Config.snow_melt_sec       = 300.0  -- seconds for a full cover to melt away
Config.dry_time            = 120    -- seconds the ground takes to dry after rain (the wet layer costs FPS until it is gone)
Config.puddle_gloss        = 0.30   -- puddle roughness: higher = blurrier reflection
Config.puddle_strength     = 0.55   -- puddle opacity 0..1: lower = fainter sky reflection
Config.wet_fade_start      = 22.0   -- metres: puddles / wetness begin to thin out with distance
Config.wet_fade_end        = 75.0   -- metres: completely gone (ripples fade out earlier)
Config.surface_alpha_cut   = 0.5    -- texels below this alpha are discarded by the surface shader (0 = never)
