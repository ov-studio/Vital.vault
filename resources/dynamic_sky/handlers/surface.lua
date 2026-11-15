----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/surface.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Snow cover, wet ground and puddles ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local min, max = util.math.min, util.math.max
local lerp, clamp = Math.lerp, Math.clamp


------------------
--[[ Handlers ]]--
------------------

-- Creates the surface weather layer (snow cover, wetness, puddles and ripples) drawn on top of the level's own materials.
Sky.on("init", function()
    if not Config.use_surface_weather then return end
    
    state.cshader = core.shader.create("files/shaders/snow_cover.gdshader", core.shader.shader_mode.SPATIAL)
    state.cshader:set_param("ripple_gain", Config.ripple_gain)
    state.cshader:set_param("screen_rip_depth", Sky.ripple.depth)
    state.cshader:set_param("screen_rip_gamma", Config.ripple_buffer_gamma)
end)

-- Grows or melts the snow cover and the wetness from the weather, and feeds them into the surface layer every frame.
Sky.on("update", function(frame)
    local shader = state.cshader
    if not shader then return end
    
    if state.cover_manual then
        state.cover = lerp(state.cover, state.cover_manual, clamp(frame.dt * 1.5, 0, 1))
    elseif state.cur.snow > 0.2 then
        state.cover = min(1.0, state.cover + frame.dt / Config.snow_accum_sec * state.cur.snow)
    else
        state.cover = max(0.0, state.cover - frame.dt / Config.snow_melt_sec * (1.0 + state.cur.rain * 3.0))
    end
    if state.cur.rain > 0.05 and state.cover < 0.3 then state.wet = min(1.0, state.wet + frame.dt / 25.0 * state.cur.rain)
    else state.wet = max(0.0, state.wet - frame.dt / (state.cover > 0.3 and 20.0 or Config.dry_time)) end
    local active = (state.cover > 0.004 or state.wet > 0.01)
    if active ~= state.cover_on then
        state.cover_on = active
        if active then shader:apply_to_material("*", "*", "*", 0, true)  -- layered: drawn on top of the level's own materials
        else shader:remove_from_material("*", "*", "*") end
    end
    if not active then return end

    shader:set_param("snow_amount", state.cover)
    shader:set_param("wet", state.wet)
    shader:set_param("rain_amt", clamp(state.cur.rain, 0.0, 1.0))
    shader:set_param("puddle_gloss", Config.puddle_gloss)
    shader:set_param("puddle_strength", Config.puddle_strength)
    shader:set_param("wet_fade_start", Config.wet_fade_start)
    shader:set_param("wet_fade_end", Config.wet_fade_end)
    shader:set_param("alpha_cut", Config.surface_alpha_cut)

    -- light the ripples pick up from the sky (independent of sun/moon): horizon + ambient colour, with a night floor
    -- mostly the horizon colour: that is what a flat water surface mirrors at a grazing angle
    local glow, flash_light = Config.ripple_glow, 0.015 + frame.flash * 0.8
    shader:set_param("ripple_light", { (frame.cycle.horizon[1] * 0.85 + frame.cycle.ambient_top[1] * 0.15 + flash_light * 0.8) * glow, (frame.cycle.horizon[2] * 0.85 + frame.cycle.ambient_top[2] * 0.15 + flash_light * 0.9) * glow, (frame.cycle.horizon[3] * 0.85 + frame.cycle.ambient_top[3] * 0.15 + flash_light * 1.2) * glow })
end)


-----------------
--[[ Exports ]]--
-----------------

-- Public API surface exposed to other resources: force the snow cover (0..1), nil follows the weather again.
util.export.register("set_snow_cover", function(v)
    state.cover_manual = tonumber(v) and clamp(tonumber(v), 0.0, 1.0) or nil
end)


------------------
--[[ Commands ]]--
------------------

-- Forces how much snow lies on surfaces, auto follows the weather
-- Usage: /snow_cover <0-1|auto>
util.input.register("snow_cover", function(args)
    local a = args[1]
    if not a then return core.engine.print("info", util.string.format("[dynamic_sky] snow cover %.2f, wet %.2f%s", state.cover, state.wet, state.cover_manual and " (manual)" or " (auto)")) end
    if a == "auto" then state.cover_manual = nil
    else
        local v = tonumber(a)
        if not v then return core.engine.print("warn", "Usage: snow_cover <0..1 | auto>") end
        state.cover_manual = clamp(v, 0.0, 1.0)
    end
    core.engine.print("info", "[dynamic_sky] snow cover:", state.cover_manual or "auto")
end)
