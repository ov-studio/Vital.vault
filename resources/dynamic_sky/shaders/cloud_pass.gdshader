shader_type canvas_item;
render_mode blend_disabled;

// Dynamic Sky: volumetric cloud march into a small HDR rendertarget (cloud_blur.gdshader blurs it, sky.gdshader reads it).
// Output: rgb = in-scattered light, a = 1 - transmittance.
// NOTE: never write the text of the entry point signatures inside comments (the engine injects code there).

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;   // R shape, G erosion, B detail
uniform vec3  cam_x   = vec3(1.0, 0.0, 0.0);      // camera axes (right, up, back), from Lua
uniform vec3  cam_y   = vec3(0.0, 1.0, 0.0);
uniform vec3  cam_z   = vec3(0.0, 0.0, 1.0);
uniform vec3  cam_pos = vec3(0.0);
uniform vec2  tan_xy  = vec2(1.0, 0.5625);        // tan of the half fov

uniform vec3  horizon_color    = vec3(0.55, 0.70, 0.88);
uniform vec3  light_dir        = vec3(0.0, 1.0, 0.0);
uniform vec3  light_color      = vec3(1.0, 0.95, 0.85);
uniform vec3  cloud_ambient_top    = vec3(0.45, 0.58, 0.80);
uniform vec3  cloud_ambient_bottom = vec3(0.30, 0.34, 0.42);
uniform float cloud_silver     = 1.0;
uniform float cloud_coverage   = 0.40;
uniform float cloud_density    = 0.004;
uniform float cloud_type       = 0.75;
uniform float cloud_base       = 1500.0;
uniform float cloud_thickness  = 2500.0;
uniform float cloud_scale      = 2600.0;
uniform float cloud_detail     = 0.55;
uniform float cloud_steps      = 40.0;
uniform float cloud_light_steps= 4.0;
uniform float cloud_opacity    = 1.0;
uniform vec3  wind_offset      = vec3(0.0);
uniform float cloud_time       = 0.0;
uniform float haze_density     = 0.000012;

const float PI_ = 3.14159265359;
const float PLANET_R = 6000000.0;

float sk_remap(float v, float a, float b, float c, float d) {
	return c + ((v - a) / (b - a)) * (d - c);
}

float sk_hg(float cos_t, float g) {
	return 0.0795774715459 * (1.0 - g * g) / pow(max(1.0 + g * g - 2.0 * g * cos_t, 0.0001), 1.5);
}

float sk_height_gradient(float hf, float ctype) {
	vec4 stratus = vec4(0.02, 0.05, 0.09, 0.11);
	vec4 strato  = vec4(0.02, 0.20, 0.48, 0.625);
	vec4 cumulus = vec4(0.01, 0.0625, 0.78, 1.0);
	float ws = 1.0 - clamp(ctype * 2.0, 0.0, 1.0);
	float wm = 1.0 - abs(ctype - 0.5) * 2.0;
	float wc = clamp(ctype - 0.5, 0.0, 1.0) * 2.0;
	vec4 g = stratus * ws + strato * wm + cumulus * wc;
	return smoothstep(g.x, g.y, hf) - smoothstep(g.z, g.w, hf);
}

// 3D noise from a tileable 2D texture (two slices blended along z), p in cells, one tile = 16 cells
vec3 sk_tex3l(vec3 p, float lod) {
	float zi = floor(p.z);
	float zf = p.z - zi;
	zf = zf * zf * (3.0 - 2.0 * zf);
	vec2 uv = fract(p.xy * 0.0625);
	vec2 o0 = fract(vec2(0.3181, 0.7257) * zi);
	vec2 o1 = fract(vec2(0.3181, 0.7257) * (zi + 1.0));
	vec3 a = textureLod(noise_tex, uv + o0, lod).rgb;
	vec3 b = textureLod(noise_tex, uv + o1, lod).rgb;
	return mix(a, b, zf);
}

vec3 sk_tex3(vec3 p) {
	return sk_tex3l(p, 0.0);
}

// lod 0 = full detail, 1 = shape only (light march, far steps)
float sk_cloud_density(vec3 q, float hf, float lod) {
	float cov = cloud_coverage;
	float grad = sk_height_gradient(hf, cloud_type);
	if (grad <= 1.0 - cov) {
		return 0.0;                                   // coverage remap can only give 0 here
	}
	vec3 pw = (q + wind_offset) / cloud_scale;
	pw.y -= cloud_time * 0.00004 * cloud_scale * 0.1;

	vec3 n = sk_tex3(pw);                                 // R perlin-worley, G worley fbm
	float shape = n.r;

	// upper bound of the result, erosion can only lower it
	float bound = clamp(sk_remap((shape + 1.0) * 0.5 * grad, 1.0 - cov, 1.0, 0.0, 1.0), 0.0, 1.0);
	if (bound <= 0.0) {
		return 0.0;
	}

	float wfbm = lod < 0.5 ? n.g : 0.5;
	float base = clamp((shape + 1.0 - wfbm) / (2.0 - wfbm), 0.0, 1.0);
	base = clamp(sk_remap(base * grad, 1.0 - cov, 1.0, 0.0, 1.0), 0.0, 1.0);
	base *= cov;
	if (base <= 0.0 || lod > 0.5) {
		return base;
	}

	// high frequency erosion: wispy at the bottom, billowy at the top
	vec3 pd = pw * 7.0;
	pd.y -= cloud_time * 0.00012;
	float dfbm = sk_tex3(pd).b;
	dfbm = mix(dfbm, 1.0 - dfbm, clamp(hf * 4.0, 0.0, 1.0));
	base = clamp(sk_remap(base, dfbm * cloud_detail * 0.7 * hf, 1.0, 0.0, 1.0), 0.0, 1.0);
	return pow(base, (1.0 - hf) * 0.8 + 0.5);
}

float sk_ray_sphere_far(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - r * r;
	float disc = b * b - c;
	return -b + sqrt(max(disc, 0.0));
}

// rgb = in-scattered light, a = 1 - transmittance
vec4 sk_clouds(vec3 d, vec3 cam, float jitter) {
	float cam_alt = clamp(cam.y, 0.0, cloud_base * 0.6);
	vec3 ro = vec3(0.0, PLANET_R + cam_alt, 0.0);
	float rb = PLANET_R + cloud_base;
	float rt = rb + cloud_thickness;
	float t0 = sk_ray_sphere_far(ro, d, rb);
	float t1 = sk_ray_sphere_far(ro, d, rt);
	float shell = min(t1 - t0, 40000.0);
	// fewer steps when looking up (thin layer), never finer than one step per ~170 m
	float steps = clamp(shell / 170.0, min(8.0, cloud_steps), max(cloud_steps, 6.0));
	float dt = shell / steps;

	vec3 RANDV[6] = vec3[6](
		vec3(0.38051305, 0.92453449, -0.02111345),
		vec3(-0.50625799, -0.03590792, -0.86163418),
		vec3(-0.32509218, -0.94557439, 0.01428793),
		vec3(0.09026238, -0.27376545, 0.95755165),
		vec3(0.28128598, 0.42443639, -0.86065785),
		vec3(-0.16852403, 0.14748697, 0.97460106));

	float lss = cloud_thickness / 30.0;
	float cos_t = dot(d, light_dir);
	float phase = mix(sk_hg(cos_t, -0.25) * 0.55, sk_hg(cos_t, 0.55), 0.45) * 4.0 * PI_ * 0.5;
	float silver = pow(max(cos_t, 0.0), 12.0) * cloud_silver * 0.9;

	vec3 L = vec3(0.0);
	float T = 1.0;
	int nl = int(clamp(cloud_light_steps, 1.0, 6.0));
	bool light_on = dot(light_color, vec3(1.0)) > 0.03;      // no light march at night
	float lit_c = 0.8;                                        // light of the last step, reused every second step
	float beers_c = 0.8;
	int lcount = 0;

	for (int i = 0; i < 160; i++) {
		if (float(i) >= steps || T < 0.04) {
			break;
		}
		float tm = t0 + (float(i) + jitter) * dt;
		vec3 p = ro + d * tm;
		float pl = length(p);
		float hf = clamp((pl - rb) / cloud_thickness, 0.0, 1.0);
		vec3 q = vec3(p.x + cam.x, pl - PLANET_R, p.z + cam.z);
		float far_lod = tm > 22000.0 ? 1.0 : 0.0;          // distant steps use the cheap density
		float dn = sk_cloud_density(q, hf, far_lod);
		dn *= 1.0 - 0.65 * smoothstep(14000.0, 50000.0, tm);   // sparser with distance, no solid wall at the horizon
		if (dn <= 0.002) {
			continue;
		}

		float lit = lit_c;
		float beers = beers_c;
		// light march toward the key light, skipped on thin edges / at night
		if (light_on && dn > 0.03 && far_lod < 0.5) {
			if ((lcount & 1) == 0) {
				float cd = 0.0;
				vec3 lp = p;
				for (int j = 0; j < 6; j++) {
					if (j >= nl) {
						break;
					}
					lp += (light_dir + RANDV[j] * float(j) * 0.55) * lss;
					float lpl = length(lp);
					float lhf = clamp((lpl - rb) / cloud_thickness, 0.0, 1.0);
					cd += sk_cloud_density(vec3(lp.x + cam.x, lpl - PLANET_R, lp.z + cam.z), lhf, 1.0);
				}
				// one far sample for long range self shadowing
				vec3 fp = p + light_dir * lss * 9.0;
				float fpl = length(fp);
				float fhf = clamp((fpl - rb) / cloud_thickness, 0.0, 1.0);
				cd += sk_cloud_density(vec3(fp.x + cam.x, fpl - PLANET_R, fp.z + cam.z), fhf, 1.0) * 2.0;

				float tau = cloud_density * cd * lss;
				beers_c = exp(-tau);
				float beers2 = exp(-tau * 0.25) * 0.7;
				lit_c = max(beers_c, beers2);
			}
			lcount++;
			beers = beers_c;
			float powder = 1.0 - exp(-dn * 5.0);
			lit = lit_c * mix(1.0, powder, 0.5);
		}

		vec3 sun_term = light_color * lit * (phase + silver * beers);
		vec3 amb_term = mix(cloud_ambient_bottom, cloud_ambient_top, smoothstep(0.0, 1.0, hf));

		float sigma = cloud_density * dn;
		float step_t = exp(-sigma * dt);
		vec3 S = (sun_term + amb_term) * sigma;
		L += T * (S - S * step_t) / max(sigma, 0.00001);
		T *= step_t;
	}

	// blend far clouds into the horizon haze
	float haze = clamp(1.0 - exp(-t0 * haze_density), 0.0, 1.0);
	float a = (1.0 - T) * cloud_opacity;
	L = mix(L, horizon_color * a, haze * 0.85) * cloud_opacity;
	// thin out toward the horizon
	float far_fade = 1.0 - 0.8 * smoothstep(12000.0, 60000.0, t0);
	return vec4(L * far_fade, a * far_fade);
}

void fragment() {
	vec2 ndc = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	vec3 d = normalize(cam_x * (ndc.x * tan_xy.x) + cam_y * (ndc.y * tan_xy.y) - cam_z);
	vec4 r = vec4(0.0);
	if (d.y > 0.012 && cloud_coverage > 0.01) {
		float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		r = sk_clouds(d, cam_pos, ign);
	}
	COLOR = vec4(max(r.rgb, vec3(0.0)), clamp(r.a, 0.0, 1.0));
}
