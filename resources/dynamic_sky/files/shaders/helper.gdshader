// Dynamic Sky: helper.gdshader
// Desc: helpers shared by the other shaders


//////////////
// Helpers //
//////////////

// pcg hash of an integer and its random float in 0..1
uint sk_pcg(uint v) {
	uint s = v * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	return (w >> 22u) ^ w;
}

float sk_rnd(uint v) {
	return float(sk_pcg(v) & 16777215u) / 16777215.0;
}

// hash without sin(), which loses precision with large arguments on the GPU
float sk_h21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// value noise
float sk_vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(sk_h21(i), sk_h21(i + vec2(1.0, 0.0)), f.x), mix(sk_h21(i + vec2(0.0, 1.0)), sk_h21(i + vec2(1.0)), f.x), f.y);
}

// world space view direction of a screen position
vec3 sk_view_ray(vec2 uv, mat4 inv_proj, mat4 inv_view) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, 0.5, 1.0);
	v.xyz /= v.w;
	return normalize((inv_view * vec4(normalize(v.xyz), 0.0)).xyz);
}
