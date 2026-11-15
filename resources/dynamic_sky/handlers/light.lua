----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/light.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Key light, ambient and procedural sky environment ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local clamp, lerp3 = util.math.clamp, util.math.lerp3


---------------
--[[ Utils ]]--
---------------

local private = {}

-- Returns a colour lifted by tint * amount, the shadow fill that keeps shaded areas from going black.
function private.lift(color, tint, amount)
    return { color[1] + tint[1] * amount, color[2] + tint[2] * amount, color[3] + tint[3] * amount }
end

-- Points a directional light away from the sun / moon, light travels along the opposite direction.
function private.aim(l, dir)
    local up = (util.math.abs(dir[2]) > 0.98) and { 0, 0, 1 } or { 0, 1, 0 }
    l:look_at_from_position({ 0, 0, 0 }, { -dir[1] * 10, -dir[2] * 10, -dir[3] * 10 }, up)
end


------------------
--[[ Handlers ]]--
------------------

-- Switches the engine environment to our procedural sky and creates the key light (a directional light).
Sky.on("init", function()
    if Config.control_environment then
        gfx.sky.set_mode(gfx.sky.sky_mode.PROCEDURAL)
        gfx.env.set_background_mode(gfx.env.background_mode.SKY)
        gfx.env.set_ambient_source(gfx.env.ambient_source.SKY)
        gfx.env.set_reflection_source(gfx.env.reflection_source.SKY)
        gfx.sky.procedural.set_sun_angle_max(0.0)
    end

    if Config.control_light then
        state.light = light.directional.create()
        state.light:set_position({ 0, 5, 0 })
        state.light:set_shadow_enabled(Config.shadows)
        state.light:set_sky_mode(light.directional.sky_mode.LIGHT_ONLY)  -- our shader draws the sun disc
    end
end)

-- Aims the key light (sun by day, moon by night), sets its colour and energy, and drives the procedural sky,
-- ambient and shadow fill colours of the engine environment every frame.
Sky.on("update", function(frame)
    local cycle = frame.cycle

    if state.light then
        private.aim(state.light, frame.key_dir)
        local color = lerp3(Config.night_light.color, cycle.light, frame.day_weight)
        state.light:set_color({ color[1], color[2], color[3], 1.0 })
        state.light:set_energy(frame.sun_energy * frame.day_weight + frame.night_energy * 3.0 + frame.flash * 4.5)
    end

    if Config.control_environment then
        -- shadow fill: lift the ambient by a daylight-scaled floor so shaded areas never go black
        -- (sky light bounces around; at sunset the sky colours alone are too dim for that)
        local ambient_floor = Config.ambient_floor * clamp(cycle.light_energy, 0.0, 1.0) ^ 0.5
        local night_weight = clamp(1.0 - clamp(cycle.light_energy * 1.5, 0.0, 1.0) * (1.0 - clamp(cycle.stars, 0.0, 1.0)), 0.0, 1.0)  -- 0 by day .. 1 at night, rising through twilight
        ambient_floor = ambient_floor + Config.night_ambient_floor * night_weight  -- night: shadowed ground is dark blue, not pure black
        local top = private.lift(cycle.ambient_top, Config.ambient_floor_color, ambient_floor)
        local horizon = private.lift(cycle.horizon, Config.ambient_floor_color, ambient_floor * 0.8)
        local ground = private.lift(cycle.ground, Config.ambient_floor_color, ambient_floor * 0.7)
        gfx.sky.procedural.set_sky_top_color({ top[1], top[2], top[3], 1.0 })
        gfx.sky.procedural.set_sky_horizon_color({ horizon[1] * 0.8 * frame.cloud_grey, horizon[2] * 0.8 * frame.cloud_grey, horizon[3] * 0.8 * frame.cloud_grey, 1.0 })
        gfx.sky.procedural.set_ground_horizon_color({ horizon[1] * 0.6, horizon[2] * 0.6, horizon[3] * 0.6, 1.0 })
        gfx.sky.procedural.set_ground_bottom_color({ ground[1], ground[2], ground[3], 1.0 })
        gfx.env.set_ambient_energy(Config.ambient_energy * (1.0 + Config.night_ambient_boost * night_weight) * (1.0 + frame.flash * 2.4))
    end
end)
