----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/contrails.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 17/11/2026
     Desc: Aircraft and contrail settings ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

Config.use_contrails      = true    -- aircraft with a white trail high in the sky
Config.contrail_strength  = 1.0     -- 0..1 opacity of the trails and aircraft
Config.contrail_planes    = 3       -- aircraft in the sky at the same time (1-4), each flies a new random route every 6-12 min
Config.contrail_height    = 9500.0  -- flight altitude above the camera (m)
Config.contrail_speed     = 230.0   -- ground speed (m/s)
Config.contrail_life      = 170.0   -- how long a trail lasts before it has faded (s)
