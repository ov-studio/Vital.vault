shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Dynamic Sky: rain streaks on real falling particles. A particle disappears on contact with the world, where the
// engine spawns the splash. The quad sits at the particle position, stretched along the fall direction and turned
// to face the camera around that axis.

uniform vec3  fall_vel     = vec3(0.0, -13.0, 0.0);   // average velocity (m/s), sets the streak direction (Lua)
uniform float spawn_half   = 17.0;                    // half size of the spawn box (m), for the edge fade
uniform float density      = 1.0;                     // 0..1 share of the streaks that are drawn
uniform float streak_len   = 0.85;                    // streak length at 13 m/s (m)
uniform float streak_w     = 0.010;                   // streak width up close (m)
uniform vec4  tint : source_color = vec4(0.72, 0.78, 0.88, 0.45);
uniform float refract_str  = 0.010;                   // screen-space distortion through the streaks (0 = off)
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex  : hint_depth_texture, filter_nearest;

varying vec2  v_s;     // x: across -1..1, y: along 0 (tail) .. 1 (head)
varying float v_a;     // per-streak alpha
varying vec2  v_side;  // streak width axis in view space, for the refraction offset

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
	float r_keep = rnd(id * 7u + 4u);
	float r_len  = rnd(id * 7u + 5u);
	float r_alp  = rnd(id * 7u + 6u);

	vec3 wp  = MODEL_MATRIX[3].xyz;                   // particle world position
	float age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);   // 0 at spawn .. 1 at end of life

	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float spd  = max(length(fall_vel), 0.001);
	vec3 d     = fall_vel / spd;
	vec3 to_p  = wp - cam;
	float dist = max(length(to_p), 0.001);
	vec3 vdir  = to_p / dist;
	vec3 side  = cross(d, vdir);
	float sl   = length(side);
	side = (sl > 0.001) ? side / sl : INV_VIEW_MATRIX[0].xyz;

	float len = streak_len * mix(0.65, 1.35, r_len) * clamp(spd / 13.0, 0.4, 3.0);
	float w   = streak_w + dist * 0.0011;             // never thinner than ~1 pixel

	// the particle position is the leading tip
	vec3 world = wp - d * (0.5 - VERTEX.y) * len + side * (VERTEX.x * w);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));

	float hq = max(abs(to_p.x), abs(to_p.z)) / spawn_half;          // horizontal distance in spawn-box units
	float edge = 1.0 - smoothstep(0.62, 1.0, hq);
	float life = smoothstep(0.0, 0.04, age) * (1.0 - smoothstep(0.80, 1.0, age));
	float nfade = smoothstep(0.6, 2.2, dist);
	float keep = step(r_keep, density);
	v_a = edge * life * nfade * keep * mix(0.45, 1.0, r_alp);
	v_s = vec2(VERTEX.x * 2.0, VERTEX.y + 0.5);
	v_side = (VIEW_MATRIX * vec4(side, 0.0)).xy * (1.0 / (1.0 + dist * 0.12));

	if (keep < 0.5) {
		POSITION = vec4(0.0, 0.0, -2.0, 1.0);          // outside the clip volume
	}
}

void fragment() {
	float across = 1.0 - smoothstep(0.15, 1.0, abs(v_s.x));
	float along  = smoothstep(0.0, 0.85, v_s.y) * (1.0 - 0.45 * smoothstep(0.92, 1.0, v_s.y));
	float shape  = across * along * v_a;
	vec2 off = v_side * v_s.x * refract_str * (1.0 - 0.5 * abs(v_s.x));
	vec3 bg  = texture(screen_tex, clamp(SCREEN_UV + off, vec2(0.001), vec2(0.999))).rgb;
	float k  = clamp(tint.a / 0.6, 0.0, 1.0);
	float sky = step(texture(depth_tex, SCREEN_UV).r, 0.00001);
	vec3 lit = bg * 1.35 + 0.008 + bg * tint.rgb * 0.12;
	vec3 sky_lit = tint.rgb * 0.9;
	ALBEDO = mix(mix(bg, lit, k), sky_lit, sky);
	ALPHA  = 0.6 * shape * mix(1.0, clamp(k * 2.2, 0.0, 1.0), sky);
}
