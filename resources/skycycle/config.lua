----------------------------------------------------------------
--[[ Resource: Skycycle
     Script: config.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Every tunable: clock, timecycle, weather ]]--
----------------------------------------------------------------

-- All colours are LINEAR rgb (0..1, can exceed 1 for HDR), converted from real-world sRGB sky colours.
-- Keyframe hours follow the sun's elevation: sunrise 6:00, sunset 18:00, civil/nautical twilight either side.

SkyConfig = {
    -- clock ------------------------------------------------------
    start_time        = 9.0,    -- hour of day at resource start (0-24)
    day_length_min    = 24.0,   -- real minutes for a full 24h day (0 = frozen)
    allow_client_control = true, -- clients may use /time /weather /timescale (set false on public servers)
    sync_interval_ms  = 5000,   -- server re-sync period

    -- sun / moon -------------------------------------------------
    sun_tilt_deg      = 25.0,   -- tilt of the sun path (0 = straight east->west over the top)
    moon_phase        = 0.5,    -- 0 new, 0.5 full, 1 new
    sun_radius_deg    = 0.50,   -- apparent sun radius in degrees (real sun: 0.27). change live with: sun_size <deg>
    moon_radius_deg   = 0.85,   -- apparent moon radius in degrees (real moon: 0.26). change live with: moon_size <deg>
    moon_phase_cycle  = true,   -- advance the phase 1 step every 29.5 days

    -- clouds -----------------------------------------------------
    wind_dir          = { 1.0, 0.35 },
    wind_speed        = 6.0,    -- metres / second
    cloud_base        = 1500.0,
    cloud_thickness   = 2500.0,
    cloud_scale       = 2600.0, -- bigger = larger puffs
    cloud_detail      = 0.55,   -- erosion, higher = more wispy/fluffy edges
    quality           = "medium", -- low | medium | high | ultra (try "low" if FPS is still low)
    cloud_rt_div      = 4,      -- clouds are marched into a rendertarget this many times smaller than the screen; size = screen size / this (4 = a sixteenth of the pixels, 2 = a quarter)
    cloud_blur        = true,   -- two cheap blur passes on the small cloud rendertarget (hides noise and the low resolution)
    weather_blend_per_sec = 0.35, -- how fast weather changes are blended

    -- scene integration -------------------------------------------
    control_light     = true,   -- drive a directional light (sun by day, moon at night)
    control_environment = true, -- drive ambient / reflections through the procedural sky
    shadows           = true,
    ambient_energy    = 2.2,    -- strength of sky ambient light on the scene (raise = lighter shadows)
    ambient_floor     = 0.16,   -- extra daylight fill so shaded areas never turn black (0 = off)
    ambient_floor_color = { 0.60, 0.68, 0.90 }, -- tint of that fill (cool sky bounce)
    exposure          = 1.0,
}

SkyConfig.qualities = {
    low    = { steps = 12, light = 2 },
    medium = { steps = 20, light = 3 },
    high   = { steps = 28, light = 4 },
    ultra  = { steps = 40, light = 5 },
}

-- weather presets: target values, blended smoothly on the client
-- Every preset blends smoothly into the next one. Keys (all optional, missing = off / neutral):
--   coverage, density, type   cloud cover / thickness / shape (0 flat stratus .. 1 puffy cumulus)
--   dark    0..1   storm darkness (dims sun, light, stars)        desat 0..1  greys the sky out
--   haze    0..2   horizon haze, redder low sun, fades far clouds
--   rain / snow 0..1   precipitation overlay intensity (world-space particles: rain_fall.gdshader / snow_fall.gdshader)
--   fog     0..1   scene fog (gfx.fog), scaled by SkyConfig.fog_density_max
--   wind    x      multiplier on cloud wind + rain slant / snow drift
--   lightning 0..1 thunder flashes (rate and strength)
--   tint = {r,g,b} multiplies the whole sky colour (sand / smog)
SkyConfig.weather = {
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
SkyConfig.fog_density_max = 0.016   -- gfx.fog density at fog = 1 (set use_fog = false to leave scene fog alone)
SkyConfig.use_fog         = true      -- skycycle owns the scene fog: off in clear weather, weather-coloured otherwise
SkyConfig.use_precipitation = true  -- world-space rain / snow particles
SkyConfig.snow_rate         = 420   -- real flakes falling per second at full snow (420 x snow_life = 6720 flakes in the air); raise it for denser snow
SkyConfig.snow_size         = 0.038 -- typical flake size up close (m)
SkyConfig.snow_life         = 16.0  -- seconds a flake can fall before it fades (enough to reach the ground from 12 m above the camera)
SkyConfig.rain_wind_mps    = 2.4   -- horizontal rain speed per unit of wind (m/s); higher = more slanted rain
SkyConfig.use_engine_glow   = true  -- bloom the sun / moon with the engine glow (gfx.glow); needs a bright HDR disc
SkyConfig.sun_hdr           = 6.0   -- sun disc HDR brightness (bloom strength follows it)
SkyConfig.glow_threshold    = 2.0   -- only HDR values above this bloom; keep it above normal scene brightness
SkyConfig.glow_intensity    = 0.9
SkyConfig.glow_scale        = 1.0
SkyConfig.glow_strength     = 1.0
SkyConfig.glow_cap          = 24.0  -- HDR luminance cap of the glow
SkyConfig.glow_levels       = { 0.0, 0.25, 0.55, 0.85, 1.0, 0.9, 0.7 }   -- intensity of each glow level
SkyConfig.use_godrays       = true  -- crepuscular rays through gaps in geometry (screen-space)
SkyConfig.use_splash        = true  -- a droplet splash wherever a rain drop lands (engine sub-emitter on the colliding rain)
SkyConfig.rain_real_rate    = 3500  -- real drops falling per second at full rain (rain needs the engine with the particle collision API)
SkyConfig.splash_gpu_burst  = 3     -- droplets spawned per landing
SkyConfig.splash_gpu_amount = 0     -- minimum droplet particle budget (0 = automatic: enough slots for every landing)
SkyConfig.splash_gpu_res    = 512   -- height map resolution of the world collider (256 .. 8192); the collider only exists while it rains or snows
SkyConfig.ripple_rt_div     = 2     -- ripple buffer size: screen size / this (1 = sharper rings, 2 = half size)
SkyConfig.ripple_buffer_gamma = 1.0 -- 2.2 only if the rings look wrong (buffer turns out to be sRGB encoded)
SkyConfig.ripple_glow       = 1.0   -- sky light the ripples catch with no sun/moon on them (0 = only sun/moon lit, higher = more visible)
SkyConfig.ripple_gain       = 0.16  -- ripple bump strength
SkyConfig.dry_time         = 120   -- seconds the ground takes to dry after rain (the wet layer costs FPS until it is gone)
SkyConfig.splash_opacity    = 1.0
SkyConfig.lightning_intensity = 1.0  -- strength of thunderstorm flashes (0 = none, 2 = blinding)
SkyConfig.godray_strength   = 0.55  -- 0..~1.5 (1.0 = strong)
SkyConfig.rain_opacity      = 1.0   -- rain streak transparency multiplier (lower = fainter)
SkyConfig.use_surface_weather = true -- snow cover + wet surfaces: drawn as a translucent layer on top of every model's material (needs apply_to_material layered support)
SkyConfig.snow_accum_sec    = 150.0 -- seconds of full snowfall until the ground is fully covered
SkyConfig.snow_melt_sec     = 300.0 -- seconds for a full cover to melt away
SkyConfig.puddle_gloss      = 0.30  -- puddle roughness: higher = blurrier reflection
SkyConfig.puddle_strength   = 0.55  -- puddle opacity 0..1: lower = fainter sky reflection
SkyConfig.wet_fade_start    = 22.0  -- metres: puddles / wetness begin to thin out with distance
SkyConfig.wet_fade_end      = 75.0  -- metres: completely gone (ripples fade out earlier)
SkyConfig.surface_alpha_cut = 0.5   -- texels below this alpha are discarded by the surface shader (0 = never)
SkyConfig.default_weather = "partly"

-- timecycle -----------------------------------------------------
-- Keyframes by hour, smoothstep-interpolated, wraps at 24.
-- Add / remove / edit rows freely (keep them sorted by hour, first at 0 and last at 24).
--   zenith, horizon, ground : gradient sky colours
--   glow, glow_strength     : sun glow / sunset tint around the sun
--   sun_color               : sun disc colour
--   light, light_energy     : colour + energy of the scene directional light (sun)
--   ambient_top/bottom      : cloud ambient + scene ambient tint
--   stars                   : star visibility 0..1
--   exposure                : per-keyframe sky brightness multiplier
local NIGHT = {
    zenith = {0.004, 0.007, 0.022}, horizon = {0.020, 0.030, 0.062}, ground = {0.006, 0.008, 0.014},
    glow = {0.20, 0.25, 0.45}, glow_strength = 0.0, sun_color = {1.0, 0.5, 0.2},
    light = {0.45, 0.55, 1.00}, light_energy = 0.10,
    ambient_top = {0.020, 0.030, 0.060}, ambient_bottom = {0.010, 0.014, 0.026},
    stars = 1.0, exposure = 1.0,
}

SkyConfig.timecycle = {
    { hour = 0.0, NIGHT },
    { hour = 4.6, NIGHT },
    { hour = 5.1, {   -- nautical dawn
        zenith = {0.002, 0.004, 0.026}, horizon = {0.048, 0.048, 0.150}, ground = {0.004, 0.004, 0.008},
        glow = {0.305, 0.102, 0.223}, glow_strength = 0.15, sun_color = {1.000, 0.352, 0.156},
        light = {0.262, 0.305, 1.000}, light_energy = 0.05,
        ambient_top = {0.032, 0.033, 0.110}, ambient_bottom = {0.024, 0.024, 0.071},
        stars = 0.6, exposure = 1.0 } },
    { hour = 5.6, {   -- civil dawn: pink / purple belt
        zenith = {0.012, 0.021, 0.122}, horizon = {0.527, 0.195, 0.242}, ground = {0.014, 0.012, 0.021},
        glow = {1.000, 0.188, 0.107}, glow_strength = 0.6, sun_color = {1.000, 0.223, 0.080},
        light = {1.000, 0.262, 0.156}, light_energy = 0.15,
        ambient_top = {0.337, 0.135, 0.228}, ambient_bottom = {0.244, 0.093, 0.119},
        stars = 0.12, exposure = 1.0 } },
    { hour = 6.0, {   -- sunrise
        zenith = {0.027, 0.065, 0.270}, horizon = {0.791, 0.305, 0.181}, ground = {0.048, 0.034, 0.040},
        glow = {1.000, 0.270, 0.065}, glow_strength = 1.1, sun_color = {1.000, 0.305, 0.080},
        light = {1.000, 0.305, 0.107}, light_energy = 0.6,
        ambient_top = {0.512, 0.231, 0.282}, ambient_bottom = {0.378, 0.153, 0.099},
        stars = 0.0, exposure = 1.0 } },
    { hour = 6.6, {   -- golden morning
        zenith = {0.045, 0.127, 0.468}, horizon = {0.855, 0.491, 0.270}, ground = {0.080, 0.072, 0.076},
        glow = {1.000, 0.434, 0.133}, glow_strength = 0.8, sun_color = {1.000, 0.552, 0.262},
        light = {1.000, 0.527, 0.238}, light_energy = 1.0,
        ambient_top = {0.563, 0.387, 0.461}, ambient_bottom = {0.421, 0.253, 0.156},
        stars = 0.0, exposure = 1.0 } },
    { hour = 7.8, {   -- morning
        zenith = {0.058, 0.181, 0.604}, horizon = {0.552, 0.658, 0.776}, ground = {0.107, 0.122, 0.144},
        glow = {1.000, 0.761, 0.413}, glow_strength = 0.4, sun_color = {1.000, 0.839, 0.631},
        light = {1.000, 0.823, 0.604}, light_energy = 1.5,
        ambient_top = {0.381, 0.525, 0.862}, ambient_bottom = {0.297, 0.351, 0.414},
        stars = 0.0, exposure = 1.0 } },
    { hour = 12.0, {   -- noon
        zenith = {0.032, 0.144, 0.552}, horizon = {0.413, 0.617, 0.839}, ground = {0.102, 0.122, 0.150},
        glow = {1.000, 0.905, 0.716}, glow_strength = 0.25, sun_color = {1.000, 0.947, 0.855},
        light = {1.000, 0.939, 0.855}, light_energy = 2.0,
        ambient_top = {0.278, 0.476, 0.869}, ambient_bottom = {0.232, 0.333, 0.445},
        stars = 0.0, exposure = 1.0 } },
    { hour = 16.2, {   -- afternoon
        zenith = {0.040, 0.156, 0.565}, horizon = {0.491, 0.617, 0.761}, ground = {0.102, 0.117, 0.138},
        glow = {1.000, 0.807, 0.479}, glow_strength = 0.35, sun_color = {1.000, 0.888, 0.672},
        light = {1.000, 0.855, 0.617}, light_energy = 1.7,
        ambient_top = {0.332, 0.483, 0.828}, ambient_bottom = {0.267, 0.330, 0.405},
        stars = 0.0, exposure = 1.0 } },
    { hour = 17.4, {   -- golden evening
        zenith = {0.045, 0.117, 0.434}, horizon = {0.839, 0.445, 0.231}, ground = {0.089, 0.072, 0.072},
        glow = {1.000, 0.413, 0.117}, glow_strength = 0.8, sun_color = {1.000, 0.503, 0.188},
        light = {1.000, 0.468, 0.162}, light_energy = 1.1,
        ambient_top = {0.552, 0.351, 0.416}, ambient_bottom = {0.417, 0.233, 0.136},
        stars = 0.0, exposure = 1.0 } },
    { hour = 18.0, {   -- sunset
        zenith = {0.025, 0.058, 0.262}, horizon = {0.807, 0.246, 0.133}, ground = {0.048, 0.032, 0.037},
        glow = {1.000, 0.162, 0.034}, glow_strength = 1.2, sun_color = {1.000, 0.188, 0.045},
        light = {1.000, 0.209, 0.065}, light_energy = 0.5,
        ambient_top = {0.520, 0.190, 0.247}, ambient_bottom = {0.385, 0.125, 0.076},
        stars = 0.0, exposure = 1.0 } },
    { hour = 18.45, {   -- civil dusk: purple / rose
        zenith = {0.013, 0.023, 0.133}, horizon = {0.434, 0.144, 0.231}, ground = {0.016, 0.012, 0.021},
        glow = {0.807, 0.133, 0.122}, glow_strength = 0.55, sun_color = {1.000, 0.156, 0.045},
        light = {0.515, 0.202, 0.434}, light_energy = 0.12,
        ambient_top = {0.279, 0.105, 0.227}, ambient_bottom = {0.203, 0.070, 0.113},
        stars = 0.2, exposure = 1.0 } },
    { hour = 18.9, {   -- nautical dusk
        zenith = {0.003, 0.005, 0.037}, horizon = {0.065, 0.048, 0.162}, ground = {0.004, 0.004, 0.009},
        glow = {0.270, 0.084, 0.202}, glow_strength = 0.15, sun_color = {1.000, 0.127, 0.032},
        light = {0.262, 0.305, 1.000}, light_energy = 0.06,
        ambient_top = {0.042, 0.033, 0.124}, ambient_bottom = {0.031, 0.024, 0.077},
        stars = 0.7, exposure = 1.0 } },
    { hour = 19.6, {   -- late dusk
        zenith = {0.001, 0.002, 0.009}, horizon = {0.013, 0.018, 0.061}, ground = {0.002, 0.003, 0.005},
        glow = {0.080, 0.045, 0.156}, glow_strength = 0.04, sun_color = {1.000, 0.102, 0.021},
        light = {0.171, 0.262, 1.000}, light_energy = 0.1,
        ambient_top = {0.009, 0.012, 0.044}, ambient_bottom = {0.007, 0.009, 0.030},
        stars = 0.95, exposure = 1.0 } },
    { hour = 20.4, NIGHT },
    { hour = 24.0, NIGHT },
}

SkyConfig.night_ambient_boost = 0.6   -- extra ambient strength from dusk to night (0 = off, 1 = double)
SkyConfig.night_ambient_floor = 0.45 -- extra scene ambient from dusk to night (fades in as the sunlight fades) so shadows are dark blue instead of pure black (0 = off)
SkyConfig.night_cloud_glow = { 0.030, 0.038, 0.066 } -- extra cloud ambient at night (overcast / rainy nights stay dim grey-blue instead of black); {0,0,0} = off
SkyConfig.night_light = { color = {0.55, 0.65, 1.0}, energy = 0.12 } -- moon as scene light
