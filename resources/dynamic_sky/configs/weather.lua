----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/weather.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Weather presets and wind ]]--
----------------------------------------------------------------

Config.default_weather       = "partly"
Config.weather_blend_per_sec = 0.35  -- how fast weather changes are blended
Config.wind_dir              = { 1.0, 0.35 }
Config.wind_speed            = 6.0   -- metres / second
Config.lightning_intensity   = 1.0   -- strength of thunderstorm flashes (0 = none, 2 = blinding)

-- weather presets: target values, blended smoothly on the client
-- Every preset blends smoothly into the next one. Keys (all optional, missing = off / neutral):
--   coverage, density, type   cloud cover / thickness / shape (0 flat stratus .. 1 puffy cumulus)
--   dark    0..1   storm darkness (dims sun, light, stars)        desat 0..1  greys the sky out
--   haze    0..2   horizon haze, redder low sun, fades far clouds
--   rain / snow 0..1   precipitation overlay intensity (world-space particles: rain_fall.gdshader / snow_fall.gdshader)
--   fog     0..1   scene fog (gfx.fog), scaled by Config.fog_density_max
--   wind    x      multiplier on cloud wind + rain slant / snow drift
--   lightning 0..1 thunder flashes (rate and strength)
--   tint = {r,g,b} multiplies the whole sky colour (sand / smog)
Config.weather = {
    clear     = { coverage = 0.12, density = 0.0030, type = 0.85, dark = 0.00, desat = 0.00, haze = 0.00 },
    partly    = { coverage = 0.27, density = 0.0029, type = 0.80, dark = 0.04, desat = 0.05, haze = 0.05 },
    cloudy    = { coverage = 0.38, density = 0.0048, type = 0.60, dark = 0.16, desat = 0.28, haze = 0.15 },
    overcast  = { coverage = 0.55, density = 0.0070, type = 0.30, dark = 0.40, desat = 0.70, haze = 0.30 },
    storm     = { coverage = 0.68, density = 0.0100, type = 0.20, dark = 0.65, desat = 0.85, haze = 0.45, wind = 1.6 },
    hazy      = { coverage = 0.16, density = 0.0048, type = 0.80, dark = 0.05, desat = 0.38, haze = 1.00 },

    drizzle   = { coverage = 0.50, density = 0.0062, type = 0.30, dark = 0.38, desat = 0.62, haze = 0.25, rain = 0.22, fog = 0.08, wind = 0.8 },
    rain      = { coverage = 0.62, density = 0.0085, type = 0.22, dark = 0.62, desat = 0.78, haze = 0.40, rain = 0.60, fog = 0.15, wind = 1.2 },
    thunder   = { coverage = 0.74, density = 0.0115, type = 0.15, dark = 0.85, desat = 0.88, haze = 0.50, rain = 1.00, fog = 0.12, wind = 1.9, lightning = 1.0 },
    snow      = { coverage = 0.58, density = 0.0070, type = 0.25, dark = 0.30, desat = 0.85, haze = 0.55, snow = 0.55, fog = 0.18, wind = 0.6, tint = { 0.96, 0.98, 1.05 } },
    blizzard  = { coverage = 0.72, density = 0.0100, type = 0.20, dark = 0.55, desat = 0.90, haze = 0.90, snow = 1.00, fog = 0.55, wind = 2.8, tint = { 0.92, 0.96, 1.05 } },
    fog       = { coverage = 0.30, density = 0.0040, type = 0.30, dark = 0.12, desat = 0.85, haze = 1.60, fog = 1.00, wind = 0.4 },
    sandstorm = { coverage = 0.20, density = 0.0040, type = 0.40, dark = 0.30, desat = 0.20, haze = 2.00, fog = 0.70, wind = 3.0, tint = { 1.00, 0.72, 0.42 } },
    smog      = { coverage = 0.18, density = 0.0040, type = 0.60, dark = 0.18, desat = 0.50, haze = 1.50, fog = 0.30, wind = 0.3, tint = { 0.93, 0.85, 0.62 } },
}
