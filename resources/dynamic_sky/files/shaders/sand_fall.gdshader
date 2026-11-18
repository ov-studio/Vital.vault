// Dynamic Sky: sand_fall.gdshader
// Desc: wind-blown sand grains on real particles

shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;


///////////////
// Uniforms //
///////////////

uniform vec3  fall_vel     = vec3(8.0, -0.5, 0.0);    // average velocity (m/s), sets the streak direction (Lua)
uniform float spawn_half   = 26.0;                    // half size of the area around the camera, for the edge fade (m)
uniform float swirl_t      = 0.0;                     // 0..50.2655 (seamless wrap), from Lua
uniform float swirl        = 1.0;                     // turbulence amplitude (m)
uniform float density      = 1.0;                     // 0..1 share of the grains that are drawn
uniform float grain_size   = 0.010;                   // typical grain size up close (m)
uniform float stretch      = 0.003;                   // extra length per m/s of speed (m)
uniform vec4  tint : source_color = vec4(0.62, 0.46, 0.28, 0.55);


///////////////
// Varyings //
///////////////

varying vec2  v_s;
varying float v_a;


//////////////
// Helpers //
//////////////

uint pcg(uint v) {
	uint s = v * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	return (w >> 22u) ^ w;
}
float rnd(uint v) {
	return float(pcg(v) & 16777215u) / 16777215.0;
}

// ============================================================================
//  Vertex
// ============================================================================

void vertex() {
	uint id = uint(INSTANCE_ID);
	float r_keep = rnd(id * 13u + 4u);
	float r_size = rnd(id * 13u + 5u);
	float r_a    = rnd(id * 13u + 6u);
	float r_f    = rnd(id * 13u + 7u);
	float r_p    = rnd(id * 13u + 8u);

	vec3 wp  = MODEL_MATRIX[3].xyz;                   // particle world position
	float age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);   // 0 at spawn .. 1 at end of life

	// integer multiples of 1/8 rad/s keep the swirl_t wrap seamless
	float f = floor(mix(6.0, 24.0, r_f)) / 8.0;
	float p = r_p * 6.2831853;
	wp += vec3(sin(swirl_t * f + p), 0.5 * sin(swirl_t * f * 2.0 + p), cos(swirl_t * f + p)) * (swirl * mix(0.3, 1.0, r_a));

	vec3 cam  = INV_VIEW_MATRIX[3].xyz;
	vec3 to_p = wp - cam;
	float dist = max(length(to_p), 0.001);

	// wind direction in the screen plane
	vec2 axis = (VIEW_MATRIX * vec4(fall_vel, 0.0)).xy;
	float al = length(axis);
	axis = (al > 0.0001) ? axis / al : vec2(1.0, 0.0);
	vec2 perp = vec2(-axis.y, axis.x);

	float s   = grain_size * mix(0.5, 1.6, r_size) + dist * 0.0005;   // never thinner than ~1 pixel
	float len = s + min(al * stretch, s * 5.0) * mix(0.6, 1.4, r_a);
	vec2 off  = axis * (VERTEX.y * len) + perp * (VERTEX.x * s);

	vec3 world = wp + INV_VIEW_MATRIX[0].xyz * off.x + INV_VIEW_MATRIX[1].xyz * off.y;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));

	float hq = max(abs(to_p.x), abs(to_p.z)) / spawn_half;
	float edge = 1.0 - smoothstep(0.62, 1.0, hq);
	float life = smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.85, 1.0, age));
	float nfade = smoothstep(0.3, 2.5, dist);         // grains right at the lens fade away
	float keep = step(r_keep, density);
	v_a = edge * life * nfade * keep * mix(0.4, 1.0, r_a);
	v_s = vec2(VERTEX.x, VERTEX.y) * 2.0;

	if (keep < 0.5) {
		POSITION = vec4(0.0, 0.0, -2.0, 1.0);
	}
}

// ============================================================================
//  Fragment
// ============================================================================

void fragment() {
	ALBEDO = tint.rgb;
	ALPHA  = tint.a * v_a * (1.0 - smoothstep(0.3, 1.0, length(v_s)));
}
