shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;

// Dynamic Sky: screen-space sky on a camera-following quad, painted only where the depth buffer is sky.
// Gradient from timecycle colours (Lua), sun, moon with phase, stars, and clouds read from cloud_pass.gdshader.
// NOTE: keep the shader_type line first and never write the text of the entry point signatures inside comments.

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D moon_tex : filter_linear_mipmap, repeat_disable;  // equirectangular colour map
uniform sampler2D cloud_tex : filter_linear, repeat_disable;           // from cloud_pass.gdshader (Lua)

// ---- celestial bodies -------------------------------------------------------
uniform vec3  sun_dir          = vec3(0.0, 1.0, 0.0);   // direction TO the sun
uniform vec3  moon_dir         = vec3(0.0, -1.0, 0.0);  // direction TO the moon
uniform float sun_size         = 0.0085;                // angular radius (rad)
uniform float moon_size        = 0.0150;                // angular radius (rad)
uniform vec3  star_axis        = vec3(0.0, 0.0, 1.0);   // celestial rotation axis
uniform float star_angle       = 0.0;                   // celestial rotation (rad)

// ---- timecycle colours (linear) ---------------------------------------------
uniform vec3  zenith_color     = vec3(0.10, 0.26, 0.60);
uniform vec3  horizon_color    = vec3(0.55, 0.70, 0.88);
uniform vec3  ground_color     = vec3(0.30, 0.34, 0.38);
uniform vec3  glow_color       = vec3(1.00, 0.72, 0.40); // sun glow / sunset tint
uniform vec3  sun_color        = vec3(1.00, 0.95, 0.85);   // timecycle tint
uniform vec3  sun_phys         = vec3(1.00, 0.93, 0.80);   // sunlight colour after the atmosphere (Lua)
uniform vec3  moon_color       = vec3(0.75, 0.82, 1.00);
uniform float horizon_falloff  = 3.5;     // higher = thinner horizon band
uniform float glow_strength    = 0.35;
uniform float sun_intensity    = 25.0;    // 25 = full strength (weather dims it)
uniform float sun_hdr          = 6.0;     // disc HDR brightness (bloom above the engine glow threshold)
uniform float moon_intensity   = 1.5;
uniform float star_visibility  = 0.0;     // 0 = day, 1 = full night sky
uniform float exposure         = 1.0;

// ---- lighting for clouds (blended sun/moon "key light") ---------------------

// ---- clouds -----------------------------------------------------------------
uniform float cloud_coverage   = 0.40;    // 0..1
uniform vec3  ray_color        = vec3(1.0, 0.86, 0.62);  // god rays: sunlight colour
uniform float ray_strength     = 0.0;     // 0 = off (driven from Lua)
uniform float ray_length       = 0.95;    // share of the way to the sun that is marched
uniform float ray_decay        = 0.97;
uniform float ray_spread       = 1.1;     // falloff with distance from the sun

// ============================================================================
//  helpers
// ============================================================================


float sk_hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 sk_hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

vec3 sk_rotate(vec3 v, vec3 axis, float ang) {
	float c = cos(ang);
	float s = sin(ang);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

// ============================================================================
//  stars
// ============================================================================

vec3 sk_star_layer(vec3 d, float fw, float tm, float scale, float density, float seed, float size_boost) {
	vec3 p = d * scale;
	vec3 id = floor(p);
	vec3 f = fract(p);
	float gate = sk_hash13(id + seed + 17.7);
	if (gate > density) {
		return vec3(0.0);
	}
	vec3 h = sk_hash33(id + seed);
	vec3 pos = 0.3 + 0.4 * h;
	float mag = pow(sk_hash13(id * 1.7 + seed + 3.3), 5.0);   // few bright, many dim
	float px = fw * scale;
	float r = min(px * (0.9 + size_boost * mag), 0.28);
	float dist = length(f - pos);
	float k = clamp(1.0 - dist / max(r, 0.0001), 0.0, 1.0);
	k = k * k;
	// scintillation: dim stars flicker the most
	float ph = h.y * 60.0;
	float a1 = sin(tm * (2.1 + 4.0 * h.x) + ph);
	float a2 = sin(tm * (5.3 + 7.0 * h.z) + ph * 1.7);
	float a3 = sin(tm * (11.0 + 9.0 * h.y) + ph * 0.6);
	float amp = mix(0.55, 0.22, clamp(mag * 3.0, 0.0, 1.0));
	float tw = clamp(0.72 + amp * (0.50 * a1 + 0.35 * a2 + 0.15 * a3) * 1.6, 0.05, 1.5);
	vec3 tint = mix(vec3(1.0, 0.74, 0.52), vec3(0.62, 0.78, 1.0), h.z);
	tint = mix(vec3(1.0), tint, 0.65);
	// colour shimmer
	tint = mix(tint, tint.bgr, 0.18 * (0.5 + 0.5 * a2));
	return tint * (k * (0.35 + 1.9 * mag)) * tw;
}

vec3 sk_stars(vec3 d, float fw, float tm) {
	vec3 dc = sk_rotate(d, star_axis, -star_angle);
	vec3 s = vec3(0.0);
	s += sk_star_layer(dc, fw, tm, 120.0, 0.16, 1.0, 0.8);
	s += sk_star_layer(dc, fw, tm, 52.0, 0.10, 7.0, 1.6);
	s += sk_star_layer(dc, fw, tm, 22.0, 0.06, 13.0, 2.4);
	return s;
}

// ============================================================================
//  moon
// ============================================================================

// returns rgb in .rgb and coverage in .a
vec4 sk_moon(vec3 d, float fw) {
	float cs = dot(d, moon_dir);
	float cr = cos(moon_size);
	vec3 colr = vec3(0.0);
	float alpha = 0.0;
	if (cs > cr) {
		// the moon keeps its celestial-north-up orientation, like the real one
		vec3 north = -star_axis;
		vec3 b = normalize(north - moon_dir * dot(north, moon_dir));
		vec3 t = cross(b, moon_dir);
		float sm = sin(moon_size);
		vec2 q = vec2(dot(d, t), dot(d, b)) / sm;
		float rr = dot(q, q);
		if (rr < 1.0) {
			float lz = sqrt(1.0 - rr);
			vec3 n = normalize(q.x * t + q.y * b - lz * moon_dir);     // surface normal, facing the viewer
			// sphere coords -> equirectangular uv
			float lon = atan(q.x, lz);
			float lat = asin(clamp(q.y, -1.0, 1.0));
			vec2 uv = vec2(0.5 + lon / 6.2831853, 0.5 - lat / 3.1415927);
			float pix_d = 2.0 * sm / max(fw, 1e-6);
			float lod = max(log2(1024.0 / pix_d), 0.0);
			vec3 tx = pow(textureLod(moon_tex, uv, lod).rgb, vec3(2.2));
			float l = dot(tx, vec3(0.2126, 0.7152, 0.0722));
			vec3 surf = mix(vec3(l), tx, 0.55) * 2.6;
			// Lommel-Seeliger style: flat-lit at full phase
			float mu0 = dot(n, sun_dir);
			float mu = max(lz, 0.02);
			float ls = max(mu0, 0.0) / (max(mu0, 0.0) + mu) * 2.0 * smoothstep(0.0, 0.07, mu0);
			vec3 earthshine = vec3(0.50, 0.60, 0.95) * 0.022;
			colr = moon_color * moon_intensity * surf * (ls + earthshine);
			alpha = clamp((1.0 - sqrt(rr)) * sm / max(fw, 1e-6) + 0.5, 0.0, 1.0);
		}
	}
	return vec4(colr, alpha);
}

// ============================================================================
//  gradient sky + sun
// ============================================================================

// apparent sun size, larger near the horizon
float sk_sun_size_eff() {
	float hf = 1.0 - smoothstep(0.0, 0.22, sun_dir.y);
	return sun_size * (1.0 + 0.28 * hf);
}

vec3 sk_sky(vec3 d) {
	float up = d.y;
	float h = clamp(up, 0.0, 1.0);
	float t = pow(1.0 - h, horizon_falloff);
	vec3 col = mix(zenith_color, horizon_color, t);
	col = mix(col, ground_color, 1.0 - smoothstep(-0.22, 0.0, up));

	float cs = max(dot(d, sun_dir), 0.0);
	float band = 0.30 + 0.70 * exp(-abs(up) * 5.0);
	// sun glow: wide haze + a corona that follows sun_size
	float sse = sk_sun_size_eff();
	float rs = max(acos(cs) / sse, 1.0);
	float corona = 0.50 * exp(-(rs - 1.0) * 0.30) + 0.28 * exp(-(rs - 1.0) * 0.065);
	float glow = 0.30 * pow(cs, 4.0) + 0.55 * pow(cs, 24.0) + 0.80 * corona;
	// colour: pale core, saturating outward into the glow colour
	vec3 hot = mix(sun_phys, vec3(1.0), 0.18);
	vec3 gtint = glow_color / max(max(glow_color.r, glow_color.g), max(glow_color.b, 1e-3));
	vec3 aur = mix(hot, gtint, clamp((rs - 1.0) * 0.16, 0.0, 1.0));
	col += aur * glow_strength * glow * band;
	// glare around the disc
	float vis = smoothstep(-0.02, 0.05, sun_dir.y) * (sun_intensity / 25.0);
	col += hot * (0.26 * exp(-(rs - 1.0) * 1.3) + 0.06 * exp(-(rs - 1.0) * 0.22)) * vis;

	// moon halo
	float cm = max(dot(d, moon_dir), 0.0);
	float lit_frac = clamp(0.5 - 0.5 * dot(moon_dir, sun_dir), 0.0, 1.0);
	float rm = max(acos(cm) / moon_size, 1.0);
	col += moon_color * moon_intensity * (0.2 + lit_frac) * (0.03 * pow(cm, 40.0) + 0.04 * exp(-(rm - 1.0) * 0.35));
	return col;
}

vec4 sk_sun_disc(vec3 d, float fw, float tm) {
	float sse = sk_sun_size_eff();
	float hf = 1.0 - smoothstep(0.0, 0.22, sun_dir.y);
	vec3 st = normalize(cross(abs(sun_dir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0), sun_dir));
	vec3 sb = cross(sun_dir, st);
	vec2 sn = vec2(dot(d, st), dot(d, sb)) / sse;
	sn.y *= 1.0 + 0.10 * hf;                       // refraction flattens a low sun
	float r = length(sn);
	float aa = max(fw / sse, 0.02);
	float disk = (dot(d, sun_dir) > 0.0) ? clamp((1.0 - r) / aa + 0.5, 0.0, 1.0) : 0.0;
	float horizon_cut = smoothstep(-0.004, 0.010, d.y);
	vec3 col = vec3(0.0);
	if (disk > 0.0) {
		// flat colour disc, tinted by the atmosphere
		vec3 tint = sun_phys * mix(vec3(1.0), sun_color / max(max(sun_color.r, sun_color.g), max(sun_color.b, 1e-3)), 0.15);
		tint = mix(tint, vec3(1.0, 0.97, 0.84), 0.62);
		col = tint * clamp(sun_intensity / 25.0, 0.0, 1.0) * sun_hdr;
	}
	return vec4(col, disk * horizon_cut);
}

// ============================================================================
//  main
// ============================================================================

vec3 sk_view_ray(vec2 uv, mat4 inv_proj, mat4 inv_view) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, 0.5, 1.0);
	v.xyz /= v.w;
	return normalize((inv_view * vec4(normalize(v.xyz), 0.0)).xyz);
}

// ---- god rays: geometry pixels look toward the sun on screen and count the open sky they see ----
float sk_rays(vec2 uv, vec2 frag, vec3 sd, mat4 vmat, mat4 pmat) {
	float aspect = pmat[1][1] / pmat[0][0];
	vec4 c = pmat * (vmat * vec4(sd, 0.0));
	if (c.w <= 0.0001) {
		return 0.0;
	}
	vec2 su = c.xy / c.w * 0.5 + 0.5;
	float edge = max(abs(su.x - 0.5), abs(su.y - 0.5)) * 2.0;
	float vis = 1.0 - smoothstep(1.0, 2.0, edge);
	if (vis <= 0.001) {
		return 0.0;
	}
	float ign = fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
	vec2 d = (su - uv) * ray_length;
	float dist = length(vec2((su.x - uv.x) * aspect, su.y - uv.y));
	float acc = 0.0;
	float wsum = 0.0;
	float w = 1.0;
	for (int i = 0; i < 24; i++) {
		float t = (float(i) + ign) / 24.0;
		vec2 p = uv + d * t;
		float open = 0.6;
		if (p.x > 0.0 && p.x < 1.0 && p.y > 0.0 && p.y < 1.0) {
			open = step(texture(depth_tex, p).r, 0.00001);
		}
		float pd = length(vec2((su.x - p.x) * aspect, su.y - p.y));
		acc += open * exp(-pd * ray_spread) * w;
		wsum += w;
		w *= ray_decay;
	}
	acc = acc / max(wsum, 0.0001);
	float ray = acc * exp(-dist * 0.6) * vis;
	return clamp((ray - 0.06) * 1.7, 0.0, 1.0);   // offset drops the faint veil over distant surfaces
}

void fragment() {
	// derivatives are taken before any divergent branch
	vec3 d = sk_view_ray(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float fw = length(fwidth(d));

	float depth = texture(depth_tex, SCREEN_UV).r;
	if (depth > 0.00001) {
		float rr = 0.0;
		if (ray_strength > 0.001) {
			rr = sk_rays(SCREEN_UV, FRAGCOORD.xy, normalize(sun_dir), VIEW_MATRIX, PROJECTION_MATRIX);
		}
		ALBEDO = ray_color;
		ALPHA = clamp(rr * ray_strength, 0.0, 0.9);
	} else {
		float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));

		vec3 col = sk_sky(d);

		// night sky: stars, moon (hidden by horizon)
		float above = smoothstep(-0.02, 0.18, d.y);
		if (star_visibility > 0.005 && d.y > -0.05) {
			float moon_wash = 1.0 - clamp(pow(max(dot(d, moon_dir), 0.0), 60.0) * 2.0, 0.0, 1.0);
			col += sk_stars(d, fw, TIME) * star_visibility * above * moon_wash;
		}
		vec4 moon = sk_moon(d, fw);
		col = mix(col, moon.rgb, moon.a * smoothstep(-0.01, 0.03, d.y));
		vec4 sun = sk_sun_disc(d, fw, TIME);
		col = mix(col, sun.rgb, sun.a);          // the disc replaces the glow behind it

		// clouds
		if (d.y > 0.012 && cloud_coverage > 0.01) {
			vec4 cl = textureLod(cloud_tex, SCREEN_UV, 0.0);
			float fade = smoothstep(0.0, 0.09, d.y);
			col = col * (1.0 - cl.a * fade) + cl.rgb * fade;
		}

		col *= exposure;
		col += (ign - 0.5) / 255.0;    // dither against banding
		ALBEDO = max(col, vec3(0.0));
		ALPHA = 1.0;
	}
}
