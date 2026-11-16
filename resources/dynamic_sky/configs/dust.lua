----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/dust.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 16/11/2026
     Desc: Sandstorm dust volume density, height and speed ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

Config.dust_density  = 0.018                  -- how thick the dust is at the ground at full sandstorm (extinction per metre), higher = shorter view distance
Config.dust_height   = 18.0                   -- height of the dust layer above the ground (m)
Config.dust_scale    = 0.0022                 -- size of the big billows (uv per metre), lower = bigger billows
Config.dust_stretch  = 0.6                    -- billows are this much longer along the wind than across (1 = round)
Config.dust_speed    = 1.0                    -- dust speed per unit of horizontal wind speed
Config.dust_distance = 220.0                  -- how far into open sky the dust is marched (m)
Config.dust_sky      = 0.75                   -- extra dust veil over the open sky (0 = clear sky overhead), so looking up is as dusty as looking ahead
Config.dust_gust     = 0.15                   -- how much the storm swells and eases in gusts (0 = steady)
Config.dust_color    = { 0.80, 0.60, 0.36 }   -- sand colour in full light
Config.dust_night    = { 0.32, 0.36, 0.52 }   -- ambient light the dust gets at night (moonlit), raise it to make the dust brighter after dark
