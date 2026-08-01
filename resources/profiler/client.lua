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

-- Single source of truth for every panel the widget renders. Add/remove/
-- reorder panels here only -- the webview builds its DOM from this table
-- (via init_panels) and nothing about a panel's title, source list, or
-- graphs needs to be touched in index.html/index.js.
--
-- panel.source must match a key returned by util.monitor.list() (e.g.
-- "native"/"custom"); any source referenced here is automatically pulled
-- and shipped to the widget on every draw, no extra wiring required.
--
-- panel.graphs is optional -- omit the key entirely for panels with no
-- graphs (don't set it to an empty table; see the "entities" panel
-- below). Each graph reads a stat by label from that
-- panel's own item list and renders it as a sparkline:
--   id         dom-safe suffix used to namespace the graph's elements
--   label      text shown above the value (e.g. "FPS")
--   stat       label of the item to read the main value from
--   divisor    raw value is divided by this before display/history
--   decimals   decimal places shown for the main value
--   unit_suffix  string appended after the main value (e.g. " MB")
--   min_floor  minimum ceiling used when scaling the sparkline
--   sub_stat   optional second item to derive a parenthetical from
--   sub_mode   "ms" (reformat a " MS" value), "percent" (sub as max),
--              or "value" (format sub on its own; see the "mem" graph
--              below for its sub_divisor/sub_decimals/sub_unit_suffix
--              overrides)
private.panels = {
    {
        id = "natives",
        title = "NATIVES",
        source = "native",
        graphs = {
            {
                id = "fps",
                label = "FPS",
                stat = "TIME FPS",
                divisor = 1,
                decimals = 0,
                min_floor = 30,
                sub_stat = "TIME PROCESS",
                sub_mode = "ms"
            },
            {
                id = "mem",
                label = "MEMORY",
                stat = "RENDER VIDEO MEM USED",
                divisor = 1,
                decimals = 1,
                unit_suffix = " MB",
                min_floor = 1,
                sub_stat = "RENDER TEXTURE MEM USED",
                sub_mode = "value"
            }
        }
    },
    {
        id = "entities",
        title = "ENTITIES",
        source = "custom"
    }
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

    -- Encoded once and re-sent every draw tick (see below) instead of
    -- once here, since the webview page usually hasn't finished loading
    -- yet at this point -- a single early eval would be silently lost
    -- and the widget would never build its panels.
    private.panels_json = util.table.encode(private.panels)

    -- Entity counter
    for _, kind in ipairs(core.engine.get_entity_types()) do
        util.monitor.register(
            kind.."_entity_count",
            util.string.upper(kind).."_ENTITY_COUNT",
            function() return #core.engine.get_entities(kind) end,
            util.monitor.stat_format.QUANTITY
        )
    end

    -- Derive the set of monitor sources actually needed from the panel
    -- config, so sandbox:draw never has to hardcode "native"/"custom".
    private.sources = {}
    for _, panel in ipairs(private.panels) do
        private.sources[panel.source] = true
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


-- Serializes a list of monitor stats into the label/value pair list
-- expected by the widget, e.g.:
--   [{"label":"ped entity count","value":"42"}, ...]
-- Each stat's value is fetched live via util.monitor.get, rounded to 2
-- decimal places, and suffixed with its unit (if any) before being
-- packed into the resulting label/value pair. Returns a plain Lua table
-- (not yet encoded) so callers can batch multiple lists into one payload.
function private.to_json_list(list)
    local parts = {}
    for _, item in ipairs(list) do
        local raw = util.monitor.get(item.id)
        local divisor = private.get_divisor(item.format)
        local value = util.math.round(raw / divisor, 2)
        local label = util.string.gsub(item.name, "_", " ")
        local unit = private.get_unit(item.format)
        parts[#parts + 1] = {
            label = label,
            value = tostring(value)..unit
        }
    end
    return parts
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
    local data = {}
    for source in pairs(private.sources) do
        data[source] = private.to_json_list(lists[source] or {})
    end

    -- init_panels is re-sent every tick alongside update_monitor. It's a
    -- no-op on the JS side once the config has already been applied, so
    -- this just guarantees the very first successful eval (whenever the
    -- webview page actually finishes loading) is the one that sticks.
    private.view:eval(util.string.format(
        "init_panels(%q); update_monitor(%q);",
        private.panels_json,
        util.table.encode(data)
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