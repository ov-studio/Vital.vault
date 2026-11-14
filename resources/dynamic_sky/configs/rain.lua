----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/rain.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Rain, splashes and ripples ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

Config.rain_real_rate      = 3500  -- real drops falling per second at full rain (rain needs the engine with the particle collision API)
Config.rain_opacity        = 1.0   -- rain streak transparency multiplier (lower = fainter)
Config.use_splash          = true  -- a droplet splash wherever a rain drop lands (engine sub-emitter on the colliding rain)
Config.splash_opacity      = 1.0   -- splash droplet opacity multiplier (lower = fainter)
Config.splash_gpu_burst    = 3     -- droplets spawned per landing
Config.splash_gpu_amount   = 0     -- minimum droplet particle budget (0 = automatic: enough slots for every landing)
Config.ripple_rt_div       = 2     -- ripple buffer size: screen size / this (1 = sharper rings, 2 = half size)
Config.ripple_buffer_gamma = 1.0   -- 2.2 only if the rings look wrong (buffer turns out to be sRGB encoded)
Config.ripple_glow         = 1.0   -- sky light the ripples catch with no sun/moon on them (0 = only sun/moon lit, higher = more visible)
Config.ripple_gain         = 0.16  -- ripple bump strength
