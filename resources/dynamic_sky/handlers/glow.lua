----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/glow.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Sun bloom through the engine glow ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state


---------------
--[[ Utils ]]--
---------------

local private = {}

-- Turns the engine glow on or off.
-- The sun disc is rendered HDR, so the engine's own glow (gfx.glow) blooms it. The glow works on the finished
-- picture, so geometry in front of the sun hides it and only the exposed part of the disc blooms (blurred over the edges).
-- The threshold is above normal scene brightness so nothing else lights up.
function private.apply(on)
    gfx.glow.set_enabled(on)
    if not on then return end

    gfx.glow.set_hdr_bleed_threshold(Config.glow_threshold)
    gfx.glow.set_hdr_bleed_scale(Config.glow_scale)
    gfx.glow.set_hdr_luminance_cap(Config.glow_cap)
    gfx.glow.set_intensity(Config.glow_intensity)
    gfx.glow.set_strength(Config.glow_strength)
    gfx.glow.set_bloom(0.0)
    gfx.glow.set_normalized(true)
    gfx.glow.set_blend_mode(gfx.glow.blend_mode.ADDITIVE)
    for i = 1, #Config.glow_levels do 
        gfx.glow.set_level_intensity(i - 1, Config.glow_levels[i]) 
    end
end


------------------
--[[ Handlers ]]--
------------------

-- Turns the engine glow on at start when it is enabled in the config.
Sky.on("init", function()
    if state.glow then private.apply(true) end
end)


------------------
--[[ Commands ]]--
------------------

-- Toggles the bloom around the sun (uses the engine glow)
-- Usage: /sky_glow [on|off]
util.input.register("sky_glow", function(args)
    state.glow = Sky.switch(args[1], state.glow)
    private.apply(state.glow)
    core.engine.print("info", util.string.format("Sun bloom %s", state.glow and "on" or "off"))
end)
