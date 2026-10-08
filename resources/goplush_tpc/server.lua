util.event.on("entity:created", function(entity)
    core.engine.print("info", "Server - Entity created:", entity:get_type())
end)

util.event.on("entity:destroyed", function(entity)
    core.engine.print("info", "Server - Entity destroyed:", entity:get_type())
end)


-- ============================================================
-- Floor (static, server-authoritative -> synced to every client)
-- ============================================================

util.timer.create(function()
    -- Visual + concave collision for the town mesh (single body)
    local floor_model = core.model.create("assets/town.glb")
    local floor_body  = physics.static.create(1) -- authority 1 = server
    local floor_shape = physics.collision_shape.create(floor_body)
    print("warn", floor_shape:set_shape_mesh(floor_model, {
        shape_type = "concave",
        include_children = true,
        filters = {}
    }))
    floor_model:set_parent(floor_body)
    floor_body:set_global_position({0, 0, 0})
end, 1, 1)


-- ============================================================
-- Test balls (dynamic, server-authoritative)
-- ============================================================

util.timer.create(function()
    for i = 1, 50, 1 do
        local ball_model = core.model.create("assets/basketball.glb")
        local ball_body  = physics.rigid.create(1) -- authority 1 = server
        local ball_shape = physics.collision_shape.create(ball_body)
        ball_model:set_parent(ball_body)
        ball_model:set_position({0, 0, 0})

        -- Prefer a simple sphere for stable contact; mesh is fine too
        ball_shape:set_shape_sphere(1)
        -- print("warn", ball_shape:set_shape_mesh(ball_model, { include_children = true }))

        ball_body:set_global_position({1 + i, 4, 0})
        ball_body:set_mass(0.5)          -- try 0.1 (light) / 5 (heavy) to feel the difference
        ball_body:set_linear_damp(0.15)
        ball_body:set_angular_damp(0.2)
    end
    core.engine.print("info", "Server - Spawned physics test balls")
end, 1, 1)


-- ============================================================
-- Impulse relay: client reports contact, server applies force
-- ============================================================
-- Clients freeze non-authority rigid bodies (kinematic proxies).
-- After move_and_slide they emit physics:rigid_impulse with
-- (net_id, impulse_vec) where the vector is
--     push_direction * (approach_speed * client PUSH_STRENGTH).
-- We turn that back into "how fast was the character walking into this
-- thing" and solve a simple character-vs-body collision using BOTH masses:
--
--     dv_body = (1 + RESTITUTION) * approach_speed * M_char / (M_char + M_body)
--     impulse = dv_body * M_body
--
-- So a body much lighter than the character flies off at ~your speed, and a
-- body much heavier than the character barely moves. A faster character
-- always pushes faster.

local CHARACTER_MASS       = 10.0  -- how "heavy" a player is when pushing. Use the same
                                   -- scale as your bodies: bodies well below this fly,
                                   -- bodies above it get sluggish, ~equal = half speed.
local RESTITUTION          = 0.1   -- 0 = shove, higher = bouncier launch

util.event.on("physics:rigid_impulse", function(net_id, impulse)
    if type(net_id) ~= "number" or type(impulse) ~= "table" then return end

    local ix, iy, iz = impulse[1], impulse[2], impulse[3]
    if type(ix) ~= "number" or type(iy) ~= "number" or type(iz) ~= "number" then return end

    local mag = util.math.sqrt(ix * ix + iy * iy + iz * iz)
    if mag ~= mag or mag < 0.001 then return end -- also rejects NaN

    local entity = core.engine.get_entity_by_net_id(net_id)
    if not entity then return end
    local t = entity:get_type()
    if t ~= "physics.rigid" then return end

    local m_body = entity:get_mass()
    if type(m_body) ~= "number" or m_body <= 0 then return end

    -- Direction of the push + how fast the character was moving into the body
    local dx, dy, dz = ix / mag, iy / mag, iz / mag
    local approach_speed = mag

    -- Velocity the body should gain: depends on the mass ratio
    local dv = (1.0 + RESTITUTION) * approach_speed * CHARACTER_MASS / (CHARACTER_MASS + m_body)

    -- The engine applies dv = impulse / mass, so multiply mass back in
    local J = dv * m_body

    -- Server is authority; every client interpolates the same simulated result.
    entity:apply_central_impulse({ dx * J, dy * J, dz * J })
end)


-- ============================================================
-- Per-player character bodies
-- ============================================================

local players      = {} -- [peer_id] = { body, shape, model }
local spawn_index  = 0
local SPAWN_SPACING = 4.0

util.event.on("peer:resource:started", function(peer_id, resource)
    if resource ~= util.resource.current() then return false end

    spawn_index = spawn_index + 1
    local spawn_pos = { (spawn_index - 1) * SPAWN_SPACING, 100, 0 }

    local model = core.model.create("assets/asset.glb", peer_id)
    local body  = physics.character.create(peer_id)
    local shape = physics.collision_shape.create(body)

    --[[
    core.engine.iprint(model:get_components())
    model:set_component_rendered("*hair_*", false)
    core.engine.iprint(model:get_components())
    core.engine.iprint(model:get_components(true))
    ]]

    shape:set_shape_capsule(0.6, 1.8)
    model:set_parent(body)
    model:set_position({0, -1.8 * 0.5, 0})
    model:set_rotation({0, 180, 0})

    body:set_motion_mode(physics.character.motion_mode.GROUNDED)
    body:set_global_position(spawn_pos)
    body:set_syncer(peer_id)

    -- Animation layers live on the MODEL — peer must own it to broadcast.
    model:set_syncer(peer_id)

    players[peer_id] = { body = body, shape = shape, model = model }
    core.engine.print("info", "Server - Spawned character for peer", peer_id, "at x =", spawn_pos[1])

    util.event.emit("own_character:incoming", { remote = true, peer = peer_id }, body:get_net_id(), model:get_net_id())
end)

util.event.on("network:peer:leave", function(peer_id)
    local data = players[peer_id]
    if data then
        data.body:destroy() -- despawns parented model on every client
        players[peer_id] = nil
    end
end)