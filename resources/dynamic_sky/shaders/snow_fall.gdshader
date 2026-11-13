shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Dynamic Sky: snow drawn on REAL falling particles.
// Each flake is one particle of an emitter that has world collision: it falls with the particle's own motion and
// disappears the moment it touches a surface (roofs, ground), so nothing snows indoors or through solid objects.
// The quad sits at the particle position (MODEL_MATRIX origin) and always faces the camera. Each flake also gets a
// small per-flake flutter on top of the real path (visual only, the collision uses the real position).
// Flakes are soft round sprites that stretch into short streaks when the wind is strong (blizzards).

uniform vec3  fall_vel     = vec3(0.0, -1.3, 0.0);    // average flake velocity (m/s), sets the streak direction (Lua)
uniform float spawn_half   = 17.0;                    // half size of the spawn box (m), for the horizontal edge fade
uniform float flutter_t    = 0.0;                     // 0..50.2655 (seamless wrap), driven from Lua
uniform float sway         = 0.45;                    // horizontal flutter amplitude (m)
uniform float density      = 1.0;                     // 0..1 share of the flakes that are drawn
uniform float flake_size   = 0.038;                   // typical flake size up close (m)
uniform vec4  tint : source_color = vec4(0.95, 0.97, 1.0, 0.85);   // flake colour against the sky
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex  : hint_depth_texture, filter_nearest;

varying vec2  v_s;
varying float v_a;

uint pcg(uint v) {
	uint s = v * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	return (w >> 22u) ^ w;
}
float rnd(uint v) {
	return float(pcg(v) & 16777215u) / 16777215.0;
}

void vertex() {
	uint id = uint(INSTANCE_ID);
	float r_keep = rnd(id * 11u + 4u);
	float r_size = rnd(id * 11u + 5u);
	float r_a    = rnd(id * 11u + 6u);
	float r_f1   = rnd(id * 11u + 7u);
	float r_f2   = rnd(id * 11u + 8u);
	float r_p1   = rnd(id * 11u + 9u);
	float r_p2   = rnd(id * 11u + 10u);

	vec3 wp  = MODEL_MATRIX[3].xyz;                   // the particle: world position (emitter is not local)
	float age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);   // 0 at spawn .. 1 at the end of its life

	// flutter: integer multiples of 1/8 rad/s so the wrap of flutter_t is seamless
	float f1 = floor(mix(6.0, 20.0, r_f1)) / 8.0;
	float f2 = floor(mix(6.0, 20.0, r_f2)) / 8.0;
	float p1 = r_p1 * 6.2831853;
	float p2 = r_p2 * 6.2831853;
	float amp = sway * mix(0.35, 1.0, r_a);
	wp += vec3(sin(flutter_t * f1 + p1), 0.35 * sin(flutter_t * f2 * 1.5 + p2), cos(flutter_t * f2 + p2)) * amp;

	vec3 cam  = INV_VIEW_MATRIX[3].xyz;
	float spd = max(length(fall_vel), 0.001);
	vec3 d    = fall_vel / spd;
	vec3 to_p = wp - cam;
	float dist = max(length(to_p), 0.001);
	vec3 vdir = to_p / dist;
	vec3 side = cross(d, vdir);
	float sl  = length(side);
	side = (sl > 0.001) ? side / sl : INV_VIEW_MATRIX[0].xyz;

	float s   = flake_size * mix(0.5, 1.5, r_size) + dist * 0.0012;
	float len = s * (1.0 + clamp(spd * 0.28, 0.0, 6.0));

	vec3 world = wp + d * (VERTEX.y * len) + side * (VERTEX.x * s);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));

	float hq = max(abs(to_p.x), abs(to_p.z)) / spawn_half;
	float edge = 1.0 - smoothstep(0.62, 1.0, hq);
	float life = smoothstep(0.0, 0.04, age) * (1.0 - smoothstep(0.90, 1.0, age));
	float nfade = smoothstep(0.25, 1.4, dist);        // out-of-focus flakes right at the lens fade away
	float keep = step(r_keep, density);
	v_a = edge * life * nfade * keep * mix(0.55, 1.0, r_a);
	v_s = vec2(VERTEX.x, VERTEX.y) * 2.0;

	if (keep < 0.5) {
		POSITION = vec4(0.0, 0.0, -2.0, 1.0);
	}
}

void fragment() {
	float rr = length(v_s);
	float disc = 1.0 - smoothstep(0.30, 1.0, rr);
	// in front of scenery the flake is the colour of what is behind it, a little lighter, so it matches the snow on the
	// ground whatever the light (never darker than the plain tint, so it stays visible on dark walls); against the open
	// sky it keeps the plain tint
	vec3 bg  = texture(screen_tex, SCREEN_UV).rgb;
	float sky = step(texture(depth_tex, SCREEN_UV).r, 0.00001);
	ALBEDO = mix(max(bg * 1.25, tint.rgb * 0.6), tint.rgb, sky);
	ALPHA  = tint.a * v_a * disc;
}
