----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/snow.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Snowfall: real flakes that collide with the world ]]--
----------------------------------------------------------------

--TODO: Improve

-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local floor, max, sqrt = util.math.floor, util.math.max, util.math.sqrt
local lerp, clamp = Math.lerp, Math.clamp


------------------
--[[ Handlers ]]--
------------------

-- Creates the snow: GPU flakes that collide with the world (they vanish on roofs and ground, so nothing snows indoors),
-- drawn by snow_fall.gdshader. Stays hidden until it snows.
Sky.on("init", function()
    if not Config.use_precipitation then return end
    local shader = core.shader.create("files/shaders/snow_fall.gdshader", core.shader.shader_mode.SPATIAL)
    state.snow_full = floor(Config.snow_rate * Config.snow_life)
    local emitter = particle.gpu.create()
    emitter:set_amount(state.snow_full)
    emitter:set_lifetime(Config.snow_life)
    emitter:set_one_shot(false)
    emitter:set_explosiveness(0.0)
    emitter:set_randomness(0.0)
    emitter:set_local_coords(false)
    emitter:set_emission_shape(particle.gpu.emission_shape.BOX, { 17.0, 0.2, 17.0 })
    emitter:set_direction({ 0, -1, 0 })
    emitter:set_spread(0)
    emitter:set_gravity({ 0, 0, 0 })
    emitter:set_visibility_aabb({ -30, -30, -30 }, { 60, 60, 60 })
    emitter:set_material(shader)
    emitter:set_collision(particle.gpu.collision_mode.HIDE, 0.0, 1.0)
    emitter:set_visible(false)
    state.snow_emitter, state.snow_shader = emitter, shader
    state.snow_on = true
end)

-- Follows the camera with the snow emitter every frame and sets its fall speed, density and colour from the weather.
Sky.on("update", function(frame)
    state.flt = (state.flt + frame.dt) % 50.26548
    if not state.snow_on then return end

    local emitter, shader = state.snow_emitter, state.snow_shader
    local density = Sky.level(emitter, "snow_lvl", state.snow_full, state.cur.snow, state.precip and frame.camera_pos ~= nil and state.cur.snow > 0.02)
    if not density then return end
    local fall_x, fall_y, fall_z = frame.wind_x * 0.85, -(0.9 + 0.7 * state.cur.snow), frame.wind_z * 0.85
    local speed = sqrt(fall_x * fall_x + fall_y * fall_y + fall_z * fall_z)
    emitter:set_global_position({ frame.camera_pos[1], frame.camera_pos[2] + 12.0, frame.camera_pos[3] })
    emitter:set_direction({ fall_x / speed, fall_y / speed, fall_z / speed })
    emitter:set_param(particle.gpu.param.VELOCITY, speed * 0.8, speed * 1.2)

    -- flake colour against the open sky: the scene's colour (horizon tint), kept bright at night so flakes are not dark specks;
    -- in front of scenery the shader takes the colour of what is behind (the ground snow) instead
    local brightness = 0.55 + 0.4 * clamp(frame.daylight, 0.0, 1.0)
    shader:set_param("fall_vel", { fall_x, fall_y, fall_z })
    shader:set_param("flake_size", Config.snow_size)
    shader:set_param("flutter_t", state.flt)
    shader:set_param("sway", 0.45 / (1.0 + max(state.cur.wind - 1.0, 0.0) * 0.6))
    shader:set_param("density", density)
    shader:set_param("tint", { lerp(frame.precip_r, 1.0, 0.6) * brightness, lerp(frame.precip_g, 1.0, 0.6) * brightness, lerp(frame.precip_b, 1.0, 0.6) * brightness, 0.85 })
end)
