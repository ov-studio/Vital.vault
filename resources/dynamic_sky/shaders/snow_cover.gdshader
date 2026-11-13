shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Dynamic Sky: weather surface layer, applied to every model as a layered material
// (shader:apply_to_material("*", "*", "*", 0, true)) on top of the surface's own material.
// snow_amount and wet are 0..1 and animated from Lua.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;   // only used for the alpha cut-out
uniform vec4  albedo_color : source_color = vec4(1.0);
uniform vec3  uv1_scale  = vec3(1.0, 1.0, 1.0);
uniform vec3  uv1_offset = vec3(0.0, 0.0, 0.0);

uniform float alpha_cut = 0.5;                     // texels below this alpha are discarded; 0 = never
uniform float snow_amount = 0.0;                   // 0..1
uniform vec3  snow_color : source_color = vec3(0.86, 0.90, 0.96);
uniform float wet = 0.0;                           // 0..1
uniform float rain_amt = 0.0;                      // current rain, drives the fallback ripples
uniform float puddle_gloss = 0.30;                 // higher = blurrier puddles
uniform float puddle_strength = 0.55;              // max puddle opacity
uniform float ripple_gain = 0.16;                  // bump strength
uniform vec3  ripple_light : source_color = vec3(0.05);   // set from Lua
uniform sampler2D screen_rip : filter_linear, repeat_disable;   // ripple buffer, see ripple_ring.gdshader
uniform float screen_rip_on = 0.0;                 // 1 = ripples from the buffer, 0 = procedural fallback
uniform float screen_rip_gamma = 1.0;              // 2.2 if the buffer is sRGB encoded
uniform float screen_rip_depth = 64.0;             // must match ripple_ring.gdshader
uniform float ripple_scale = 1.7;                  // fallback ripple cells per metre
uniform float wet_fade_start = 22.0;               // metres: wetness starts to thin out
uniform float wet_fade_end   = 75.0;               // metres: completely gone

varying vec3 w_pos;
varying vec3 w_nrm;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
// ripple height at a screen position, counted only where the ring depth matches the surface
float screen_h(vec2 uv, float depth) {
	vec4 t = textureLod(screen_rip, uv, 0.0);
	if (t.a < 0.5) return 0.0;
	vec3 v = pow(max(t.rgb, vec3(0.0)), vec3(screen_rip_gamma));
	float d = v.b * screen_rip_depth / t.a;
	return (v.r - v.g) * (1.0 - smoothstep(0.15, 0.30, abs(d - depth)));
}
vec2 screen_uv_of(vec3 world, mat4 view, mat4 proj) {          // built-ins are passed in, functions cannot read them
	vec4 c = proj * (view * vec4(world, 1.0));
	return c.xy / c.w * 0.5 + 0.5;
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 uv = UV * uv1_scale.xy + uv1_offset.xy;
	vec4 tex = texture(albedo_texture, uv) * albedo_color;
	if (tex.a < alpha_cut) {
		discard;
	}

	float ny = clamp(w_nrm.y, -1.0, 1.0);
	// world-space noise projected along the dominant axis
	vec3 an = abs(w_nrm);
	vec2 np = (an.y >= an.x && an.y >= an.z) ? w_pos.xz : ((an.x > an.z) ? w_pos.zy : w_pos.xy);
	float nl = vnoise(np * 0.22);
	float nm = vnoise(np * 0.85 + 11.3);
	float n  = nl * 0.65 + nm * 0.35;

	// ---- snow ----
	float sa = clamp(snow_amount, 0.0, 1.0);
	float thr = mix(1.02, -0.05, pow(sa, 0.75));                     // steeper surfaces get covered as it grows
	float m_raw = smoothstep(thr, thr + 0.45, ny + (n - 0.5) * 0.40 + sa * 0.10);
	float snow = smoothstep(0.10, 0.90, m_raw);
	snow *= smoothstep(0.0, 0.02, sa);

	// ---- rain ----
	// wetness fades with distance, ripples earlier (they alias when far away)
	float cd = length(VERTEX);
	float wfade = 1.0 - smoothstep(wet_fade_start, max(wet_fade_end, wet_fade_start + 1.0), cd);
	float rfade = 1.0 - smoothstep(wet_fade_start * 0.45, wet_fade_end * 0.40, cd);
	float wt = clamp(wet, 0.0, 1.0) * wfade;
	float flat_w = smoothstep(0.80, 0.96, ny);
	float pud = smoothstep(0.50, 0.72, nl * 0.7 + nm * 0.3) * flat_w * smoothstep(0.40, 0.95, wt);
	pud *= (1.0 - snow);
	float sheen = wt * (1.0 - snow) * (1.0 - pud);

	// snow normal and puddle ripples
	vec2 bump = vec2(nm - 0.5, vnoise(np * 0.85 + 40.0) - 0.5) * 0.16;
	vec2 nxy = bump * snow;
	vec2 rgrad = vec2(0.0);                                          // ripple slope (world xz)
	if (screen_rip_on > 0.5) {
		if (pud > 0.05 && rfade > 0.01) {
			vec3 vp = (VIEW_MATRIX * vec4(w_pos, 1.0)).xyz;
			float depth = -vp.z;
			float px = 2.0 / (PROJECTION_MATRIX[1][1] * float(textureSize(screen_rip, 0).y));   // metres per buffer pixel at depth 1
			float e = max(0.0176, depth * px * 1.2);             // never finer than the buffer resolves
			vec2 uc = screen_uv_of(w_pos, VIEW_MATRIX, PROJECTION_MATRIX);
			vec2 dx = screen_uv_of(w_pos + vec3(e, 0.0, 0.0), VIEW_MATRIX, PROJECTION_MATRIX) - uc;
			vec2 dz = screen_uv_of(w_pos + vec3(0.0, 0.0, e), VIEW_MATRIX, PROJECTION_MATRIX) - uc;
			vec2 u0 = SCREEN_UV;
			float hx = screen_h(u0 + dx, depth) - screen_h(u0 - dx, depth);
			float hz = screen_h(u0 + dz, depth) - screen_h(u0 - dz, depth);
			rgrad = -vec2(hx, hz) * ripple_gain * (0.0176 / e) * pud * rfade;
			nxy += rgrad;
		}
	} else if (rain_amt > 0.05 && pud > 0.05 && rfade > 0.01) {
		// no ripple buffer: looping ripples on a world-space grid
		vec2 g = w_pos.xz * ripple_scale;
		vec2 cell = floor(g);
		vec2 jit = (vec2(hash12(cell + 7.1), hash12(cell + 19.7)) - 0.5) * 0.24;
		vec2 lf = fract(g) - 0.5 - jit;
		float ph = fract(TIME * 0.7 + hash12(cell));
		float rr = max(length(lf), 0.001);
		float ring = sin((rr - ph * 0.45) * 45.0) * (1.0 - ph) * (1.0 - smoothstep(0.0, 0.14, abs(rr - ph * 0.45)));
		rgrad = (lf / rr) * ring * 0.22 * pud * rain_amt * rfade;
		nxy += rgrad;
	}

	// priority: snow, puddle, wet film
	float a_snow = snow;
	float a_pud  = pud * clamp(puddle_strength, 0.0, 1.0);
	float a_film = sheen * 0.30;
	float a = max(a_snow, max(a_pud, a_film));

	vec3 col_w = vec3(0.012, 0.014, 0.018);                          // dark water, the reflection supplies the colour
	vec3 col = (a_snow >= max(a_pud, a_film)) ? snow_color * (0.97 + 0.03 * nm) : col_w;

	float rgh = (a_snow >= max(a_pud, a_film)) ? 0.65 : mix(0.50, clamp(puddle_gloss, 0.05, 1.0), step(a_film, a_pud));
	float spec = (a_snow >= max(a_pud, a_film)) ? 0.5 : mix(0.30, 0.38, step(a_film, a_pud));

	// ripples stay visible without sun/moon: facets tilted towards the camera mirror the sky
	float rs = length(rgrad);
	vec3 wv = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);   // towards the camera
	float graze = 1.0 - clamp(wv.y, 0.0, 1.0);
	float side = dot(rgrad, normalize(wv.xz + vec2(0.0001))) * 14.0;   // + : tilted towards camera
	float tilt = 1.0 - exp(-rs * 5.0);
	float catch_l = tilt * (0.30 + 0.70 * clamp(0.5 + side, 0.0, 1.0)) * (0.35 + 0.65 * graze * graze);
	a = max(a, tilt * pud * 0.55);

	ALBEDO = col;
	EMISSION = ripple_light * catch_l * 0.55 * step(a_snow, max(a_pud, a_film) + 0.0001);
	ALPHA = clamp(a, 0.0, 1.0);
	ROUGHNESS = rgh;
	METALLIC = 0.0;
	SPECULAR = spec;
	NORMAL_MAP = vec3(0.5 + nxy.x, 0.5 + nxy.y, 1.0);
}
