window.addEventListener('load', function () {
  var pn = document.getElementById('panel-natives');
  var pe = document.getElementById('panel-entities');
  pn.style.top = '1vh';
  pn.style.right = '1vw';
  pn.style.left = 'auto';
  var rn = pn.getBoundingClientRect();
  pe.style.top = '1vh';
  pe.style.left = (rn.left - pe.offsetWidth - window.innerWidth * 0.01) + 'px';
});

window.addEventListener('resize', function () {
  var pn = document.getElementById('panel-natives');
  var pe = document.getElementById('panel-entities');
  pn.style.top = '1vh';
  pn.style.right = '1vw';
  pn.style.left = 'auto';
  var rn = pn.getBoundingClientRect();
  pe.style.top = '1vh';
  pe.style.left = (rn.left - pe.offsetWidth - window.innerWidth * 0.01) + 'px';
});

var top_z = 2;
function bring_to_front(panel_id) {
  var el = document.getElementById(panel_id);
  top_z += 1;
  el.style.zIndex = top_z;
}

var drag = null;
document.querySelectorAll('.panel-header').forEach(function (header) {
  header.addEventListener('mousedown', function (e) {
    if (e.button !== 0) return;
    var panel_id = header.getAttribute('data-panel');
    bring_to_front(panel_id);
    var el = document.getElementById(panel_id);
    var rect = el.getBoundingClientRect();
    drag = { el: el, ox: e.clientX - rect.left, oy: e.clientY - rect.top };
    e.preventDefault();
  });
});

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

var resize = null;
document.querySelectorAll('.panel-resize').forEach(function (handle) {
  handle.addEventListener('mousedown', function (e) {
    if (e.button !== 0) return;
    var rows_el = document.getElementById(handle.getAttribute('data-rows'));
    var panel_el = rows_el.closest('.panel');
    if (panel_el) bring_to_front(panel_el.id);
    resize = { rows_el: rows_el, start_y: e.clientY, start_h: rows_el.offsetHeight };
    e.preventDefault();
  });
});

var HISTORY_MAX = 120;
var graphs = {
  fps: { canvas_id: 'fps-canvas', history: [], min_floor: 30 },
  mem: { canvas_id: 'mem-canvas', history: [], min_floor: 1 }
};

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

function format_number(n) {
  return Math.round(n).toLocaleString();
}

function update_graphs(natives) {
  var fps_item = find_item(natives, 'TIME FPS');
  var ms_item = find_item(natives, 'TIME PROCESS');
  var fps_val = fps_item ? parseFloat(fps_item.value) : 0;
  if (isNaN(fps_val)) fps_val = 0;
  push_history(graphs.fps, fps_val);

  var fps_val_el = document.getElementById('fps-value');
  if (fps_val_el) {
    var fps_ms = ms_item ? ms_item.value.replace(' MS', 'ms').toLowerCase() : '';
    fps_val_el.innerHTML = Math.round(fps_val) + (fps_ms ? ' <span class="val-sub">(' + fps_ms + ')</span>' : '');
  }

  draw_sparkline(graphs.fps);
  var mem_item = find_item(natives, 'MEMORY STATIC');
  var mem_max_item = find_item(natives, 'MEMORY STATIC MAX');
  var mem_val_bytes = mem_item ? parseFloat(mem_item.value) : 0;
  if (isNaN(mem_val_bytes)) mem_val_bytes = 0;
  var mem_mb = mem_val_bytes / (1024 * 1024);
  push_history(graphs.mem, mem_mb);
  var mem_val_el = document.getElementById('mem-value');
  if (mem_val_el) {
    var mem_text = mem_mb.toFixed(1) + ' MB';
    if (mem_max_item) {
      var mem_max_mb = parseFloat(mem_max_item.value) / (1024 * 1024);
      if (mem_max_mb > 0) {
        var mem_pct = Math.round((mem_mb / mem_max_mb) * 100);
        mem_text += ' <span class="val-sub">(' + mem_pct + '%)</span>';
      }
    }
    mem_val_el.innerHTML = mem_text;
  }
  draw_sparkline(graphs.mem);
}

window.addEventListener('resize', function () {
  draw_sparkline(graphs.fps);
  draw_sparkline(graphs.mem);
});

function update_monitor(natives_json, entities_json) {
  var natives = JSON.parse(natives_json);
  render_panel('natives', natives);
  render_panel('entities', JSON.parse(entities_json));
  update_graphs(natives);
}

function render_panel(id, items) {
  var count_el = document.getElementById(id + '-count');
  var rows_el = document.getElementById(id + '-rows');
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