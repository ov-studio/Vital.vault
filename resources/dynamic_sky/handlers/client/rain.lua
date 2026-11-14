----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/rain.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Rain: real colliding drops, splashes and exact-landing ripples ]]--
----------------------------------------------------------------

local state = Sky.state
local floor, max, abs, sqrt = util.math.floor, util.math.max, util.math.abs, util.math.sqrt
local clamp = Math.clamp
local RIP = Sky.ripple


-----------------------
--[[ Ripple buffer ]]--
-----------------------

-- a 3D rendertarget (a fraction of the screen, same aspect) that only sees the ring emitter. It is made
-- when the rain starts and rebuilt if the window changes size. A 3D rendertarget renders the world a second time every
-- frame, so it only exists while it rains.
local function buffer_free()
    local rt = state.rrt
    if not rt then return end
    state.rrt = nil
    pcall(function()
        state.cshader:set_param("screen_rip_on", 0.0)
        state.gpu_rip:set_visible(false)
        state.gpu_rip:set_layer()
        rt:destroy()
    end)
end

local function buffer()
    local res = core.display.get_resolution()
    local rx, ry = res[1] or res.x, res[2] or res.y
    if not (rx and ry and ry > 0) then return end
    if state.rrt and abs(rx - state.rrt_rx) <= 2 and abs(ry - state.rrt_ry) <= 2 then return end
    buffer_free()
    local div = Config.ripple_rt_div
    local ok, err = pcall(function()
        local rt = core.rendertarget.create({ max(64, floor(rx / div)), max(64, floor(ry / div)) }, true, true)
        state.gpu_rip:set_layer(rt)
        state.gpu_rip:set_visible(true)
        state.cshader:set_param("screen_rip", rt)
        state.cshader:set_param("screen_rip_on", 1.0)
        state.rrt = rt
    end)
    state.rrt_rx, state.rrt_ry = rx, ry
    if not ok then
        core.engine.print("warn", "[dynamic_sky] ripple buffer unavailable, using procedural ripples: " .. tostring(err))
        state.rip_hook, state.rrt = false, nil
        state.cshader:set_param("screen_rip_on", 0.0)
        pcall(function() state.gpu_rip:set_visible(false) end)
    end
end


--------------
--[[ Init ]]--
--------------

-- real falling drops that collide with the world (they vanish on roofs and ground, so nothing rains indoors);
-- every drop that lands spawns a small droplet burst through a sub-emitter. Needs the engine's particle collision API.
Sky.on("init", function()
    if not Config.use_precipitation then return end
    local ok, err = pcall(function()
        local rr = Sky.shader("files/shaders/rain_fall.gdshader")
        if not rr then error("files/shaders/rain_fall.gdshader failed to compile") end
        -- ripples exactly where each drop lands: the droplets spawn a flat ring emitter that is drawn into a screen-space buffer
        -- (needs particle:set_layer). Without it the puddles use procedural ripples.
        local ring_sh = Config.use_surface_weather and Sky.shader("files/shaders/ripple_ring.gdshader") or nil
        state.sdrop = (state.splash_on or ring_sh) and Sky.shader("files/shaders/splash_drop.gdshader") or nil
        if not particle.gpu.set_world_collision then error("particle.gpu.set_world_collision is missing") end
        local life = 3.6
        state.gpu_full = floor(Config.rain_real_rate * life)
        state.gpu_burst = Config.splash_gpu_burst
        state.rrshader = rr
        -- enough droplet slots for EVERY landing: landings per second x droplets per landing x droplet lifetime (+25%).
        -- A full budget silently drops new splashes, which looks like drops that hit the ground without splashing
        local sub = particle.gpu.create()                         -- the droplets: the engine spawns them where a drop lands
        sub:set_amount(max(Config.splash_gpu_amount, floor(Config.rain_real_rate * state.gpu_burst * 0.46 * 1.25) + 16))
        sub:set_lifetime(0.46)
        sub:set_one_shot(false)
        sub:set_explosiveness(0.0)
        sub:set_randomness(0.6)
        sub:set_local_coords(false)
        sub:set_direction({ 0, 1, 0 })
        sub:set_spread(62)
        sub:set_gravity({ 0, -9.8, 0 })
        sub:set_param(particle.gpu.param.VELOCITY, 0.7, 3.0)
        sub:set_visibility_aabb({ -30, -10, -30 }, { 60, 40, 60 })
        if state.sdrop then sub:set_material(state.sdrop) end
        pcall(sub.set_fixed_fps, sub, 0)                          -- simulate every frame, not at 30 fps
        sub:set_visible(true)
        local rip = ring_sh and particle.gpu.create()                 -- one ring per droplet: stands still where it was spawned
        if rip and not rip.set_layer then rip:destroy(); rip = nil end
        if rip then
            rip:set_amount(floor(Config.rain_real_rate * state.gpu_burst * RIP.life * 1.25) + 16)
            rip:set_lifetime(RIP.life)
            rip:set_one_shot(false)
            rip:set_explosiveness(0.0)
            rip:set_randomness(0.0)
            rip:set_local_coords(false)
            rip:set_gravity({ 0, 0, 0 })
            rip:set_param(particle.gpu.param.VELOCITY, 0.0, 0.0)
            rip:set_visibility_aabb({ -30, -10, -30 }, { 60, 40, 60 })
            rip:set_material(ring_sh)
            ring_sh:set_param("ring_radius", RIP.radius)
            ring_sh:set_param("share", 1.0 / state.gpu_burst)
            ring_sh:set_param("depth_scale", RIP.depth)
            pcall(rip.set_fixed_fps, rip, 0)
            rip:set_visible(false)                                -- shown once its rendertarget exists (see buffer)
            sub:set_sub_emitter(rip, particle.gpu.sub_emitter_mode.AT_START, 1)
            state.gpu_rip = rip
        end
        local car = particle.gpu.create()                         -- the rain: real falling drops drawn by rain_fall.gdshader
        car:set_amount(state.gpu_full)
        car:set_lifetime(life)
        car:set_one_shot(false)
        car:set_explosiveness(0.0)
        car:set_randomness(0.0)
        car:set_local_coords(false)
        car:set_emission_shape(particle.gpu.emission_shape.BOX, { 17.0, 0.2, 17.0 })
        car:set_direction({ 0, -1, 0 })
        car:set_spread(0)
        car:set_gravity({ 0, 0, 0 })
        car:set_material(rr)
        car:set_visibility_aabb({ -30, -30, -30 }, { 60, 60, 60 })
        car:set_collision(particle.gpu.collision_mode.HIDE, 0.0, 1.0)
        if state.splash_on or rip then car:set_sub_emitter(sub, particle.gpu.sub_emitter_mode.AT_COLLISION, state.gpu_burst) end
        -- the rain simulates every frame: at the default 30 fps a drop falling 13 m/s moves 0.4 m per step and is only noticed
        -- below the surface, so its splash would start under the floor
        pcall(car.set_fixed_fps, car, 0)
        car:set_visible(false)
        state.gpu_sub, state.gpu_car = sub, car
    end)
    state.gpu_on = ok
    if ok then core.engine.print("info", "[dynamic_sky] rain active (real colliding drops, splashes = " .. (state.splash_on and "on" or "off") .. ")")
    else core.engine.print("warn", "[dynamic_sky] rain needs the engine with the particle collision API: " .. tostring(err)) end

    -- ripples from the landed drops (else procedural ripples in the puddle layer)
    state.rip_hook = state.gpu_rip ~= nil and state.cshader ~= nil
end)


----------------
--[[ Update ]]--
----------------

Sky.on("update", function(F)
    if state.gpu_on then
        local R, cpos = F.R, F.cpos
        local stint = { F.pr * F.daylight, F.pg * F.daylight, F.pb * F.daylight, state.splash_on and (0.30 + 0.45 * clamp(R, 0, 1)) * Config.splash_opacity or 0.0 }   -- same colour source as the rain
        if state.sdrop then state.sdrop:set_param("tint", stint) end
        local snowk = (state.cur.snow > 0.2) and (1.0 - clamp(state.cur.snow, 0.0, 1.0)) or 1.0
        local reff = clamp(R * snowk, 0.0, 1.0)
        local car = state.gpu_car
        local dens = Sky.level(car, "gpu_lvl", state.gpu_full, reff, state.precip and cpos ~= nil and reff > 0.02)
        if dens then
            local fx, fy, fz = F.wx * (0.75 + 0.5 * R), -(8.5 + 9.5 * R ^ 0.9), F.wz * (0.75 + 0.5 * R)
            local fl = sqrt(fx * fx + fy * fy + fz * fz)
            pcall(function()
                car:set_global_position({ cpos[1], cpos[2] + 14.0, cpos[3] })
                state.gpu_sub:set_global_position({ cpos[1], cpos[2], cpos[3] })       -- their culling box follows the camera too
                if state.rip_hook then
                    state.gpu_rip:set_global_position({ cpos[1], cpos[2], cpos[3] })
                    buffer()
                end
                car:set_direction({ fx / fl, fy / fl, fz / fl })
                car:set_param(particle.gpu.param.VELOCITY, fl * 0.75, fl * 1.25)
            end)
            local sh = state.rrshader
            sh:set_param("fall_vel", { fx, fy, fz })
            sh:set_param("density", dens)
            sh:set_param("tint", { F.pr * F.daylight, F.pg * F.daylight, F.pb * F.daylight, (0.15 - 0.05 * clamp(R, 0, 1)) * Config.rain_opacity })
            sh:set_param("streak_len", 0.55 + 0.55 * R)
            sh:set_param("streak_w", 0.007 + 0.006 * R)
        end
    end

    -- no rain for a moment (the last rings have faded): drop the ripple buffer
    if state.rip_hook and state.rrt then
        state.rrt_idle = (state.gpu_lvl or 0) > 0 and 0.0 or (state.rrt_idle or 0.0) + F.dt
        if state.rrt_idle > RIP.life + 1.0 then buffer_free() end
    end
end)


-----------------
--[[ Input ]]--
-----------------

-- sky_splash [on|off] : droplet splashes where rain hits the ground
util.input.register("sky_splash", function(args)
    if not state.gpu_on then return core.engine.print("warn", "[dynamic_sky] rain is not active (needs the engine with the particle collision API)") end
    state.splash_on = Sky.switch(args[1], state.splash_on)
    if not state.rip_hook then                                                     -- with the ripple hook the droplets keep spawning (the rings hang on them), they just stay invisible
        pcall(function()
            if state.splash_on then state.gpu_car:set_sub_emitter(state.gpu_sub, particle.gpu.sub_emitter_mode.AT_COLLISION, state.gpu_burst)
            else state.gpu_car:reset_sub_emitter() end
        end)
    end
    core.engine.print("info", "[dynamic_sky] rain splashes:", state.splash_on and "on" or "off")
end)
