----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/glow.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Sun bloom (engine glow) ]]--
----------------------------------------------------------------

Config.use_engine_glow = true  -- bloom the sun / moon with the engine glow (gfx.glow); needs a bright HDR disc
Config.glow_threshold  = 2.0   -- only HDR values above this bloom; keep it above normal scene brightness
Config.glow_intensity  = 0.9
Config.glow_scale      = 1.0
Config.glow_strength   = 1.0
Config.glow_cap        = 24.0  -- HDR luminance cap of the glow
Config.glow_levels     = { 0.0, 0.25, 0.55, 0.85, 1.0, 0.9, 0.7 }  -- intensity of each glow level
