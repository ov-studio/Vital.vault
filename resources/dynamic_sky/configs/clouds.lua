----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/clouds.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Volumetric clouds ]]--
----------------------------------------------------------------

Config.quality         = "medium"  -- low | medium | high | ultra (try "low" if FPS is still low)
Config.cloud_base      = 1500.0
Config.cloud_thickness = 2500.0
Config.cloud_scale     = 2600.0    -- bigger = larger puffs
Config.cloud_detail    = 0.55      -- erosion, higher = more wispy/fluffy edges
Config.cloud_rt_div    = 4         -- clouds are marched into a rendertarget this many times smaller than the screen; size = screen size / this (4 = a sixteenth of the pixels, 2 = a quarter)
Config.cloud_blur      = true      -- two cheap blur passes on the small cloud rendertarget (hides noise and the low resolution)

Config.qualities = {
    low    = { steps = 12, light = 2 },
    medium = { steps = 20, light = 3 },
    high   = { steps = 28, light = 4 },
    ultra  = { steps = 40, light = 5 },
}
