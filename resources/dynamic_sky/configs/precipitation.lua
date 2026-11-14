----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/precipitation.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: World-space rain and snow ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

Config.use_precipitation = true  -- world-space rain / snow particles
Config.rain_wind_mps     = 2.4   -- horizontal rain speed per unit of wind (m/s); higher = more slanted rain
Config.splash_gpu_res    = 512   -- height map resolution of the world collider (256 .. 8192); the collider only exists while it rains or snows
