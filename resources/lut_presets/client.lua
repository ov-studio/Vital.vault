----------------------------------------------------------------
--[[ Resource: LUT Presets
     Script: client.lua
     Author: ov-studio
     Developer(s): Aviril, Аниса
     DOC: 24/07/2026
     Desc: Curated LUT presets ]]--
----------------------------------------------------------------


-------------------
--[[ Util: LUT ]]--
-------------------

-- Master list of every LUT preset bundled with this resource, grouped by
-- collection ("Cinematic", "Moody", "Portrait", "ColorBoost", "Lutify").
-- Each entry is the relative path (minus extension) used to look up and
-- apply the LUT via gfx.adjustment.set_lut.
local private = {
    list = {
        "assets/lut/Cinematic/Cinematic 1.png",
        "assets/lut/Cinematic/Cinematic 2.png",
        "assets/lut/Cinematic/Cinematic 3.png",
        "assets/lut/Cinematic/Cinematic 4.png",
        "assets/lut/Cinematic/Cinematic 5.png",
        "assets/lut/Cinematic/Cinematic 6.png",
        "assets/lut/Cinematic/Cinematic 7.png",
        "assets/lut/Cinematic/Cinematic 8.png",
        "assets/lut/Cinematic/Cinematic 9.png",
        "assets/lut/Cinematic/Cinematic 10.png",
        "assets/lut/Moody/Moody 1.png",
        "assets/lut/Moody/Moody 2.png",
        "assets/lut/Moody/Moody 3.png",
        "assets/lut/Moody/Moody 4.png",
        "assets/lut/Moody/Moody 5.png",
        "assets/lut/Moody/Moody 6.png",
        "assets/lut/Moody/Moody 7.png",
        "assets/lut/Moody/Moody 8.png",
        "assets/lut/Moody/Moody 9.png",
        "assets/lut/Moody/Moody 10.png",
        "assets/lut/Portrait/Portrait 1.png",
        "assets/lut/Portrait/Portrait 2.png",
        "assets/lut/Portrait/Portrait 3.png",
        "assets/lut/Portrait/Portrait 4.png",
        "assets/lut/Portrait/Portrait 5.png",
        "assets/lut/Portrait/Portrait 6.png",
        "assets/lut/Portrait/Portrait 7.png",
        "assets/lut/Portrait/Portrait 8.png",
        "assets/lut/Portrait/Portrait 9.png",
        "assets/lut/Portrait/Portrait 10.png",
        "assets/lut/ColorBoost/Aqua and Orange Dark.png",
        "assets/lut/ColorBoost/Aqua.png",
        "assets/lut/ColorBoost/Blues.png",
        "assets/lut/ColorBoost/Earth Tone Boost.png",
        "assets/lut/ColorBoost/Green Blues.png",
        "assets/lut/ColorBoost/Green Yellow.png",
        "assets/lut/ColorBoost/Oranges.png",
        "assets/lut/ColorBoost/Purple.png",
        "assets/lut/ColorBoost/Reds.png",
        "assets/lut/ColorBoost/Reds Oranges and Yellows.png",
        "assets/lut/Lutify/2-Strip Process.png",
        "assets/lut/Lutify/Berlin Sky.png",
        "assets/lut/Lutify/Chrome 1.png",
        "assets/lut/Lutify/Classic Teal and Orange.png",
        "assets/lut/Lutify/Fade to Green.png",
        "assets/lut/Lutify/Film Print 1.png",
        "assets/lut/Lutify/Film Print 2.png",
        "assets/lut/Lutify/French Comedy.png",
        "assets/lut/Lutify/Studio Skin Tone Shaper.png",
        "assets/lut/Lutify/Vintage Chrome.png",
        "assets/lut/Lutify/Blue Architecture.png",
        "assets/lut/Lutify/Blue Hour.png",
        "assets/lut/Lutify/Cold Chrome.png",
        "assets/lut/Lutify/Crisp Autumn.png",
        "assets/lut/Lutify/Dark And Somber.png",
        "assets/lut/Lutify/Hard Boost.png",
        "assets/lut/Lutify/Long Beach Morning.png",
        "assets/lut/Lutify/Lush Green.png",
        "assets/lut/Lutify/Magic Hour.png",
        "assets/lut/Lutify/Natural Boost.png",
        "assets/lut/Lutify/Orange And Blue.png",
        "assets/lut/Lutify/Soft Black And White.png",
        "assets/lut/Lutify/Waves.png"
    }
}

-- Returns the full list of available preset paths, in display order.
-- Intended for external callers (e.g. a menu UI) building a picker.
function private.get_list()
    return private.list
end

-- Returns the 1-based index of the currently applied LUT within
-- private.list, or `false` if no LUT from this pack is active.
function private.get_lut()
    local path = gfx.adjustment.get_lut()
    for i = 1, #private.list, 1 do
        local j = private.list[i]
        if path == private.list[i] then
            return i
        end
    end
    return false
end

-- Applies the LUT at the given index (as returned by get_list/get_lut).
-- Returns false if the index is missing, non-numeric, or out of range.
function private.set_lut(index)
    index = tonumber(index)
    if not private.list[index] then return false end
    return gfx.adjustment.set_lut(private.list[index])
end

-- Clears any active LUT, restoring the default (unadjusted) color grade.
function private.reset_lut()
    return gfx.adjustment.reset_lut()
end


-----------------
--[[ Exports ]]--
-----------------

-- Public API surface exposed to other resources: browse presets, check
-- or change the active one, and reset back to no grading.
util.export.register("get_list", private.get_list)
util.export.register("get_lut", private.get_lut)
util.export.register("set_lut", private.set_lut)
util.export.register("reset_lut", private.reset_lut)


------------------
--[[ Commands ]]--
------------------

-- Command to apply presets directly via console
-- Usage: /lut <index>
util.input.register("lut", function(args)
    local index = tonumber(args[1])
    if not index then return core.engine.print("warn", "Usage: lut <index>") end
    if not private.set_lut(index) then return core.engine.print("warn", util.string.format("Usage: lut index #%s out of range [1-%s]", index, util.table.len(private.list))) end
    core.engine.print("info", util.string.format("Lut successfully set to index #%s (%s)", index, private.list[index]))
end)
