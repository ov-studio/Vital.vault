shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

// Dynamic Sky: one raindrop ripple, spawned by the engine exactly where a drop lands (sub-emitter of the splash droplets).
// The emitter is drawn only into a 3D rendertarget (particle:set_layer), never into the main view. The rendertarget
// is a screen-space ripple buffer that snow_cover.gdshader reads at every puddle pixel:
//   r = height, positive part      g = height, negative part       (added up, so they cannot be negative)
//   b = view depth of the ring / depth_scale                       a = number of rings covering the pixel
// depth / count tells the puddle which surface the ring belongs to (a roof, not the floor below it).

uniform float ring_radius = 0.35;     // metres: half size of one ring
uniform float lift = 0.02;            // metres above the landing point (the drop is detected a hair below the surface)
uniform float share = 0.3333;         // the landing spawns several droplets and each one spawns a ring: every ring carries its share
uniform float depth_scale = 64.0;     // metres the depth channel covers

varying vec2  v_p;
varying float v_age;
varying float v_amp;

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz + vec3(0.0, lift, 0.0);
	v_age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	v_amp = 0.7 + 0.4 * fract(sin(dot(c.xz, vec2(12.9898, 78.233))) * 43758.5453);
	v_p = VERTEX.xy * 2.0;
	vec3 world = c + vec3(VERTEX.x, 0.0, -VERTEX.y) * (ring_radius * 2.0);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
	float r = length(v_p);
	if (r > 1.0) discard;
	float age = v_age;

	// two travelling wave packets (a light and a dark thin band each), the second one behind the first
	float r1 = mix(0.10, 0.86, sqrt(age));
	float r2 = mix(0.05, 0.60, sqrt(clamp(age * 1.25 - 0.1, 0.0, 1.0)));
	float soft = 0.18 + 0.10 * age;                                  // widens and softens while it travels
	float e1 = 1.0 - smoothstep(0.0, soft, abs(r - r1));
	float e2 = (1.0 - smoothstep(0.0, soft * 0.85, abs(r - r2))) * 0.6 * smoothstep(0.05, 0.25, age);
	float h = sin((r - r1) * 17.0) * e1 + sin((r - r2) * 17.0) * e2;

	// quick fade-in, long gentle fade-out
	float fade = pow(1.0 - age, 1.25) * smoothstep(0.0, 0.07, age);
	h *= v_amp * fade * (1.0 - smoothstep(0.88, 1.0, r)) * share;

	float depth = -VERTEX.z / depth_scale;                           // view space position of this very pixel of the ring
	ALBEDO = vec3(max(h, 0.0), max(-h, 0.0), depth);
	ALPHA = 1.0;
}
