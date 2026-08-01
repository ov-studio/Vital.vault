----------------------------------------------------------------
--[[ Resource: Profiler
     Script: shared.lua
     Author: ov-studio
     Developer(s): Kivi
     DOC: 01/08/2026
     Desc: In-game profiler overlay ]]--
----------------------------------------------------------------


--------------------------------
--[[ Setup: Entity counters ]]--
--------------------------------

-- Registers one monitor stat per entity type known to the engine
-- (e.g. "ped", "vehicle", "object"), so each type's live count is
-- tracked automatically without needing to hardcode a list here.
--   Stat id:    "<kind>_entity_count"          e.g. "ped_entity_count"
--   Stat label: "<KIND>_ENTITY_COUNT"          e.g. "PED_ENTITY_COUNT"
--   Value:      number of currently spawned entities of that kind
for _, kind in ipairs(core.engine.get_entity_types()) do
    util.monitor.register(
        kind.."_entity_count",
        util.string.upper(kind).."_ENTITY_COUNT",
        function() return #core.engine.get_entities(kind) end,
        util.monitor.stat_format.QUANTITY
    )
end


-------------------------------
--[[ Util: Stat formatting ]]--
-------------------------------

-- Returns the display suffix for a given stat format, so the widget
-- can show values like "12 MS" or "48 %" without each stat needing
-- to know how to render itself.
local function get_unit(fmt)
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
local function stats_to_json(list)
    local parts = {}
    for _, item in ipairs(list) do
        local value = util.math.round(util.monitor.get(item.id), 2)
        local label = util.string.gsub(item.name, "_", " ")
        local unit  = get_unit(item.format)
        parts[#parts + 1] = util.string.format(
            '{"label":"%s","value":"%s%s"}',
            label, tostring(value), unit
        )
    end
    return "["..util.table.concat(parts, ",").."]"
end


--------------------------
--[[ Setup: Overlay UI ]]--
--------------------------

-- Creates the transparent, click-through-by-default webview that
-- renders the monitor panels (see assets/widget/index.html), and
-- makes it visible immediately on resource start.
local monitor_view = core.webview.create({ forward_input = true })
monitor_view:load_url("assets/widget/index.html")
monitor_view:set_visible(true)


----------------
--[[ Events ]]--
----------------

-- Every frame, pulls the current native (built-in) and custom monitor
-- stat lists, serializes each to JSON, and forwards them into the
-- webview by calling its `update_monitor(natives, custom)` JS function.
util.event.on("sandbox:draw", function()
    local lists = util.monitor.list()
    monitor_view:eval(util.string.format(
        "update_monitor(%q, %q);",
        stats_to_json(lists.native),
        stats_to_json(lists.custom)
    ))
end)