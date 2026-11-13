shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Dynamic Sky: rain splash droplets. Each particle is a small water bead thrown up from the impact.
// It is a camera-facing quad that stays upright and stretches along its (mostly vertical) motion:
// long and thin while it is fast, round at the top of its arc, then it fades.

uniform vec4  tint : source_color = vec4(0.82, 0.88, 1.0, 0.6);
uniform float drop_size = 0.012;     // bead radius (m)
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

varying vec2  v_uv;
varying float v_a;

uniform float lift = 0.03;           // metres: the drop that lands has gone a little below the surface when it is detected, so lift the splash

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz + vec3(0.0, lift, 0.0);
	float age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to = c - cam;
	float dist = max(length(to), 0.001);
	vec3 right = cross(vec3(0.0, 1.0, 0.0), to);
	float rl = length(right);
	right = (rl > 0.0001) ? right / rl : INV_VIEW_MATRIX[0].xyz;

	float h = fract(sin(dot(c.xz, vec2(12.9898, 78.233)) + c.y * 3.1) * 43758.5453);
	float sz = drop_size * (0.65 + 0.9 * h) + dist * 0.0007;       // never thinner than about a pixel
	float stretch = 1.0 + 2.6 * clamp(abs(age - 0.4) / 0.6, 0.0, 1.0);   // fast at launch and at impact, round at the apex

	vec3 world = c + right * (VERTEX.x * sz * 2.0) + vec3(0.0, 1.0, 0.0) * (VERTEX.y * sz * 2.0 * stretch);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));

	v_uv = VERTEX.xy * 2.0;
	v_a = (1.0 - smoothstep(0.55, 1.0, age)) * smoothstep(0.2, 0.9, dist) * (1.0 - smoothstep(7.0, 14.0, dist));
}

void fragment() {
	// bead: soft ellipse with a brighter core, a drop-like taper towards the bottom
	vec2 p = v_uv;
	p.y += 0.12 * p.y * p.y;
	float r = length(p * vec2(1.0, 0.8));
	float body = 1.0 - smoothstep(0.35, 1.0, r);
	float core = 1.0 - smoothstep(0.0, 0.55, r);
	vec3 bg = min(texture(screen_tex, SCREEN_UV).rgb, vec3(1.0));   // a sun reflection on the ground must not turn beads into sparks
	float lum = dot(bg, vec3(0.30, 0.59, 0.11));
	float env = clamp(lum * 1.5 + 0.025, 0.0, 1.0);
	ALBEDO = mix(bg * 1.3 + 0.008, tint.rgb * env * 1.25, 0.12);   // surface colour made lighter, only a trace of the weather tint
	ALPHA = clamp(tint.a * v_a * (body * 0.75 + core * 0.5), 0.0, 1.0);
}
