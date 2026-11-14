----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: utils/state.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Client state shared by every handler ]]--
----------------------------------------------------------------

-- Fields that start out unset (nil): shader, light, cshader, moon_phase_manual (nil = automatic phase),
-- cover_manual (nil = snow cover follows the weather), fog_on (unknown until the first frame, so the level's own fog
-- is switched off when the weather has none), gpu_on / snow_on (set once the particles exist).
Sky.state = {
    time     = Config.start_time,
    day      = 0,
    scale    = 1.0,
    weather  = Config.default_weather,
    cur      = { coverage = 0.45, density = 0.004, type = 0.75, dark = 0.0, desat = 0.0, haze = 0.0,
                 rain = 0.0, snow = 0.0, fog = 0.0, wind = 1.0, lightning = 0.0, tr = 1.0, tg = 1.0, tb = 1.0 },  -- blended weather
    base     = {},              -- blended preset values before the manual multipliers (see over)
    over     = {},              -- manual weather overrides: rain, snow, wind, fog, lightning
    wdir     = { Config.wind_dir[1], Config.wind_dir[2] },    -- smoothed wind direction {x, z}
    wdir_t   = { Config.wind_dir[1], Config.wind_dir[2] },    -- wind direction target
    wind     = { 0, 0, 0 },     -- accumulated wind offset of the clouds
    cloud_t  = 0.0,
    enabled  = true,

    -- lightning
    flash    = 0.0,             -- manual flash 0..1
    bolt_cd  = 4.0,
    seed     = 12345,

    -- sun / moon
    sun_deg  = Config.sun_radius_deg,
    moon_deg = Config.moon_radius_deg,

    -- clouds
    quality  = Config.quality,
    clouds   = true,

    -- toggles
    glow      = Config.use_engine_glow,
    rays      = Config.use_godrays,
    precip    = Config.use_precipitation,
    splash_on = Config.use_splash,

    -- precipitation
    flt      = 0.0,

    -- surface weather
    cover    = 0.0,
    wet      = 0.0,
    cover_on = false,
}

for k, v in pairs(Sky.state.cur) do Sky.state.base[k] = v end

-- ripple buffer constants, ripple_ring.gdshader and snow_cover.gdshader use the same depth range
Sky.ripple = { life = 1.2, radius = 0.35, depth = 64.0 }
Sky.wrap = 5.0e6    -- wind / cloud time wrap, keeps float precision

-- optional spatial shader: nil (with a warning) when it fails to compile, the sky works without it
function Sky.shader(path)
    local ok, sh = pcall(core.shader.create, path, core.shader.shader_mode.SPATIAL)
    if ok and sh then return sh end
    core.engine.print("warn", "[dynamic_sky] " .. path .. " failed to compile")
    return nil
end
