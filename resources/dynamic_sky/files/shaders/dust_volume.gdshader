shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;

// Dynamic Sky: dust_volume.gdshader
// Desc: sandstorm dust volume over the whole screen

// ============================================================================
//  Uniforms
// ============================================================================

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;   // baked cloud noise, G = billows

// storm (from Lua)
uniform float strength     = 0.0;                     // 0..1 storm level
uniform vec3  wind_dir     = vec3(1.0, 0.0, 0.0);     // direction the dust blows towards, xz is used
uniform vec2  drift_a      = vec2(0.0);               // how far the big billows have blown in the world, xz (m)
uniform vec2  drift_b      = vec2(0.0);               // same for the small billows, they blow faster (m)
uniform float ground_y     = 0.0;                     // world height of the ground under the camera (m)

// shape
uniform float density      = 0.018;                   // extinction per metre at the ground at full strength
uniform float height       = 18.0;                    // dust layer height (m)
uniform float noise_scale  = 0.0022;                  // size of the big billows, uv per metre
uniform float stretch      = 0.6;                     // billows are this much longer along the wind than across (1 = round)
uniform float max_dist     = 220.0;                   // how far into open sky the dust is marched (m)
uniform float sky_veil     = 0.75;                    // extra dust over the open sky, so the sky is dusty in every direction

// light
uniform vec3  albedo         = vec3(0.80, 0.60, 0.36);
uniform vec3  light_color    = vec3(1.0, 0.9, 0.7);   // key light (sun or moon) after the time of day
uniform vec3  ambient_color  = vec3(0.45, 0.50, 0.60);
uniform vec3  light_dir      = vec3(0.0, 1.0, 0.0);   // direction TO the key light

// ============================================================================
//  Helpers
// ============================================================================

const int STEPS = 6;

// Dust extinction at a world position (per metre), and the height of the dust there in .y
vec2 sk_dust(vec3 p, float dist) {
	vec2 w = normalize(wind_dir.xz + vec2(0.0001));
	vec2 perp = vec2(-w.y, w.x);
	vec2 pa = p.xz - drift_a;                                         // the dust field is carried by the wind in the world,
	vec2 pb = p.xz - drift_b;                                         // only its stretch follows the current wind direction
	vec2 qa = vec2(dot(pa, w) * stretch, dot(pa, perp)) * noise_scale;
	vec2 qb = vec2(dot(pb, w) * stretch, dot(pb, perp)) * noise_scale * 3.1;
	float lod = 2.0 + clamp(dist * 0.012, 0.0, 2.0);                  // blurrier far away, never a visible noise pattern
	float a = textureLod(noise_tex, qa + p.y * 0.0031, lod).g;
	float b = a;
	if (dist < 80.0) {                                                // the small billows are lost in the distance, skip the second fetch
		b = textureLod(noise_tex, qb + p.y * 0.007 + vec2(0.0, 0.37), lod + 0.5).g;
	}
	float n = a * 0.65 + b * 0.35;
	float h = max(p.y - ground_y, 0.0);
	float top = height * (0.55 + 0.9 * a);                           // big billows rise higher
	float shape = 0.3 + 0.7 * smoothstep(0.30, 0.80, n);
	return vec2(density * strength * shape * exp(-h / top), clamp(h / top, 0.0, 1.0));
}

vec3 sk_view_ray(vec2 uv, mat4 inv_proj, mat4 inv_view) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, 0.5, 1.0);
	v.xyz /= v.w;
	return normalize((inv_view * vec4(normalize(v.xyz), 0.0)).xyz);
}

// ============================================================================
//  Main
// ============================================================================

void fragment() {
	vec3 d = sk_view_ray(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;

	float depth = texture(depth_tex, SCREEN_UV).r;
	float t_end = max_dist;
	if (depth > 0.00001) {
		vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		t_end = min(length(sv.xyz / sv.w), max_dist);
	}

	// open sky above the dust layer needs no march: stop the ray where the dust has thinned out
	float top_y = ground_y + height * 4.5;
	if (d.y > 0.0005) {
		t_end = min(t_end, max((top_y - cam.y) / d.y, 0.0));
	} else if (cam.y > top_y) {
		t_end = 0.0;
	}

	float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float cos_l = max(dot(d, light_dir), 0.0);
	float phase = 0.85 + 0.6 * pow(cos_l, 4.0);                       // dust glows a little towards the light

	vec3 L = vec3(0.0);
	float T = 1.0;
	for (int i = 0; i < STEPS && t_end >= 0.5; i++) {
		float u = (float(i) + ign) / float(STEPS);
		float t = t_end * pow(u, 1.5);                                 // dense steps near the camera
		float dt = t_end * 1.5 * sqrt(u) / float(STEPS);
		vec2 s = sk_dust(cam + d * t, t);
		float step_t = exp(-s.x * dt);
		vec3 c = albedo * (light_color * phase * mix(0.6, 1.0, s.y) + ambient_color);
		L += T * (1.0 - step_t) * c;
		T *= step_t;
		if (T < 0.03) {
			break;
		}
	}

	// the sky itself sits behind a veil of dust, thicker towards the horizon
	if (depth <= 0.00001) {
		float tau = sky_veil * strength * (0.6 + 0.8 * (1.0 - clamp(d.y, 0.0, 1.0)));
		L += T * (1.0 - exp(-tau)) * albedo * (light_color * 0.95 + ambient_color);
		T *= exp(-tau);
	}

	float a = clamp(1.0 - T, 0.0, 0.97);
	ALBEDO = L / max(1.0 - T, 0.001);
	ALPHA = a;
}
