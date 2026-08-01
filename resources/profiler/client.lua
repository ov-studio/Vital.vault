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

function private.setup()
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

    for _, kind in ipairs(core.engine.get_entity_types()) do
        util.monitor.register(
            kind.."_entity_count",
            util.string.upper(kind).."_ENTITY_COUNT",
            function() return #core.engine.get_entities(kind) end,
            util.monitor.stat_format.QUANTITY
        )
    end    
end


-- Resolves the display suffix appended to a stat's value based on its
-- format (e.g. TIME -> " MS", MEMORY -> " MB", PERCENTAGE -> " %"), so
-- the widget can render values like "12 MS" or "48 %" without each stat
-- needing to know how to format itself. Formats with no known suffix
-- (e.g. QUANTITY) resolve to an empty string.
function private.get_unit(fmt)
    if fmt == util.monitor.stat_format.TIME then return " MS"
    elseif fmt == util.monitor.stat_format.MEMORY then return " MB"
    elseif fmt == util.monitor.stat_format.PERCENTAGE then return " %" end
    return ""
end


-- Serializes a list of monitor stats into the JSON array string expected
-- by the webview widget, e.g.:
--   [{"label":"ped entity count","value":"42"}, ...]
-- Each stat's value is fetched live via util.monitor.get, rounded to 2
-- decimal places, and suffixed with its unit (if any) before being
-- packed into the resulting label/value pair.
function private.to_json(list)
    local parts = {}
    for _, item in ipairs(list) do
        local value = util.math.round(util.monitor.get(item.id), 2)
        local label = util.string.gsub(item.name, "_", " ")
        local unit = private.get_unit(item.format)
        parts[#parts + 1] = {
            label = label,
            value = tostring(value)..unit
        }
    end
    return util.table.encode(parts)
end


----------------
--[[ Events ]]--
----------------

util.event.on("resource:started", function(name)
    if name ~= util.resource.current() then return false end
    private.setup()
end)

util.event.on("sandbox:draw", function()
    local lists = util.monitor.list()
    private.view:eval(util.string.format(
        "update_monitor(%q, %q);",
        private.to_json(lists.native),
        private.to_json(lists.custom)
    ))
end)


------------------
--[[ Commands ]]--
------------------

-- Command to toggle profiler overlay via console
-- Usage: /profiler
util.input.register("profiler", function(args)
    private.view:set_visible(not private.view:is_visible())
    core.engine.print("info", util.string.format("Profiler overlay %s", (private.view:is_visible() and "enabled") or "disabled"))
end)