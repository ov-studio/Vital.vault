shader_type canvas_item;
render_mode blend_disabled;

// skycycle: one direction of a separable gaussian blur for the small cloud rendertarget (call it twice: horizontal,
// then vertical). Clouds are soft, so this hides the dither noise of the cloud pass and the low resolution.
// NOTE: never write the text of the entry point signatures inside comments (the engine injects code there).

uniform sampler2D src : filter_linear, repeat_disable;
uniform vec2  step_uv = vec2(0.0, 0.0);           // one texel along the blur direction, in uv units (Lua)

void fragment() {
	// 5 taps with the linear sampling trick = a 9 tap gaussian
	vec4 c = texture(src, UV) * 0.2270270270;
	c += texture(src, UV + step_uv * 1.3846153846) * 0.3162162162;
	c += texture(src, UV - step_uv * 1.3846153846) * 0.3162162162;
	c += texture(src, UV + step_uv * 3.2307692308) * 0.0702702703;
	c += texture(src, UV - step_uv * 3.2307692308) * 0.0702702703;
	COLOR = vec4(max(c.rgb, vec3(0.0)), clamp(c.a, 0.0, 1.0));
}
