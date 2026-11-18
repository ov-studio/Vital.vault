// Dynamic Sky: mist_volume.gdshader
// Desc: ground mist volume over the whole screen

shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;


///////////////
// Uniforms //
///////////////

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;   // baked cloud noise, G = billows

// mist (from Lua)
uniform float strength     = 0.0;                     // 0..1 mist level
uniform vec2  drift        = vec2(0.0);               // how far the mist has drifted in the world, xz (m)
uniform float ground_y     = 0.0;                     // world height of the ground under the camera (m)

// shape
uniform float density      = 0.006;                   // extinction per metre at the ground at full strength
uniform float height       = 30.0;                    // mist layer height (m)
uniform float noise_scale  = 0.0016;                  // size of the mist patches, uv per metre
uniform float max_dist     = 600.0;                   // how far the mist is marched (m)

// light
uniform vec3  albedo         = vec3(0.86, 0.90, 0.96);
uniform vec3  light_color    = vec3(1.0, 0.9, 0.7);   // key light (sun or moon) after the time of day
uniform vec3  ambient_color  = vec3(0.45, 0.50, 0.60);
uniform vec3  light_dir      = vec3(0.0, 1.0, 0.0);   // direction TO the key light


//////////////
// Helpers //
//////////////

#include "files/shaders/helper.gdshader"

const int STEPS = 8;

// Mist extinction at a world position (per metre), and the height of the mist there in .y
vec2 sk_mist(vec3 p, float dist) {
	float lod = 2.0 + clamp(dist * 0.006, 0.0, 3.0);                  // blurrier far away, never a visible noise pattern
	float n = textureLod(noise_tex, (p.xz - drift) * noise_scale + p.y * 0.002, lod).g;
	float h = max(p.y - ground_y, 0.0);
	float top = height * (0.7 + 0.6 * n);                             // patches rise to different heights
	float shape = 0.55 + 0.45 * smoothstep(0.30, 0.75, n);            // mostly even, a little patchy
	return vec2(density * strength * shape * exp(-h / top), clamp(h / top, 0.0, 1.0));
}


///////////////
// Handlers //
///////////////

void fragment() {
	vec3 d = sk_view_ray(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;

	float depth = texture(depth_tex, SCREEN_UV).r;
	float t_end = max_dist;
	if (depth > 0.00001) {
		vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		t_end = min(length(sv.xyz / sv.w), max_dist);
	}

	// above the mist layer there is nothing to march: stop the ray where the mist has thinned out
	float top_y = ground_y + height * 4.0;
	if (d.y > 0.0005) {
		t_end = min(t_end, max((top_y - cam.y) / d.y, 0.0));
	} else if (cam.y > top_y) {
		t_end = 0.0;
	}

	float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float cos_l = max(dot(d, light_dir), 0.0);
	float phase = 0.8 + 0.9 * pow(cos_l, 6.0);                        // mist glows towards a low sun

	vec3 L = vec3(0.0);
	float T = 1.0;
	for (int i = 0; i < STEPS && t_end >= 0.5; i++) {
		float u = (float(i) + ign) / float(STEPS);
		float t = t_end * pow(u, 1.5);                                 // dense steps near the camera
		float dt = t_end * 1.5 * sqrt(u) / float(STEPS);
		vec2 s = sk_mist(cam + d * t, t);
		float step_t = exp(-s.x * dt);
		vec3 c = albedo * (light_color * phase * mix(0.55, 1.0, s.y) + ambient_color);
		L += T * (1.0 - step_t) * c;
		T *= step_t;
		if (T < 0.03) {
			break;
		}
	}

	float a = clamp(1.0 - T, 0.0, 0.96);
	ALBEDO = L / max(1.0 - T, 0.001);
	ALPHA = a;
}
