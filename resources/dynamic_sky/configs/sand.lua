----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/sand.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 16/11/2026
     Desc: Wind-blown sand grain rate, size, speed and swirl ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

Config.sand_rate   = 2500   -- grains spawned per second at full sandstorm (2500 x sand_life = 7500 in the air); raise it for more sand
Config.sand_size   = 0.030  -- typical grain size up close (m)
Config.sand_life   = 3.0    -- seconds a grain blows before it fades
Config.sand_speed  = 2.0    -- grain speed per unit of horizontal wind speed (grains fly faster than the dust)
Config.sand_fall   = 0.5    -- slow sinking speed (m/s)
Config.sand_swirl  = 1.0    -- turbulence amplitude (m)
Config.sand_upwind = 14.0   -- distance the spawn area sits upwind of the camera, so the grains blow through it (m)
