----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: utils/state.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Client state shared by every handler ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

Sky.state = {
    time     = Config.start_time,
    day      = 0,
    scale    = 1.0,
    weather  = Config.default_weather,
    cur      = { 
                  coverage = 0.45, 
                  density = 0.004, 
                  type = 0.75, 
                  dark = 0.0, 
                  desat = 0.0, 
                  haze = 0.0,
                  rain = 0.0, 
                  snow = 0.0, 
                  sand = 0.0, 
                  fog = 0.0, 
                  wind = 1.0, 
                  lightning = 0.0, 
                  tr = 1.0, 
                  tg = 1.0, 
                  tb = 1.0 
               },   -- blended weather
    over     = {},  -- manual weather overrides: rain, snow, sand, wind, fog, lightning
    wdir     = util.table.clone(Config.wind_dir),  -- smoothed wind direction {x, z}
    wdir_t   = util.table.clone(Config.wind_dir),  -- wind direction target
    wind     = { 0, 0, 0 },  -- accumulated wind offset of the clouds
    cloud_t  = 0.0,
    enabled  = true,

    -- lightning
    flash    = 0.0,  -- manual flash 0..1
    bolt_cd  = 4.0,

    -- sun / moon
    sun_deg  = Config.sun_radius_deg,
    moon_deg = Config.moon_radius_deg,

    -- clouds
    quality  = Config.quality,
    clouds   = true,

    -- toggles
    glow      = Config.use_engine_glow,
    rays      = Config.use_godrays,
    contrails = Config.use_contrails,
    precip    = Config.use_precipitation,
    splash_on = Config.use_splash,

    -- precipitation
    flt      = 0.0,

    -- contrails
    contrail_amt = 0.0,

    -- surface weather
    cover    = 0.0,
    wet      = 0.0,
    cover_on = false,

    -- particle pool step of rain, snow and sand (0 = hidden), see Sky.level
    gpu_lvl  = 0,
    snow_lvl = 0,
    sand_lvl = 0
}

Sky.state.base = util.table.clone(Sky.state.cur)
Sky.state.target = util.table.clone(Sky.state.cur)
Sky.ripple = { life = 1.2, radius = 0.35, depth = 64.0 }
Sky.wrap = 5.0e6    -- wind / cloud time wrap, keeps float precision
