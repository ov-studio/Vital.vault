----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/surface.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Surface weather: snow settles and melts, the ground gets wet ]]--
----------------------------------------------------------------

local S = Sky.state
local min, max = util.math.min, util.math.max
local lerp, clamp = Math.lerp, Math.clamp


----------------
--[[ Init ]]--
----------------

Sky.on("init", function()
    if not Config.use_surface_weather then return end
    S.cshader = Sky.shader("files/shaders/snow_cover.gdshader")
    if not S.cshader then return end
    S.cshader:set_param("ripple_gain", Config.ripple_gain)
    S.cshader:set_param("screen_rip_depth", Sky.ripple.depth)
    S.cshader:set_param("screen_rip_gamma", Config.ripple_buffer_gamma)
end)


-----------------
--[[ Update ]]--
-----------------

Sky.on("update", function(F)
    local sh = S.cshader
    if not sh then return end
    local dt, R, SN = F.dt, F.R, F.SN

    if S.cover_manual then
        S.cover = lerp(S.cover, S.cover_manual, clamp(dt * 1.5, 0, 1))
    elseif SN > 0.2 then
        S.cover = min(1.0, S.cover + dt / Config.snow_accum_sec * SN)
    else
        S.cover = max(0.0, S.cover - dt / Config.snow_melt_sec * (1.0 + R * 3.0))
    end
    if R > 0.05 and S.cover < 0.3 then S.wet = min(1.0, S.wet + dt / 25.0 * R)
    else S.wet = max(0.0, S.wet - dt / (S.cover > 0.3 and 20.0 or Config.dry_time)) end

    local active = (S.cover > 0.004 or S.wet > 0.01)
    if active ~= S.cover_on then
        S.cover_on = active
        if active then pcall(sh.apply_to_material, sh, "*", "*", "*", 0, true)   -- layered: drawn on top of the level's own materials
        else pcall(sh.remove_from_material, sh, "*", "*", "*") end
    end
    if not active then return end

    sh:set_param("snow_amount", S.cover)
    sh:set_param("wet", S.wet)
    sh:set_param("rain_amt", clamp(R, 0.0, 1.0))
    sh:set_param("puddle_gloss", Config.puddle_gloss)
    sh:set_param("puddle_strength", Config.puddle_strength)
    sh:set_param("wet_fade_start", Config.wet_fade_start)
    sh:set_param("wet_fade_end", Config.wet_fade_end)
    sh:set_param("alpha_cut", Config.surface_alpha_cut)
    -- light the ripples pick up from the sky (independent of sun/moon): horizon + ambient colour, with a night floor
    -- mostly the horizon colour: that is what a flat water surface mirrors at a grazing angle
    local g, f = Config.ripple_glow, 0.015 + F.FL * 0.8
    local h, a = F.tc.horizon, F.tc.ambient_top
    sh:set_param("ripple_light", { (h[1] * 0.85 + a[1] * 0.15 + f * 0.8) * g, (h[2] * 0.85 + a[2] * 0.15 + f * 0.9) * g, (h[3] * 0.85 + a[3] * 0.15 + f * 1.2) * g })
end)


-----------------
--[[ Input ]]--
-----------------

-- snow_cover <0..1 | auto> : force how much snow lies on surfaces (auto = follows the weather)
util.input.register("snow_cover", function(args)
    local a = args[1]
    if not a then return core.engine.print("info", util.string.format("[dynamic_sky] snow cover %.2f, wet %.2f%s", S.cover, S.wet, S.cover_manual and " (manual)" or " (auto)")) end
    if a == "auto" then S.cover_manual = nil
    else
        local v = tonumber(a)
        if not v then return core.engine.print("warn", "Usage: snow_cover <0..1 | auto>") end
        S.cover_manual = clamp(v, 0.0, 1.0)
    end
    core.engine.print("info", "[dynamic_sky] snow cover:", S.cover_manual or "auto")
end)


------------------
--[[ Exports ]]--
------------------

util.export.register("set_snow_cover", function(v) S.cover_manual = tonumber(v) and clamp(tonumber(v), 0.0, 1.0) or nil end)
