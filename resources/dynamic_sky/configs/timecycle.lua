----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/timecycle.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Sky colour keyframes and night lighting ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

-- timecycle -----------------------------------------------------
-- Keyframes by hour, smoothstep-interpolated, wraps at 24.
-- Add / remove / edit rows freely (keep them sorted by hour, first at 0 and last at 24).
--   zenith         : sky colour at the top
--   horizon        : sky colour at the horizon
--   ground         : colour below the horizon
--   glow           : sun glow / sunset tint around the sun
--   glow_strength  : strength of that glow
--   sun_color      : sun disc colour
--   light          : colour of the scene directional light (sun)
--   light_energy   : energy of the scene directional light (sun)
--   ambient_top    : cloud ambient tint
--   ambient_bottom : scene ambient tint
--   stars          : star visibility 0..1
--   exposure       : per-keyframe sky brightness multiplier
Config.timecycle = {
    {
        hour = 0.0,
        template = {
            -- midnight
            zenith         = {0.003, 0.005, 0.018},
            horizon        = {0.014, 0.022, 0.050},
            ground         = {0.005, 0.006, 0.012},
            glow           = {0.20, 0.25, 0.45},
            glow_strength  = 0.0,
            sun_color      = {1.0, 0.5, 0.2},
            light          = {0.45, 0.55, 1.00},
            light_energy   = 0.08,
            ambient_top    = {0.016, 0.024, 0.050},
            ambient_bottom = {0.008, 0.011, 0.021},
            stars          = 1.0,
            exposure       = 1.0
        }
    },

    {
        hour = 4.6,
        template = {
            -- pre-dawn
            zenith         = {0.004, 0.007, 0.024},
            horizon        = {0.026, 0.034, 0.075},
            ground         = {0.006, 0.008, 0.015},
            glow           = {0.22, 0.20, 0.40},
            glow_strength  = 0.02,
            sun_color      = {1.0, 0.45, 0.2},
            light          = {0.42, 0.52, 1.00},
            light_energy   = 0.07,
            ambient_top    = {0.022, 0.030, 0.064},
            ambient_bottom = {0.012, 0.015, 0.028},
            stars          = 0.9,
            exposure       = 1.0
        }
    },

    {
        hour = 5.1,
        template = {
            -- nautical dawn
            zenith         = {0.002, 0.004, 0.026},
            horizon        = {0.048, 0.048, 0.150},
            ground         = {0.004, 0.004, 0.008},
            glow           = {0.305, 0.102, 0.223},
            glow_strength  = 0.15,
            sun_color      = {1.000, 0.352, 0.156},
            light          = {0.262, 0.305, 1.000},
            light_energy   = 0.05,
            ambient_top    = {0.032, 0.033, 0.110},
            ambient_bottom = {0.024, 0.024, 0.071},
            stars          = 0.6,
            exposure       = 1.0
        }
    },

    {
        hour = 5.6,
        template = {
            -- civil dawn: pink / purple belt
            zenith         = {0.012, 0.021, 0.122},
            horizon        = {0.527, 0.195, 0.242},
            ground         = {0.014, 0.012, 0.021},
            glow           = {1.000, 0.188, 0.107},
            glow_strength  = 0.6,
            sun_color      = {1.000, 0.223, 0.080},
            light          = {1.000, 0.262, 0.156},
            light_energy   = 0.15,
            ambient_top    = {0.337, 0.135, 0.228},
            ambient_bottom = {0.244, 0.093, 0.119},
            stars          = 0.12,
            exposure       = 1.0
        }
    },

    {
        hour = 6.0,
        template = {
            -- sunrise
            zenith         = {0.027, 0.065, 0.270},
            horizon        = {0.791, 0.305, 0.181},
            ground         = {0.048, 0.034, 0.040},
            glow           = {1.000, 0.270, 0.065},
            glow_strength  = 1.1,
            sun_color      = {1.000, 0.305, 0.080},
            light          = {1.000, 0.305, 0.107},
            light_energy   = 0.6,
            ambient_top    = {0.512, 0.231, 0.282},
            ambient_bottom = {0.378, 0.153, 0.099},
            stars          = 0.0,
            exposure       = 1.0
        }
    },

    {
        hour = 6.6,
        template = {
            -- golden morning
            zenith         = {0.045, 0.127, 0.468},
            horizon        = {0.855, 0.491, 0.270},
            ground         = {0.080, 0.072, 0.076},
            glow           = {1.000, 0.434, 0.133},
            glow_strength  = 0.8,
            sun_color      = {1.000, 0.552, 0.262},
            light          = {1.000, 0.527, 0.238},
            light_energy   = 1.0,
            ambient_top    = {0.563, 0.387, 0.461},
            ambient_bottom = {0.421, 0.253, 0.156},
            stars          = 0.0,
            exposure       = 1.0
        }
    },

    {
        hour = 7.8,
        template = {
            -- morning
            zenith         = {0.058, 0.181, 0.604},
            horizon        = {0.552, 0.658, 0.776},
            ground         = {0.107, 0.122, 0.144},
            glow           = {1.000, 0.761, 0.413},
            glow_strength  = 0.4,
            sun_color      = {1.000, 0.839, 0.631},
            light          = {1.000, 0.823, 0.604},
            light_energy   = 1.5,
            ambient_top    = {0.381, 0.525, 0.862},
            ambient_bottom = {0.297, 0.351, 0.414},
            stars          = 0.0,
            exposure       = 1.0
        }
    },

    {
        hour = 12.0,
        template = {
            -- noon
            zenith         = {0.032, 0.144, 0.552},
            horizon        = {0.413, 0.617, 0.839},
            ground         = {0.102, 0.122, 0.150},
            glow           = {1.000, 0.905, 0.716},
            glow_strength  = 0.25,
            sun_color      = {1.000, 0.947, 0.855},
            light          = {1.000, 0.939, 0.855},
            light_energy   = 2.0,
            ambient_top    = {0.278, 0.476, 0.869},
            ambient_bottom = {0.232, 0.333, 0.445},
            stars          = 0.0,
            exposure       = 1.0
        }
    },

    {
        hour = 16.2,
        template = {
            -- afternoon
            zenith         = {0.040, 0.156, 0.565},
            horizon        = {0.491, 0.617, 0.761},
            ground         = {0.102, 0.117, 0.138},
            glow           = {1.000, 0.807, 0.479},
            glow_strength  = 0.35,
            sun_color      = {1.000, 0.888, 0.672},
            light          = {1.000, 0.855, 0.617},
            light_energy   = 1.7,
            ambient_top    = {0.332, 0.483, 0.828},
            ambient_bottom = {0.267, 0.330, 0.405},
            stars          = 0.0,
            exposure       = 1.0
        }
    },

    {
        hour = 17.4,
        template = {
            -- golden evening
            zenith         = {0.045, 0.117, 0.434},
            horizon        = {0.839, 0.445, 0.231},
            ground         = {0.089, 0.072, 0.072},
            glow           = {1.000, 0.413, 0.117},
            glow_strength  = 0.8,
            sun_color      = {1.000, 0.503, 0.188},
            light          = {1.000, 0.468, 0.162},
            light_energy   = 1.1,
            ambient_top    = {0.552, 0.351, 0.416},
            ambient_bottom = {0.417, 0.233, 0.136},
            stars          = 0.0,
            exposure       = 1.0
        }
    },

    {
        hour = 18.0,
        template = {
            -- sunset
            zenith         = {0.025, 0.058, 0.262},
            horizon        = {0.807, 0.246, 0.133},
            ground         = {0.048, 0.032, 0.037},
            glow           = {1.000, 0.162, 0.034},
            glow_strength  = 1.2,
            sun_color      = {1.000, 0.188, 0.045},
            light          = {1.000, 0.209, 0.065},
            light_energy   = 0.5,
            ambient_top    = {0.520, 0.190, 0.247},
            ambient_bottom = {0.385, 0.125, 0.076},
            stars          = 0.0,
            exposure       = 1.0
        }
    },

    {
        hour = 18.45,
        template = {
            -- civil dusk: purple / rose
            zenith         = {0.013, 0.023, 0.133},
            horizon        = {0.434, 0.144, 0.231},
            ground         = {0.016, 0.012, 0.021},
            glow           = {0.807, 0.133, 0.122},
            glow_strength  = 0.55,
            sun_color      = {1.000, 0.156, 0.045},
            light          = {0.515, 0.202, 0.434},
            light_energy   = 0.12,
            ambient_top    = {0.279, 0.105, 0.227},
            ambient_bottom = {0.203, 0.070, 0.113},
            stars          = 0.2,
            exposure       = 1.0
        }
    },

    {
        hour = 18.9,
        template = {
            -- nautical dusk
            zenith         = {0.003, 0.005, 0.037},
            horizon        = {0.065, 0.048, 0.162},
            ground         = {0.004, 0.004, 0.009},
            glow           = {0.270, 0.084, 0.202},
            glow_strength  = 0.15,
            sun_color      = {1.000, 0.127, 0.032},
            light          = {0.262, 0.305, 1.000},
            light_energy   = 0.06,
            ambient_top    = {0.042, 0.033, 0.124},
            ambient_bottom = {0.031, 0.024, 0.077},
            stars          = 0.7,
            exposure       = 1.0
        }
    },

    {
        hour = 19.6,
        template = {
            -- late dusk
            zenith         = {0.001, 0.002, 0.009},
            horizon        = {0.013, 0.018, 0.061},
            ground         = {0.002, 0.003, 0.005},
            glow           = {0.080, 0.045, 0.156},
            glow_strength  = 0.04,
            sun_color      = {1.000, 0.102, 0.021},
            light          = {0.171, 0.262, 1.000},
            light_energy   = 0.1,
            ambient_top    = {0.009, 0.012, 0.044},
            ambient_bottom = {0.007, 0.009, 0.030},
            stars          = 0.95,
            exposure       = 1.0
        }
    },

    {
        hour = 20.4,
        template = {
            -- early night
            zenith         = {0.003, 0.006, 0.020},
            horizon        = {0.018, 0.026, 0.058},
            ground         = {0.005, 0.007, 0.013},
            glow           = {0.18, 0.20, 0.42},
            glow_strength  = 0.01,
            sun_color      = {1.0, 0.5, 0.2},
            light          = {0.45, 0.55, 1.00},
            light_energy   = 0.10,
            ambient_top    = {0.019, 0.028, 0.058},
            ambient_bottom = {0.010, 0.013, 0.025},
            stars          = 1.0,
            exposure       = 1.0
        }
    },

    {
        hour = 24.0,
        template = {
            -- midnight, same as 0.0 so the day wraps seamlessly
            zenith         = {0.003, 0.005, 0.018},
            horizon        = {0.014, 0.022, 0.050},
            ground         = {0.005, 0.006, 0.012},
            glow           = {0.20, 0.25, 0.45},
            glow_strength  = 0.0,
            sun_color      = {1.0, 0.5, 0.2},
            light          = {0.45, 0.55, 1.00},
            light_energy   = 0.08,
            ambient_top    = {0.016, 0.024, 0.050},
            ambient_bottom = {0.008, 0.011, 0.021},
            stars          = 1.0,
            exposure       = 1.0
        }
    }
}

Config.night_ambient_boost = 0.6                                           -- extra ambient strength from dusk to night (0 = off, 1 = double)
Config.night_ambient_floor = 0.45                                          -- extra scene ambient from dusk to night (fades in as the sunlight fades) so shadows are dark blue instead of pure black (0 = off)
Config.night_cloud_glow    = { 0.030, 0.038, 0.066 }                       -- extra cloud ambient at night (overcast / rainy nights stay dim grey-blue instead of black); {0,0,0} = off
Config.night_light         = { color = {0.55, 0.65, 1.0}, energy = 0.12 }  -- moon as scene light
