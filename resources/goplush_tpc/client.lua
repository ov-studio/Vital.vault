util.event.on("entity:created", function(entity)
    if entity:get_type() == "physics.character" then
        core.engine.print("info", "Client - Character created:", entity:get_type(), entity:get_net_id(), core.engine.get_entity_by_net_id(entity:get_net_id()))
    else
        core.engine.print("info", "Client - Entity created:", entity:get_type(), entity:get_net_id(), core.engine.get_entity_by_net_id(entity:get_net_id()))
    end
end)

util.event.on("entity:destroyed", function(entity)
    core.engine.print("info", "Client - Entity destroyed:", entity:get_type())
end)

gfx.adjustment.set_enabled(true)
gfx.adjustment.set_brightness(1.05)
gfx.adjustment.set_contrast(1.05)
gfx.sky.set_mode(gfx.sky.sky_mode.PANORAMA)
gfx.sky.panorama.set_texture("assets/skybox.exr")
gfx.env.set_background_mode(gfx.env.background_mode.SKY)
physics.collision_shape.set_debug_all(true)

-- Camera
local camera = core.camera.create()
camera:set_projection(core.camera.projection.PERSPECTIVE)
camera:set_near_clip(0.1)
camera:set_far_clip(5000)
camera:set_fov(70)
camera:set_active()


-- ============================================================
-- Claim "my own" character body + model
-- ============================================================

local my_body  = nil
local my_model = nil

local pending_body_net_id  = nil
local pending_model_net_id = nil

local function try_claim_body(net_id)
    local entity = core.engine.get_entity_by_net_id(net_id)
    if entity then
        my_body = entity
        core.engine.print("info", "Client - Claimed own character body")
        return true
    end
    return false
end

local function try_claim_model(net_id)
    local entity = core.engine.get_entity_by_net_id(net_id)
    if entity then
        my_model = entity
        core.engine.print("info", "Client - Claimed own character model")
        return true
    end
    return false
end

util.event.on("own_character:incoming", function(body_net_id, model_net_id)
    if not try_claim_body(body_net_id) then
        pending_body_net_id = body_net_id
    end
    if not try_claim_model(model_net_id) then
        pending_model_net_id = model_net_id
    end
end)

-- Create shader from raw GLSL
local shader = core.shader.create_from_raw([[
    // render_mode cull_disabled;   // uncomment if double-sided meshes vanish from behind

    uniform sampler2D albedo_texture    : source_color, hint_default_white;
    uniform vec4      albedo_color      : source_color = vec4(1.0);
    uniform sampler2D normal_texture    : hint_normal;
    uniform float     normal_scale      = 1.0;
    uniform float     roughness         = 0.6;
    uniform float     metallic          = 0.0;
    uniform float     specular          = 0.5;
    uniform sampler2D emission_texture  : source_color, hint_default_white;
    uniform vec4      emission          : source_color = vec4(0.0, 0.0, 0.0, 1.0);
    uniform float     emission_energy   = 1.0;
    uniform vec3      uv1_scale         = vec3(1.0);
    uniform vec3      uv1_offset        = vec3(0.0);

    uniform float rainbow_speed  = 0.35;  // full hue cycles per second
    uniform float rainbow_spread = 1.5;   // hue offset across the UV
    uniform float rainbow_glow   = 0.6;   // 0 = no emission

    vec3 hsv2rgb(vec3 c) {
        vec3 p = clamp(abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
        return c.z * mix(vec3(1.0), p, c.y);
    }

    void fragment() {
        vec2 uv = UV * uv1_scale.xy + uv1_offset.xy;
        vec4 tex = texture(albedo_texture, uv) * albedo_color;

        // near-white pixels (the eyes / face lines) -> rainbow
        float whiteness = smoothstep(0.6, 0.8, min(tex.r, min(tex.g, tex.b)));
        float hue = fract(TIME * rainbow_speed + (UV.x + UV.y) * rainbow_spread);
        vec3 rainbow = pow(hsv2rgb(vec3(hue, 1.0, 1.0)), vec3(2.2)); // sRGB -> linear
        ALBEDO = mix(tex.rgb, rainbow, whiteness);


        //float hue2 = fract(TIME * rainbow_speed);
        //vec3 rainbow2 = pow(hsv2rgb(vec3(hue2, 1.0, 1.0)), vec3(2.2)); // sRGB -> linear
        //ALBEDO = rainbow2;

        ROUGHNESS = roughness;
        METALLIC  = 0.0;
        SPECULAR  = specular;
        NORMAL_MAP       = texture(normal_texture, uv).rgb;
        NORMAL_MAP_DEPTH = normal_scale;
        EMISSION = emission.rgb * texture(emission_texture, uv).rgb * emission_energy
                 + rainbow * whiteness * rainbow_glow;
    }
]], core.shader.shader_mode.SPATIAL)

--shader:apply_to_material("*", "*", "*")
--shader:apply_to_material("*", "*hair_1", "*")

util.event.on("entity:created", function(entity)
    if pending_body_net_id and entity:get_net_id() == pending_body_net_id then
        my_body = entity
        pending_body_net_id = nil
        core.engine.print("info", "Client - Claimed own character body (late)")
    end
    if pending_model_net_id and entity:get_net_id() == pending_model_net_id then
        my_model = entity
        pending_model_net_id = nil
        core.engine.print("info", "Client - Claimed own character model (late)")
        core.engine.iprint(my_model:get_bones())
        shader:apply_to_material(my_model, "*", "*")
    end
end)

util.event.on("entity:destroyed", function(entity)
    if entity == my_body  then my_body  = nil end
    if entity == my_model then my_model = nil end
end)


-- ============================================================
-- Movement + third-person camera
-- ============================================================

util.input.set_cursor_mode(util.input.cursor_mode.HIDDEN)

local yaw, pitch = 0.0, -15.0
local vel_y      = 0.0

local move_x, move_z = 0.0, 0.0
local facing_dot     = 0.0

local WALK_SPEED         = 4.0
local RUN_SPEED          = 6.0
local JUMP_SPEED         = 18
local GRAVITY            = 25.0
local MOUSE_SENSITIVITY  = 0.01
local CAMERA_DISTANCE    = 6.0
local CAMERA_HEIGHT      = 2.0
local CAMERA_LOOK_HEIGHT = 1.0
local CAMERA_RADIUS      = 0.3   -- collision sphere; also keeps the near plane out of walls
local CAMERA_SWEEP_FROM  = 0.6   -- sweep starts this far above body centre (safely inside the capsule)
local CAMERA_RECOVER     = 8.0   -- how fast the camera eases back out after an obstruction (1/s). Moving IN is instant

-- Impulse relay tuning (client -> server)
local PUSH_STRENGTH      = 0.6   -- scales character velocity into impulse
local IMPULSE_COOLDOWN   = 0.05  -- seconds between pulses per collider
local last_impulse_at    = {}    -- [net_id] = time


-- ------------------------------------------------------------
-- Tilt (tilt_l / tilt_r)
-- ------------------------------------------------------------
-- Two extra layers on top of your existing ones (0-6 are untouched).
-- tilt_* are static full-body poses, so they are bone-filtered to the head
-- (every other bone is a child of DEF-head) - the legs keep walking/running.

local LAYER_TILT_L       = 7
local LAYER_TILT_R       = 8
local LAYER_UP           = 9     -- "up" pose, overlaid on fall while rising (see update_up_layer)

local TILT_BONES         = { "DEF-head" }  -- NOTE: don't add arm bones here, layer 6 (wave) is below this layer
local TILT_MAX_WEIGHT    = 0.85  -- pose blend at full lean (1.0 = the full authored pose)
local TURN_FOR_FULL_LEAN = 220.0 -- deg/s of turning, at full run speed, that gives full lean
local STRAFE_LEAN        = 0.35  -- lean from sidestepping at full run speed (0 = off)
local LEAN_DEADZONE      = 0.06
local LEAN_ATTACK        = 11.0  -- how fast lean builds  (1/s)
local LEAN_RELEASE       = 7.0   -- how fast lean settles (1/s)

-- false = body snaps to camera yaw exactly like before (lean comes from turning the camera while moving)
-- true  = body swings round to the camera, so lean also shows when you start moving in a new direction
local SMOOTH_TURN        = false
local TURN_SMOOTHING     = 12.0  -- only used when SMOOTH_TURN (1/s, lower = lazier)
local MAX_TURN_SPEED     = 540.0 -- only used when SMOOTH_TURN (deg/s)

-- Layer weights are reliable rpcs: send at most this often, only when changed.
-- The engine tweens between updates.
local TILT_SEND_INTERVAL = 1.0 / 12.0
local TILT_SEND_EPS      = 0.04

local m_abs, m_exp, m_sqrt = util.math.abs, util.math.exp, util.math.sqrt
local m_sin, m_cos, m_rad  = util.math.sin, util.math.cos, util.math.rad

-- Jump / rising ("up" pose)
local UP_ENTER_SPEED  = 1.5   -- upward speed (units/s) that starts "up"
local UP_EXIT_SPEED   = 0.5   -- ...and it ends below this (gap = no flicker near the apex)
local UP_BLEND_IN     = 0.12
local UP_BLEND_OUT    = 0.25  -- fade back out at the apex, revealing fall underneath
local up_active       = false

local body_yaw        = 0.0   -- facing we apply to the body
local body_was_moving = false
local lean            = 0.0   -- smoothed: -1 = full left (tilt_l) .. +1 = full right (tilt_r)

local tilt = { model = nil, ready = false, retry_at = 0.0, next_send = 0.0, sent = {} }

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Shortest signed angle, result in [-180, 180)
local function wrap180(a)
    return (a + 180.0) % 360.0 - 180.0
end

local function now_sec()
    return core.engine.get_tick() * 0.001 -- get_tick() is milliseconds
end

-- Allocate the tilt layers once at weight 0. The engine rebuilds its blend
-- tree (restarting every clip) the first time a higher layer index is used,
-- so this makes that happen once at spawn instead of mid-run.
local function tilt_warmup()
    if tilt.model ~= my_model then
        tilt.model     = my_model
        tilt.ready     = false
        tilt.retry_at  = 0.0
        tilt.next_send = 0.0
        tilt.sent      = { [LAYER_TILT_L] = 0.0, [LAYER_TILT_R] = 0.0 }
        lean           = 0.0
        up_active      = false
    end
    if tilt.ready then return end

    local t = now_sec()
    if t < tilt.retry_at then return end

    if my_model:play_animation_layer(LAYER_UP,     "up",     true, 1.0, 0.0, 0.0)
    and my_model:play_animation_layer(LAYER_TILT_R, "tilt_r", true, 1.0, 0.0, 0.0)
    and my_model:play_animation_layer(LAYER_TILT_L, "tilt_l", true, 1.0, 0.0, 0.0) then
        my_model:set_animation_layer_filter(LAYER_TILT_L, true, TILT_BONES)
        my_model:set_animation_layer_filter(LAYER_TILT_R, true, TILT_BONES)
        tilt.ready = true
    else
        tilt.retry_at = t + 0.25 -- model probably still streaming in
    end
end

-- lean (-1..1) -> weights for (tilt_l, tilt_r). One side at a time, so going
-- left -> right crossfades through the neutral pose.
local function lean_to_weights(l)
    local a = m_abs(l)
    if a <= LEAN_DEADZONE then return 0.0, 0.0 end
    local w = (a - LEAN_DEADZONE) / (1.0 - LEAN_DEADZONE) * TILT_MAX_WEIGHT
    if l > 0 then return 0.0, w end
    return w, 0.0
end

local function push_tilt_weight(layer, w)
    local prev = tilt.sent[layer]
    local diff = m_abs(w - prev)
    -- always let a layer settle exactly to 0, otherwise skip tiny changes
    if diff < TILT_SEND_EPS and not (w == 0.0 and prev ~= 0.0) then return false end

    -- The engine moves weight at 1/blend_time per second (full 0->1), so this
    -- makes the tween last ~one send interval whatever the size of the step.
    local blend = clamp(TILT_SEND_INTERVAL * 1.2 / diff, 0.04, 2.5)
    if my_model:set_animation_layer_weight(layer, w, blend) then
        tilt.sent[layer] = w
        return true
    end
    return false
end

local function tilt_send()
    if not tilt.ready then return end
    local t = now_sec()
    if t < tilt.next_send then return end
    local wl, wr = lean_to_weights(lean)
    local a = push_tilt_weight(LAYER_TILT_L, wl)
    local b = push_tilt_weight(LAYER_TILT_R, wr)
    if a or b then tilt.next_send = t + TILT_SEND_INTERVAL end
end

-- Lean from turn speed (only while moving) plus sidestep speed.
-- Positive = toward the character's right = tilt_r.
local function update_lean(dt, yaw_rate)
    local target = 0.0
    if my_body and my_body:is_on_floor() then
        local v = my_body:get_real_velocity()
        local vx, vz = v[1], v[3]
        local speed01 = clamp(m_sqrt(vx * vx + vz * vz) / RUN_SPEED, 0.0, 1.0)

        -- turning right = yaw decreasing = negative yaw_rate, so flip the sign
        local turn_lean = -yaw_rate / TURN_FOR_FULL_LEAN * speed01

        -- velocity along the character's own right vector
        local r = m_rad(body_yaw)
        local lateral = (vx * m_cos(r) + vz * -m_sin(r)) / RUN_SPEED

        target = clamp(turn_lean + lateral * STRAFE_LEAN, -1.0, 1.0)
    end

    local rate = (m_abs(target) > m_abs(lean)) and LEAN_ATTACK or LEAN_RELEASE
    lean = lean + (target - lean) * (1.0 - m_exp(-rate * dt))
end

-- Rising = "up" pose on top of fall. Fall keeps doing exactly what it did
-- (on whenever you're off the floor); when upward speed drops away at the apex
-- "up" fades out and gravity's "fall" is already there underneath. Only talks
-- to the engine when the state changes.
local function update_up_layer()
    if not tilt.ready or not my_body then return end

    local want = false
    if not my_body:is_on_floor() then
        local vy = my_body:get_real_velocity()[2]
        if up_active then want = vy > UP_EXIT_SPEED else want = vy > UP_ENTER_SPEED end
    end
    if want == up_active then return end

    if want then
        if my_model:play_animation_layer(LAYER_UP, "up", true, 1.0, 1.0, UP_BLEND_IN) then up_active = true end
    else
        my_model:stop_animation_layer(LAYER_UP, UP_BLEND_OUT)
        up_active = false
    end
end

local function update_animation()
    if not my_model then return end

    tilt_warmup()

    my_model:play_animation_layer(0, "idle", true, 1.0, 1, 0.25)

    if util.input.is_pressed(util.input.key.W) then
        my_model:play_animation_layer(1, "walk", true, 1, 1, 0.25)
    else
        my_model:stop_animation_layer(1, 0.25)
    end

    if util.input.is_pressed(util.input.key.S) then
        my_model:play_animation_layer(2, "walk", true, -1, 1, 0.25)
    else
        my_model:stop_animation_layer(2, 0.25)
    end

    if util.input.is_pressed(util.input.key.W) and util.input.is_pressed(util.input.key.SHIFT) then
        RUNNING = true
        my_model:play_animation_layer(3, "run", true, 1, 1, 0.25)
    else
        RUNNING = false
        my_model:stop_animation_layer(3, 0.25)
    end

    if util.input.is_pressed(util.input.key.S) and util.input.is_pressed(util.input.key.SHIFT) then
        my_model:play_animation_layer(4, "run", true, -1, 1, 0.25)
    else
        my_model:stop_animation_layer(4, 0.25)
    end

    if my_body and not my_body:is_on_floor() then
        my_model:play_animation_layer(5, "fall", true, 1.0, 1, 0.2)
    else
        my_model:stop_animation_layer(5, 0.25)
    end

    update_up_layer()

    if util.input.is_pressed(util.input.key.Q) then
        my_model:play_animation_layer(6, "wave", false, 1.0, 1, 0.25)
        my_model:set_animation_layer_filter(6, true, {
            "DEF-upper_arm.L",
            "DEF-forearm.L",
            "DEF-hand.L",
            "DEF-upper_arm.R",
            "DEF-forearm.R",
            "DEF-hand.R",
        })
    end

    tilt_send()
end

-- After move_and_slide: report contacts against rigid bodies to the server.
local function relay_rigid_impulses()
    if not my_body then return end
    local n = my_body:get_slide_collision_count()
    if not n or n <= 0 then return end

    local v = my_body:get_real_velocity()
    local speed = util.math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])

    local now = core.engine.get_tick()
    for i = 0, n - 1 do
        local col = my_body:get_slide_collision(i)
        if col and col.collider_net_id and col.collider_net_id ~= 0 then
            local nid = col.collider_net_id
            local last = last_impulse_at[nid] or 0
            if (now - last) >= IMPULSE_COOLDOWN then
                -- Push along contact normal (away from character into the body)
                local nx, ny, nz = col.normal[1], col.normal[2], col.normal[3]
                -- Project velocity onto -normal so we only push into the object
                local vn = v[1] * (-nx) + v[2] * (-ny) + v[3] * (-nz)
                local strength = PUSH_STRENGTH*((RUNNING and 2) or 1)
                local s = vn * strength
                util.event.emit("physics:rigid_impulse", { remote = true }, nid, {
                    (-nx) * s,
                    (-ny) * s,
                    (-nz) * s
                })
                last_impulse_at[nid] = now
            end
        end
    end
end

-- ============================================================
-- Camera collision
-- ============================================================
-- Sweeps a small sphere from the character out to where the camera wants to
-- be and stops at the first thing it hits, so the camera can't go under the
-- floor or behind walls. Dynamic bodies (balls, other players, vehicles) are
-- excluded so they never shove the camera around.

local CAMERA_SHAPE        = { type = "sphere", radius = CAMERA_RADIUS }
local CAMERA_IGNORE_TYPES = { "physics.rigid", "physics.character", "physics.vehicle" }

local camera_frac       = 1.0   -- 0..1: how much of the wanted camera distance is currently free
local cam_exclude       = {}
local cam_exclude_dirty = true
local cam_exclude_at    = 0.0

local function refresh_cam_exclude()
    local list, n = {}, 0
    for i = 1, #CAMERA_IGNORE_TYPES do
        local ok, ents = pcall(core.engine.get_entities, CAMERA_IGNORE_TYPES[i])
        if ok and type(ents) == "table" then
            for j = 1, #ents do
                n = n + 1
                list[n] = ents[j]
            end
        end
    end
    cam_exclude       = list
    cam_exclude_dirty = false
    cam_exclude_at    = now_sec() + 1.0 -- periodic safety refresh
end

util.event.on("entity:created",   function() cam_exclude_dirty = true end)
util.event.on("entity:destroyed", function() cam_exclude_dirty = true end)

-- pos = character position, want = where the camera would like to be.
-- Returns the position the camera should actually use.
local function camera_collide(pos, want, dt)
    if cam_exclude_dirty or now_sec() >= cam_exclude_at then refresh_cam_exclude() end

    local sx, sy, sz = pos[1], pos[2] + CAMERA_SWEEP_FROM, pos[3]
    local mx, my, mz = want[1] - sx, want[2] - sy, want[3] - sz

    local target = 1.0
    local cast = physics.space and physics.space.cast_motion
    if cast then
        local ok, res = pcall(cast, CAMERA_SHAPE, { sx, sy, sz }, { mx, my, mz }, { exclude = cam_exclude })
        if ok and type(res) == "table" and type(res.safe) == "number" then
            target = clamp(res.safe, 0.0, 1.0)
        end
    end

    if target < camera_frac then
        camera_frac = target -- obstruction: snap in immediately, never show clipping
    else
        camera_frac = camera_frac + (target - camera_frac) * (1.0 - m_exp(-CAMERA_RECOVER * dt)) -- ease back out
    end

    return { sx + mx * camera_frac, sy + my * camera_frac, sz + mz * camera_frac }
end

util.event.on("sandbox:process", function(delta)
    local mv = util.input.get_cursor_velocity()
    yaw   = yaw   - mv[1] * MOUSE_SENSITIVITY
    pitch = pitch - mv[2] * MOUSE_SENSITIVITY
    if pitch > 80  then pitch = 80  end
    if pitch < -60 then pitch = -60 end

    if not my_body then return end

    local yaw_rad = util.math.rad(yaw)
    local fwd_x,   fwd_z   = -util.math.sin(yaw_rad), -util.math.cos(yaw_rad)
    local right_x, right_z =  util.math.cos(yaw_rad), -util.math.sin(yaw_rad)

    move_x, move_z = 0.0, 0.0
    if util.input.is_pressed(util.input.key.W) then move_x = move_x + fwd_x;   move_z = move_z + fwd_z   end
    if util.input.is_pressed(util.input.key.S) then move_x = move_x - fwd_x;   move_z = move_z - fwd_z   end
    if util.input.is_pressed(util.input.key.D) then move_x = move_x + right_x; move_z = move_z + right_z end
    if util.input.is_pressed(util.input.key.A) then move_x = move_x - right_x; move_z = move_z - right_z end

    facing_dot = move_x * fwd_x + move_z * fwd_z

    local current_speed = util.input.is_pressed(util.input.key.SHIFT) and RUN_SPEED or WALK_SPEED
    local len = util.math.sqrt(move_x * move_x + move_z * move_z)
    local yaw_rate = 0.0
    if len > 0.001 then
        move_x = (move_x / len) * current_speed
        move_z = (move_z / len) * current_speed

        local prev_yaw = body_yaw
        if SMOOTH_TURN then
            local step     = wrap180(yaw - body_yaw) * (1.0 - m_exp(-TURN_SMOOTHING * delta))
            local max_step = MAX_TURN_SPEED * delta
            body_yaw = wrap180(body_yaw + clamp(step, -max_step, max_step))
        else
            body_yaw = yaw
            -- first frame of a move: the jump from the old facing isn't a "turn"
            if not body_was_moving then prev_yaw = body_yaw end
        end
        my_body:set_rotation({0, body_yaw, 0})
        if delta > 0.0 then yaw_rate = wrap180(body_yaw - prev_yaw) / delta end
    end
    body_was_moving = len > 0.001

    update_lean(delta, yaw_rate)
    update_animation()

    local pos = my_body:get_global_position()
    local pitch_rad = util.math.rad(pitch)
    local back_dist = CAMERA_DISTANCE * util.math.cos(pitch_rad)

    camera:set_global_position(camera_collide(pos, {
        pos[1] - fwd_x * back_dist,
        pos[2] + CAMERA_HEIGHT + CAMERA_DISTANCE * util.math.sin(pitch_rad),
        pos[3] - fwd_z * back_dist
    }, delta))
    camera:look_at({ pos[1], pos[2] + CAMERA_LOOK_HEIGHT, pos[3] })
end)

util.event.on("sandbox:physics_process", function(delta)
    if not my_body then return end

    if my_body:is_on_floor() then
        vel_y = util.input.is_pressed(util.input.key.SPACE) and JUMP_SPEED or -1.0
    else
        vel_y = vel_y - GRAVITY * delta
    end

    my_body:set_velocity({ move_x, vel_y, move_z })
    my_body:move_and_slide()

    -- Contact -> server impulse (server remains sole rigid-body sim)
    relay_rigid_impulses()
end)
