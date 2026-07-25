----------------------------------------------------------------
--[[ Resource: Preset - LUT
     Script: client.lua
     Author: ov-studio
     Developer(s): Aviril, Tron, Mario, Аниса, A-Variakojiene
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
        "Cinematic/Cinematic 1",
        "Cinematic/Cinematic 2",
        "Cinematic/Cinematic 3",
        "Cinematic/Cinematic 4",
        "Cinematic/Cinematic 5",
        "Cinematic/Cinematic 6",
        "Cinematic/Cinematic 7",
        "Cinematic/Cinematic 8",
        "Cinematic/Cinematic 9",
        "Cinematic/Cinematic 10",
        "Moody/Moody 1",
        "Moody/Moody 2",
        "Moody/Moody 3",
        "Moody/Moody 4",
        "Moody/Moody 5",
        "Moody/Moody 6",
        "Moody/Moody 7",
        "Moody/Moody 8",
        "Moody/Moody 9",
        "Moody/Moody 10",
        "Portrait/Portrait 1",
        "Portrait/Portrait 2",
        "Portrait/Portrait 3",
        "Portrait/Portrait 4",
        "Portrait/Portrait 5",
        "Portrait/Portrait 6",
        "Portrait/Portrait 7",
        "Portrait/Portrait 8",
        "Portrait/Portrait 9",
        "Portrait/Portrait 10",
        "ColorBoost/Aqua and Orange Dark",
        "ColorBoost/Aqua",
        "ColorBoost/Blues",
        "ColorBoost/Earth Tone Boost",
        "ColorBoost/Green Blues",
        "ColorBoost/Green Yellow",
        "ColorBoost/Oranges",
        "ColorBoost/Purple",
        "ColorBoost/Reds",
        "ColorBoost/Reds Oranges and Yellows",
        "Lutify/2-Strip Process",
        "Lutify/Berlin Sky",
        "Lutify/Chrome 1",
        "Lutify/Classic Teal and Orange",
        "Lutify/Fade to Green",
        "Lutify/Film Print 1",
        "Lutify/Film Print 2",
        "Lutify/French Comedy",
        "Lutify/Studio Skin Tone Shaper",
        "Lutify/Vintage Chrome",
        "Lutify/Blue Architecture",
        "Lutify/Blue Hour",
        "Lutify/Cold Chrome",
        "Lutify/Crisp Autumn",
        "Lutify/Dark And Somber",
        "Lutify/Hard Boost",
        "Lutify/Long Beach Morning",
        "Lutify/Lush Green",
        "Lutify/Magic Hour",
        "Lutify/Natural Boost",
        "Lutify/Orange And Blue",
        "Lutify/Soft Black And White",
        "Lutify/Waves"
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
    local path = gfx.adjustment.get_lut() -- TODO: Verify if it returns the path correctly or indexed using :resourcename
    for i = 1, #private.list, 1 do
        local j = private.list[i]
        if path == private.list[i] then
            return i
        end
    end
    return false
end

-- Applies the LUT at the given index (as returned by get_list/get_lut).
-- Errors if the index is missing, non-numeric, or out of range.
function private.set_lut(index)
    index = tonumber(index)
    if not private.list[index] then
        error("Invalid lut index")
    end
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

-- Reserved for a future console command to preview/apply presets
-- directly (e.g. `lut <index>`). Not yet implemented.
--WIP