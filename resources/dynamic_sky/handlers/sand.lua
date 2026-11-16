----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/sand.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 16/11/2026
     Desc: Wind-blown sand grains ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local floor, sqrt = util.math.floor, util.math.sqrt
local tint = { 0, 0, 0, 0.55 }


------------------
--[[ Handlers ]]--
------------------

-- Creates the sand: GPU grains that collide with the world (they vanish on walls and ground, so nothing blows indoors),
-- drawn by sand_fall.gdshader. Stays hidden until a sandstorm.
Sky.on("init", function()
    if not Config.use_precipitation then return end

    local shader = core.shader.create("files/shaders/sand_fall.gdshader", core.shader.shader_mode.SPATIAL)
    state.sand_full = floor(Config.sand_rate * Config.sand_life)

    local emitter = particle.gpu.create()
    emitter:set_amount(state.sand_full)
    emitter:set_lifetime(Config.sand_life)
    emitter:set_one_shot(false)
    emitter:set_explosiveness(0.0)
    emitter:set_randomness(0.0)
    emitter:set_local_coords(false)
    emitter:set_emission_shape(particle.gpu.emission_shape.BOX, { 20.0, 3.0, 20.0 })
    emitter:set_direction({ 1, 0, 0 })
    emitter:set_spread(0)
    emitter:set_gravity({ 0, 0, 0 })
    emitter:set_visibility_aabb({ -40, -30, -40 }, { 80, 60, 80 })
    emitter:set_material(shader)
    emitter:set_collision(particle.gpu.collision_mode.HIDE, 0.0, 1.0)
    emitter:set_visible(false)
    state.sand_emitter, state.sand_shader = emitter, shader
    state.sand_on = true
end)

-- Moves the sand emitter upwind of the camera every frame, blows it along the wind and sets its density and colour
-- from the weather and the time of day.
Sky.on("update", function(frame)
    if not state.sand_on then return end

    local emitter, shader = state.sand_emitter, state.sand_shader
    local density = Sky.level(emitter, "sand_lvl", state.sand_full, state.cur.sand, state.precip and frame.camera_pos ~= nil and state.cur.sand > 0.02)
    if not density then return end

    local blow_x, blow_y, blow_z = frame.wind_x * Config.sand_speed, -Config.sand_fall, frame.wind_z * Config.sand_speed
    local speed = sqrt(blow_x * blow_x + blow_y * blow_y + blow_z * blow_z)
    emitter:set_global_position({ frame.camera_pos[1] - frame.wind_dir[1] * Config.sand_upwind, frame.camera_pos[2] + 1.0, frame.camera_pos[3] - frame.wind_dir[3] * Config.sand_upwind })
    emitter:set_direction({ blow_x / speed, blow_y / speed, blow_z / speed })
    emitter:set_param(particle.gpu.param.VELOCITY, speed * 0.9, speed * 1.1)

    -- grains are lit like the dust but a little darker, key light plus ambient sky, so they turn dark at night
    local color, light, ambient = Config.dust_color, frame.key_color, frame.dust_ambient
    shader:set_param("fall_vel", { blow_x, blow_y, blow_z })
    shader:set_param("grain_size", Config.sand_size)
    shader:set_param("swirl_t", state.flt)
    shader:set_param("swirl", Config.sand_swirl)
    shader:set_param("density", density)
    tint[1], tint[2], tint[3] = color[1] * (ambient[1] + light[1] * 0.3) * 0.8, color[2] * (ambient[2] + light[2] * 0.3) * 0.8, color[3] * (ambient[3] + light[3] * 0.3) * 0.8
    shader:set_param("tint", tint)
end)
