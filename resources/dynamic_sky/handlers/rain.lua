----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/rain.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Rain: real colliding drops, splashes and exact-landing ripples ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local floor, max, abs, sqrt = util.math.floor, util.math.max, util.math.abs, util.math.sqrt
local clamp = Math.clamp
local RIP = Sky.ripple


---------------
--[[ Utils ]]--
---------------

local private = {}

-- Frees the ripple rendertarget and hides the ring emitter.
function private.buffer_free()
    local rt = state.rrt
    if not rt then return end
    state.rrt = nil
    state.cshader:set_param("screen_rip_on", 0.0)
    state.ring_emitter:set_visible(false)
    state.ring_emitter:set_layer()
    rt:destroy()
end

-- Makes sure the ripple rendertarget exists and matches the window size.
-- It is a 3D rendertarget (a fraction of the screen, same aspect) that only sees the ring emitter. It renders the
-- world a second time every frame, so it is made when the rain starts and rebuilt if the window changes size.
function private.buffer()
    local res = core.display.get_resolution()
    local rx, ry = res[1], res[2]
    if state.rrt and abs(rx - state.rrt_rx) <= 2 and abs(ry - state.rrt_ry) <= 2 then return end
    private.buffer_free()
    local rt = core.rendertarget.create({ max(64, floor(rx / Config.ripple_rt_div)), max(64, floor(ry / Config.ripple_rt_div)) }, true, true)
    state.ring_emitter:set_layer(rt)
    state.ring_emitter:set_visible(true)
    state.cshader:set_param("screen_rip", rt)
    state.cshader:set_param("screen_rip_on", 1.0)
    state.rrt, state.rrt_rx, state.rrt_ry = rt, rx, ry
end


------------------
--[[ Handlers ]]--
------------------

-- Creates the rain: real falling drops that collide with the world (they vanish on roofs and ground, so nothing rains indoors);
-- every drop that lands spawns a small droplet burst through a sub-emitter, and a ripple ring when surface weather is on.
-- Stays hidden until it rains.
Sky.on("init", function()
    if not Config.use_precipitation then return end
    local SPATIAL = core.shader.shader_mode.SPATIAL
    local rain_shader = core.shader.create("files/shaders/rain_fall.gdshader", SPATIAL)

    -- ripples exactly where each drop lands: the droplets spawn a flat ring emitter that is drawn into a screen-space buffer
    -- (needs particle:set_layer). Without it the puddles use procedural ripples.
    local ring_shader = Config.use_surface_weather and core.shader.create("files/shaders/ripple_ring.gdshader", SPATIAL) or nil
    state.sdrop = (state.splash_on or ring_shader) and core.shader.create("files/shaders/splash_drop.gdshader", SPATIAL) or nil
    local lifetime = 3.6
    state.gpu_full = floor(Config.rain_real_rate * lifetime)
    state.gpu_burst = Config.splash_gpu_burst
    state.rrshader = rain_shader

    -- enough droplet slots for EVERY landing: landings per second x droplets per landing x droplet lifetime (+25%).
    -- A full budget silently drops new splashes, which looks like drops that hit the ground without splashing
    local splash = particle.gpu.create()                         -- the droplets: the engine spawns them where a drop lands
    splash:set_amount(max(Config.splash_gpu_amount, floor(Config.rain_real_rate * state.gpu_burst * 0.46 * 1.25) + 16))
    splash:set_lifetime(0.46)
    splash:set_one_shot(false)
    splash:set_explosiveness(0.0)
    splash:set_randomness(0.6)
    splash:set_local_coords(false)
    splash:set_direction({ 0, 1, 0 })
    splash:set_spread(62)
    splash:set_gravity({ 0, -9.8, 0 })
    splash:set_param(particle.gpu.param.VELOCITY, 0.7, 3.0)
    splash:set_visibility_aabb({ -30, -10, -30 }, { 60, 40, 60 })
    if state.sdrop then splash:set_material(state.sdrop) end
    splash:set_fixed_fps(0)  -- simulate every frame, not at 30 fps
    splash:set_visible(true)
    local ring = ring_shader and particle.gpu.create()  -- one ring per droplet: stands still where it was spawned
    if ring then
        ring:set_amount(floor(Config.rain_real_rate * state.gpu_burst * RIP.life * 1.25) + 16)
        ring:set_lifetime(RIP.life)
        ring:set_one_shot(false)
        ring:set_explosiveness(0.0)
        ring:set_randomness(0.0)
        ring:set_local_coords(false)
        ring:set_gravity({ 0, 0, 0 })
        ring:set_param(particle.gpu.param.VELOCITY, 0.0, 0.0)
        ring:set_visibility_aabb({ -30, -10, -30 }, { 60, 40, 60 })
        ring:set_material(ring_shader)
        ring_shader:set_param("ring_radius", RIP.radius)
        ring_shader:set_param("share", 1.0 / state.gpu_burst)
        ring_shader:set_param("depth_scale", RIP.depth)
        ring:set_fixed_fps(0)
        ring:set_visible(false)  -- shown once its rendertarget exists (see buffer)
        splash:set_sub_emitter(ring, particle.gpu.sub_emitter_mode.AT_START, 1)
        state.ring_emitter = ring
    end

    local drops = particle.gpu.create()  -- the rain: real falling drops drawn by rain_fall.gdshader
    drops:set_amount(state.gpu_full)
    drops:set_lifetime(lifetime)
    drops:set_one_shot(false)
    drops:set_explosiveness(0.0)
    drops:set_randomness(0.0)
    drops:set_local_coords(false)
    drops:set_emission_shape(particle.gpu.emission_shape.BOX, { 17.0, 0.2, 17.0 })
    drops:set_direction({ 0, -1, 0 })
    drops:set_spread(0)
    drops:set_gravity({ 0, 0, 0 })
    drops:set_material(rain_shader)
    drops:set_visibility_aabb({ -30, -30, -30 }, { 60, 60, 60 })
    drops:set_collision(particle.gpu.collision_mode.HIDE, 0.0, 1.0)
    if state.splash_on or ring then drops:set_sub_emitter(splash, particle.gpu.sub_emitter_mode.AT_COLLISION, state.gpu_burst) end

    -- the rain simulates every frame: at the default 30 fps a drop falling 13 m/s moves 0.4 m per step and is only noticed
    -- below the surface, so its splash would start under the floor
    drops:set_fixed_fps(0)
    drops:set_visible(false)
    state.splash_emitter, state.rain_emitter = splash, drops
    state.gpu_on = true
    core.engine.print("info", "[dynamic_sky] rain active (real colliding drops, splashes = " .. (state.splash_on and "on" or "off") .. ")")
    state.rip_hook = state.ring_emitter ~= nil and state.cshader ~= nil
end)

-- Follows the camera with the rain and splash emitters every frame and sets the fall speed, density and colour from the weather.
-- Also frees the ripple buffer once the last rings have faded.
Sky.on("update", function(frame)
    if state.gpu_on then
        local splash_tint = { frame.precip_r * frame.daylight, frame.precip_g * frame.daylight, frame.precip_b * frame.daylight, state.splash_on and (0.30 + 0.45 * clamp(state.cur.rain, 0, 1)) * Config.splash_opacity or 0.0 }  -- same colour source as the rain
        if state.sdrop then state.sdrop:set_param("tint", splash_tint) end
        local snow_fade = (state.cur.snow > 0.2) and (1.0 - clamp(state.cur.snow, 0.0, 1.0)) or 1.0
        local rain_level = clamp(state.cur.rain * snow_fade, 0.0, 1.0)
        local drops = state.rain_emitter
        local density = Sky.level(drops, "gpu_lvl", state.gpu_full, rain_level, state.precip and frame.camera_pos ~= nil and rain_level > 0.02)
        if density then
            local fall_x, fall_y, fall_z = frame.wind_x * (0.75 + 0.5 * state.cur.rain), -(8.5 + 9.5 * state.cur.rain ^ 0.9), frame.wind_z * (0.75 + 0.5 * state.cur.rain)
            local speed = sqrt(fall_x * fall_x + fall_y * fall_y + fall_z * fall_z)
            drops:set_global_position({ frame.camera_pos[1], frame.camera_pos[2] + 14.0, frame.camera_pos[3] })
            state.splash_emitter:set_global_position({ frame.camera_pos[1], frame.camera_pos[2], frame.camera_pos[3] })  -- their culling box follows the camera too
            if state.rip_hook then
                state.ring_emitter:set_global_position({ frame.camera_pos[1], frame.camera_pos[2], frame.camera_pos[3] })
                private.buffer()
            end
            drops:set_direction({ fall_x / speed, fall_y / speed, fall_z / speed })
            drops:set_param(particle.gpu.param.VELOCITY, speed * 0.75, speed * 1.25)
            local shader = state.rrshader
            shader:set_param("fall_vel", { fall_x, fall_y, fall_z })
            shader:set_param("density", density)
            shader:set_param("tint", { frame.precip_r * frame.daylight, frame.precip_g * frame.daylight, frame.precip_b * frame.daylight, (0.15 - 0.05 * clamp(state.cur.rain, 0, 1)) * Config.rain_opacity })
            shader:set_param("streak_len", 0.55 + 0.55 * state.cur.rain)
            shader:set_param("streak_w", 0.007 + 0.006 * state.cur.rain)
        end
    end

    -- no rain for a moment (the last rings have faded): drop the ripple buffer
    if state.rip_hook and state.rrt then
        state.rrt_idle = (state.gpu_lvl or 0) > 0 and 0.0 or (state.rrt_idle or 0.0) + frame.dt
        if state.rrt_idle > RIP.life + 1.0 then private.buffer_free() end
    end
end)


------------------
--[[ Commands ]]--
------------------

-- Toggles the droplet splashes where rain hits the ground
-- Usage: /sky_splash [on|off]
util.input.register("sky_splash", function(args)
    if not state.gpu_on then return core.engine.print("warn", "[dynamic_sky] rain is not active (use_precipitation is off)") end
    state.splash_on = Sky.switch(args[1], state.splash_on)
    if not state.rip_hook then  -- with the ripple hook the droplets keep spawning (the rings hang on them), they just stay invisible
        if state.splash_on then state.rain_emitter:set_sub_emitter(state.splash_emitter, particle.gpu.sub_emitter_mode.AT_COLLISION, state.gpu_burst)
        else state.rain_emitter:reset_sub_emitter() end
    end
    core.engine.print("info", "[dynamic_sky] rain splashes:", state.splash_on and "on" or "off")
end)
