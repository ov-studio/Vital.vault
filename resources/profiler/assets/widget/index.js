// ------------------------------------------------------------------
// Panel config lifecycle:
//   1. Lua calls init_panels(config_json) once, after load_url.
//      config_json is an array of panel definitions, e.g.:
//        [{
//          id: "natives", title: "NATIVES", source: "native",
//          graphs: [{ id, label, stat, divisor, decimals, unit_suffix,
//                     min_floor, sub_stat, sub_mode,
//                     // sub_mode: "ms" | "percent" | "value"
//                     // "value" also accepts sub_divisor/sub_decimals/
//                     // sub_unit_suffix to format independently of the
//                     // main value (defaults to the main ones) }, ...]
//        }, ...]
//   2. build_panels() creates every panel's DOM (header, optional
//      graphs, rows, resize handle) purely from that config -- no
//      panel/graph is ever referenced by name in this file.
//   3. Lua calls update_monitor(data_json) on every draw tick, where
//      data_json is a map of source -> [{label, value}, ...]. Each
//      panel looks up its own `source` in that map.
// ------------------------------------------------------------------

// Lua's JSON encoder can't distinguish an empty array from an empty
// object when encoding an empty table, so a panel with no graphs may
// arrive as `graphs: {}` instead of `graphs: []`. Route every read of
// panel.graphs through this so that ambiguity can never throw and
// silently abort a panel build (which also skips layout_panels()).
function as_array(v) {
  return Array.isArray(v) ? v : [];
}

var panels_config = null;
var panels_config_raw = null; // last raw config_json successfully applied
var graphs = {};   // key: `${panel.id}::${graph.id}` -> graph state
var top_z = 0;

// Lua calls this on every draw tick (not just once after load_url),
// because the webview may not have finished loading the page the first
// time it's sent -- a single early call would otherwise be lost forever
// and the widget would stay blank. Re-sending is cheap: if the config
// hasn't changed since the last successful build, this is a no-op.
function init_panels(config_json) {
  if (config_json === panels_config_raw) return;
  panels_config_raw = config_json;
  build_panels(JSON.parse(config_json));
}

function build_panels(config) {
  panels_config = config;
  graphs = {};
  top_z = 0;

  var root = document.getElementById('panels-root');
  root.innerHTML = '';

  config.forEach(function (panel) {
    // A single malformed panel entry should never abort the whole
    // build (which would also skip layout_panels() and leave every
    // panel after it missing/misplaced) -- isolate it instead.
    try {
      var panel_el = document.createElement('div');
      panel_el.className = 'panel';
      panel_el.id = 'panel-' + panel.id;
      top_z += 1;
      panel_el.style.zIndex = top_z;

      var header = document.createElement('div');
      header.className = 'panel-header';
      header.setAttribute('data-panel', panel_el.id);
      header.innerHTML =
        '<span class="title">' + panel.title + '</span>' +
        '<span class="count" id="' + panel.id + '-count">#0</span>';
      panel_el.appendChild(header);
      wire_drag(header);

      as_array(panel.graphs).forEach(function (g) {
        var canvas_id = panel.id + '-' + g.id + '-canvas';
        var value_id = panel.id + '-' + g.id + '-value';

        var graph_el = document.createElement('div');
        graph_el.className = 'panel-graph';
        graph_el.id = panel.id + '-' + g.id + '-graph';
        graph_el.innerHTML =
          '<div class="graph-label">' +
            '<span class="graph-key">' + g.label + '</span>' +
            '<span class="graph-val" id="' + value_id + '">0</span>' +
          '</div>' +
          '<canvas id="' + canvas_id + '"></canvas>';
        panel_el.appendChild(graph_el);

        graphs[panel.id + '::' + g.id] = {
          config: g,
          canvas_id: canvas_id,
          value_id: value_id,
          history: [],
          min_floor: (g.min_floor !== undefined) ? g.min_floor : 1
        };
      });

      var rows_el = document.createElement('div');
      rows_el.className = 'panel-rows';
      rows_el.id = panel.id + '-rows';
      panel_el.appendChild(rows_el);

      var resize_el = document.createElement('div');
      resize_el.className = 'panel-resize';
      resize_el.setAttribute('data-rows', rows_el.id);
      panel_el.appendChild(resize_el);
      wire_resize(resize_el);

      root.appendChild(panel_el);
    } catch (err) {
      console.error('Failed to build panel "' + (panel && panel.id) + '":', err);
    }
  });

  layout_panels();
}

// Anchors the first panel top-right, then chains every subsequent panel
// immediately to the left of the previous one. Works for any number of
// panels, in whatever order they appear in the config.
function layout_panels() {
  if (!panels_config) return;
  var prev_left = null;

  panels_config.forEach(function (panel, i) {
    var el = document.getElementById('panel-' + panel.id);
    if (!el) return;
    el.style.top = '1vh';

    if (i === 0) {
      el.style.right = '1vw';
      el.style.left = 'auto';
    } 
    else {
      el.style.right = 'auto';
      el.style.left = (prev_left - el.offsetWidth - window.innerWidth * 0.01) + 'px';
    }
    prev_left = el.getBoundingClientRect().left;
  });
}

window.addEventListener('resize', function () {
  layout_panels();
  Object.keys(graphs).forEach(function (key) { draw_sparkline(graphs[key]); });
});

function bring_to_front(panel_id) {
  var el = document.getElementById(panel_id);
  top_z += 1;
  el.style.zIndex = top_z;
}

var drag = null;
function wire_drag(header) {
  header.addEventListener('mousedown', function (e) {
    if (e.button !== 0) return;
    var panel_id = header.getAttribute('data-panel');
    bring_to_front(panel_id);
    var el = document.getElementById(panel_id);
    var rect = el.getBoundingClientRect();
    drag = { el: el, ox: e.clientX - rect.left, oy: e.clientY - rect.top };
    e.preventDefault();
  });
}

var resize = null;
function wire_resize(handle) {
  handle.addEventListener('mousedown', function (e) {
    if (e.button !== 0) return;
    var rows_el = document.getElementById(handle.getAttribute('data-rows'));
    var panel_el = rows_el.closest('.panel');
    if (panel_el) bring_to_front(panel_el.id);
    resize = { rows_el: rows_el, start_y: e.clientY, start_h: rows_el.offsetHeight };
    e.preventDefault();
  });
}

document.addEventListener('mousemove', function (e) {
  if (drag) {
    var x = Math.max(0, Math.min(window.innerWidth - drag.el.offsetWidth, e.clientX - drag.ox));
    var y = Math.max(0, Math.min(window.innerHeight - drag.el.offsetHeight, e.clientY - drag.oy));
    drag.el.style.left = x + 'px';
    drag.el.style.top = y + 'px';
  }
  if (resize) {
    var new_h = Math.max(50, e.clientY - resize.start_y + resize.start_h);
    resize.rows_el.style.maxHeight = new_h + 'px';
  }
});

document.addEventListener('mouseup', function () { drag = null; resize = null; });

var HISTORY_MAX = 120;

function get_theme_color(var_name, fallback) {
  var v = getComputedStyle(document.documentElement).getPropertyValue(var_name).trim();
  if (!v) v = getComputedStyle(document.body).getPropertyValue(var_name).trim();
  return v || fallback;
}

function draw_sparkline(graph) {
  var canvas = document.getElementById(graph.canvas_id);
  var history = graph.history;
  if (!canvas || history.length === 0) return;

  var dpr = window.devicePixelRatio || 1;
  var cw = canvas.clientWidth;
  var ch = canvas.clientHeight;
  if (cw === 0 || ch === 0) return;
  if (canvas.width !== Math.round(cw * dpr) || canvas.height !== Math.round(ch * dpr)) {
    canvas.width = Math.round(cw * dpr);
    canvas.height = Math.round(ch * dpr);
  }

  var ctx = canvas.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, cw, ch);

  var max_val = Math.max.apply(null, history);
  max_val = Math.max(max_val * 1.8, graph.min_floor);
  var n = history.length;
  var step_x = cw / Math.max(n - 1, 1);
  var pad = 5;
  var points = [];
  for (var i = 0; i < n; i++) {
    var x = i * step_x;
    var y = pad + (ch - pad * 2) - (history[i] / max_val) * (ch - pad * 2);
    points.push([x, y]);
  }
  if (points.length === 1) {
    points.push([cw, points[0][1]]);
  }

  var blue = get_theme_color('--blue', '#3b82f6');
  var gradient = ctx.createLinearGradient(0, 0, 0, ch);
  gradient.addColorStop(0, blue);
  gradient.addColorStop(1, 'transparent');

  function trace_path(ctx2) {
    ctx2.moveTo(points[0][0], points[0][1]);
    for (var m = 1; m < points.length - 1; m++) {
      var mx = (points[m][0] + points[m + 1][0]) / 2;
      var my = (points[m][1] + points[m + 1][1]) / 2;
      ctx2.quadraticCurveTo(points[m][0], points[m][1], mx, my);
    }
    if (points.length > 1) {
      var last = points[points.length - 1];
      ctx2.lineTo(last[0], last[1]);
    }
  }

  ctx.beginPath();
  ctx.moveTo(points[0][0], ch);
  ctx.lineTo(points[0][0], points[0][1]);
  trace_path(ctx);
  ctx.lineTo(points[points.length - 1][0], ch);
  ctx.closePath();
  ctx.save();
  ctx.globalAlpha = 0.4;
  ctx.fillStyle = gradient;
  ctx.fill();
  ctx.restore();
  ctx.beginPath();
  trace_path(ctx);
  ctx.strokeStyle = blue;
  ctx.lineWidth = 1.25;
  ctx.lineJoin = 'round';
  ctx.lineCap = 'round';
  ctx.stroke();
}

function push_history(graph, value) {
  graph.history.push(value);
  if (graph.history.length > HISTORY_MAX) graph.history.shift();
}

function find_item(items, label) {
  return items.filter(function (i) { return i.label === label; })[0];
}

// Renders every graph configured on a panel (if any) from that panel's
// own item list. Nothing here is specific to fps/memory -- the stat to
// read, how to scale it, and what the parenthetical sub-value means all
// come from the graph's config (see the header comment for the shape).
function update_graphs(panel, items) {
  as_array(panel.graphs).forEach(function (g) {
    var graph = graphs[panel.id + '::' + g.id];
    if (!graph) return;

    var divisor = g.divisor || 1;
    var decimals = (g.decimals !== undefined) ? g.decimals : 0;

    var main_item = find_item(items, g.stat);
    var raw = main_item ? parseFloat(main_item.value) : 0;
    if (isNaN(raw)) raw = 0;
    var main_val = raw / divisor;

    push_history(graph, main_val);

    var value_el = document.getElementById(graph.value_id);
    if (value_el) {
      var text = main_val.toFixed(decimals) + (g.unit_suffix || '');
      var sub_text = '';

      if (g.sub_stat) {
        var sub_item = find_item(items, g.sub_stat);
        if (sub_item) {
          if (g.sub_mode === 'ms') {
            sub_text = sub_item.value.replace(' MS', 'ms').toLowerCase();
          } 
          else if (g.sub_mode === 'percent') {
            var sub_val = parseFloat(sub_item.value) / divisor;
            if (!isNaN(sub_val) && sub_val > 0) {
              sub_text = Math.round((main_val / sub_val) * 100) + '%';
            }
          } 
          else if (g.sub_mode === 'value') {
            var sub_divisor = (g.sub_divisor !== undefined) ? g.sub_divisor : divisor;
            var sub_decimals = (g.sub_decimals !== undefined) ? g.sub_decimals : decimals;
            var sub_unit = (g.sub_unit_suffix !== undefined) ? g.sub_unit_suffix : (g.unit_suffix || '');
            var sub_num = parseFloat(sub_item.value) / sub_divisor;
            if (!isNaN(sub_num)) {
              sub_text = sub_num.toFixed(sub_decimals) + sub_unit;
            }
          }
        }
      }

      if (sub_text) text += ' <span class="val-sub">(' + sub_text + ')</span>';
      value_el.innerHTML = text;
    }

    draw_sparkline(graph);
  });
}

function update_monitor(data_json) {
  if (!panels_config) return;
  var data = JSON.parse(data_json);

  panels_config.forEach(function (panel) {
    var items = data[panel.source] || [];
    render_panel(panel.id, items);
    if (as_array(panel.graphs).length) {
      update_graphs(panel, items);
    }
  });
}

function render_panel(id, items) {
  var count_el = document.getElementById(id + '-count');
  var rows_el = document.getElementById(id + '-rows');
  if (!count_el || !rows_el) return;
  count_el.textContent = '#' + items.length;

  var existing = rows_el.children;
  for (var i = 0; i < items.length; i++) {
    var row;
    if (i < existing.length) {
      row = existing[i];
    }
    else {
      row = document.createElement('div');
      row.className = 'row';
      row.innerHTML = '<span class="key"></span><span class="val"></span>';
      rows_el.appendChild(row);
    }
    row.children[0].textContent = items[i].label;
    row.children[1].textContent = items[i].value;
  }
  while (rows_el.children.length > items.length) {
    rows_el.removeChild(rows_el.lastChild);
  }
}
