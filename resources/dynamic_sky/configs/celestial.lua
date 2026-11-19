----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/celestial.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Sun and moon size, tilt and phase ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

Config.sun_tilt_deg     = 25.0  -- tilt of the sun path (0 = straight east->west over the top)
Config.sun_radius_deg   = 2     -- apparent sun radius in deg (real sun: 0.27). change live with: sun_size <deg>
Config.moon_radius_deg  = 2     -- apparent moon radius in deg (real moon: 0.26). change live with: moon_size <deg>
Config.moon_blur        = 3.0   -- softness of the moon surface in texture mip levels, 0 = full detail, 4 = barely any craters
Config.moon_phase       = 0.5   -- 0 new, 0.5 full, 1 new
Config.moon_phase_cycle = true  -- advance the phase 1 step every 29.5 days
