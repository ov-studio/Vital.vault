----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/glow.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Sun bloom through the engine glow ]]--
----------------------------------------------------------------

local state = Sky.state


-- The sun disc is rendered HDR, so the engine's own glow (gfx.glow) blooms it. The glow works on the finished
-- picture, so geometry in front of the sun hides it and only the exposed part of the disc blooms (blurred over the edges).
-- The threshold is above normal scene brightness so nothing else lights up.
local function apply(on)
    if not gfx.glow then return end
    pcall(function()
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
        local lv = Config.glow_levels
        for i = 1, #lv do gfx.glow.set_level_intensity(i - 1, lv[i]) end
    end)
end

Sky.on("init", function()
    if state.glow then apply(true) end
end)


-----------------
--[[ Input ]]--
-----------------

-- sky_glow [on|off] : bloom around the sun (uses the engine glow)
util.input.register("sky_glow", function(args)
    state.glow = Sky.switch(args[1], state.glow)
    apply(state.glow)
    core.engine.print("info", "[dynamic_sky] sun bloom:", state.glow and "on" or "off")
end)
