// Dynamic Sky: heat_haze.gdshader
// Desc: shimmer of the hot air over distant ground

shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;


//////////////
// Imports //
//////////////

#include "files/shaders/helper.gdshader"


///////////////
// Uniforms //
///////////////

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

// heat (from Lua)
uniform float strength     = 0.0;      // 0..1 heat level
uniform float start_dist   = 80.0;     // the shimmer starts this far from the camera (m)
uniform float amplitude    = 0.0012;   // strongest distortion (screen uv)
uniform float scale        = 40.0;     // ripples across the screen height


///////////////
// Handlers //
///////////////

void fragment() {
	vec2 uv = SCREEN_UV;
	float depth = texture(depth_tex, uv).r;
	vec3 d = sk_view_ray(uv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);

	// far ground near the horizon: the hot air lies low and shows at a grazing angle. The sky is not distorted,
	// it is drawn on top of the screen, so only geometry pixels are touched
	float mask = 0.0;
	if (depth > 0.00001) {
		vec4 sv = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, depth, 1.0);
		float dist = length(sv.xyz / sv.w);
		mask = smoothstep(start_dist, start_dist * 5.0, dist) * (1.0 - smoothstep(0.01, 0.12, abs(d.y))) * strength;
	}
	if (mask < 0.002) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	} else {
		float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
		vec2 p = uv * vec2(aspect, 1.0) * scale;
		float w1 = sk_vn(p * vec2(1.0, 2.2) + vec2(0.0, -TIME * 0.6)) - 0.5;
		float w2 = sk_vn(p * vec2(2.3, 4.1) + vec2(17.0, -TIME * 1.0)) - 0.5;
		float w = w1 + 0.5 * w2;
		vec2 off = vec2(w, abs(w) * 0.2) * amplitude * mask;
		if (texture(depth_tex, uv + off).r <= 0.00001) {
			off = vec2(0.0);                                           // never pull the sky behind the horizon into the ground
		}
		ALBEDO = texture(screen_tex, uv + off).rgb;
		ALPHA = clamp(mask * 20.0, 0.0, 1.0);
	}
}
