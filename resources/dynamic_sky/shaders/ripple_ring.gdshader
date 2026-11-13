shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

// Dynamic Sky: one raindrop ripple, spawned where a drop lands (sub-emitter of the splash droplets).
// Drawn only into a 3D rendertarget (particle:set_layer), which snow_cover.gdshader reads:
//   r = height (+)   g = height (-)   b = view depth / depth_scale   a = ring count

uniform float ring_radius = 0.35;     // metres: half size of one ring
uniform float lift = 0.02;            // metres above the landing point
uniform float share = 0.3333;         // each droplet spawns a ring, so each carries a share
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

	// two travelling wave packets, the second behind the first
	float r1 = mix(0.10, 0.86, sqrt(age));
	float r2 = mix(0.05, 0.60, sqrt(clamp(age * 1.25 - 0.1, 0.0, 1.0)));
	float soft = 0.18 + 0.10 * age;                                  // softens while it travels
	float e1 = 1.0 - smoothstep(0.0, soft, abs(r - r1));
	float e2 = (1.0 - smoothstep(0.0, soft * 0.85, abs(r - r2))) * 0.6 * smoothstep(0.05, 0.25, age);
	float h = sin((r - r1) * 17.0) * e1 + sin((r - r2) * 17.0) * e2;

	float fade = pow(1.0 - age, 1.25) * smoothstep(0.0, 0.07, age);
	h *= v_amp * fade * (1.0 - smoothstep(0.88, 1.0, r)) * share;

	float depth = -VERTEX.z / depth_scale;
	ALBEDO = vec3(max(h, 0.0), max(-h, 0.0), depth);
	ALPHA = 1.0;
}
