----------------------------------------------------------------
--[[ Resource: Profiler
     Script: shared.lua
     Author: ov-studio
     Developer(s): Kivi
     DOC: 01/08/2026
     Desc: In-game profiler overlay ]]--
----------------------------------------------------------------


------------------------
--[[ Util: Profiler ]]--
------------------------

local private = {
    command = "profiler"
}

private.view = core.webview.create({
    fullscreen = true,
    transparent = true,
    incognito = false,
    autoplay = false,
    zoomable = false,
    forward_input = true
})
private.view:load_url("assets/widget/index.html")
private.view:set_visible(true)


-- Registers one monitor stat per entity type known to the engine
-- (e.g. "ped", "vehicle", "object"), so each type's live count is
-- tracked automatically without needing to hardcode a list here.
--   Stat id:    "<kind>_entity_count"          e.g. "ped_entity_count"
--   Stat label: "<KIND>_ENTITY_COUNT"          e.g. "PED_ENTITY_COUNT"
--   Value:      number of currently spawned entities of that kind
function private.setup()
    for _, kind in ipairs(core.engine.get_entity_types()) do
        util.monitor.register(
            kind.."_entity_count",
            util.string.upper(kind).."_ENTITY_COUNT",
            function() return #core.engine.get_entities(kind) end,
            util.monitor.stat_format.QUANTITY
        )
    end    
end


-- Returns the display suffix for a given stat format ("TIME", "MEMORY",
-- "PERCENTAGE"), so the widget can show values like "12 MS" or "48 %"
-- without each individual stat needing to know how to render itself.
-- Formats with no known suffix (e.g. QUANTITY) render with none.
function private.get_unit(fmt)
    if fmt == util.monitor.stat_format.TIME then return " MS"
    elseif fmt == util.monitor.stat_format.MEMORY then return " MB"
    elseif fmt == util.monitor.stat_format.PERCENTAGE then return " %" end
    return ""
end

-- Converts a list of monitor stats into a JSON array string that the
-- webview widget understands, e.g.:
--   [{"label":"ped entity count","value":"42"}, ...]
-- Each entry's current value is read live via util.monitor.get,
-- rounded to 2 decimal places, and suffixed with its unit (if any).
function private.stats_to_json(list)
    local parts = {}
    for _, item in ipairs(list) do
        local value = util.math.round(util.monitor.get(item.id), 2)
        local label = util.string.gsub(item.name, "_", " ")
        local unit  = private.get_unit(item.format)
        parts[#parts + 1] = util.string.format(
            '{"label":"%s","value":"%s%s"}',
            label, tostring(value), unit
        )
    end
    return "["..util.table.concat(parts, ",").."]"
end


----------------
--[[ Events ]]--
----------------

-- Every frame, pulls the current native (built-in) and custom monitor
-- stat lists, serializes each to JSON, and forwards them into the
-- webview by calling its `update_monitor(natives, custom)` JS function.
util.event.on("sandbox:draw", function()
    local lists = util.monitor.list()
    private.view:eval(util.string.format(
        "update_monitor(%q, %q);",
        private.stats_to_json(lists.native),
        private.stats_to_json(lists.custom)
    ))
end)