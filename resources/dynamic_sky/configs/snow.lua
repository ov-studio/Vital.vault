----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/snow.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Snowfall ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

Config.snow_rate = 420    -- real flakes falling per second at full snow (420 x snow_life = 6720 flakes in the air); raise it for denser snow
Config.snow_size = 0.038  -- typical flake size up close (m)
Config.snow_life = 16.0   -- seconds a flake can fall before it fades (enough to reach the ground from 12 m above the camera)
