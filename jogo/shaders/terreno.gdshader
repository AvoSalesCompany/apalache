shader_type spatial;
render_mode cull_back, diffuse_burley;
// Chao da floresta: folhas, lama, musgo, rocha, seixos do rio e trilha.
uniform sampler2D splat : filter_linear, repeat_disable;
uniform sampler2D folha_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D folha_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D folha_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lama_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lama_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mato_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mato_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocha_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocha_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D seixo_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D seixo_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terra_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terra_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = NORMAL;
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = cross(NORMAL, TANGENT);
}

float h2(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { return ru(p) * 0.5 + ru(p * 2.13 + 7.1) * 0.3 + ru(p * 4.7 + 3.3) * 0.2; }
float lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }

// mistura por altura (usa o brilho da textura como relevo)
void mistura(inout vec3 c, inout vec3 n, inout float r, vec3 c2, vec3 n2, float r2, float w) {
	float a = lum(c) * 1.2 + (1.0 - w);
	float b = lum(c2) * 1.2 + w;
	float k = smoothstep(-0.18, 0.18, b - a);
	c = mix(c, c2, k); n = mix(n, n2, k); r = mix(r, r2, k);
}

void fragment() {
	vec4 sp = texture(splat, (wp.xz + 512.0 + 1.0) / 1026.0);
	float d_tri = (1.0 - sp.r) * 6.0;
	float d_rio = (1.0 - sp.g) * 12.0;
	float d_rod = (1.0 - sp.b) * 16.0;
	float d_que = (1.0 - sp.a) * 14.0;
	float n1 = fbm(wp.xz * 0.09);
	float n2 = fbm(wp.xz * 0.55 + 31.0);
	float n3 = ru(wp.xz * 2.7);
	vec2 u = wp.xz * 0.42;
	vec2 ub = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * wp.xz * 0.27 + 0.37;
	float mt = smoothstep(0.35, 0.65, n2);

	vec3 c = mix(texture(folha_c, u).rgb, texture(folha_c, ub).rgb, mt);
	vec3 n = mix(texture(folha_n, u).rgb, texture(folha_n, ub).rgb, mt);
	float ao = mix(texture(folha_a, u).r, texture(folha_a, ub).r, mt);
	float r = 0.72;
	c *= mix(0.72, 1.08, n1);

	// musgo / chao de mato
	float wm = smoothstep(0.50, 0.68, n1 + (n2 - 0.5) * 0.4);
	mistura(c, n, r, texture(mato_c, u * 0.8).rgb * vec3(0.62, 0.72, 0.55), texture(mato_n, u * 0.8).rgb, 0.85, wm);
	// lama
	float wl = smoothstep(0.60, 0.76, fbm(wp.xz * 0.13 + 90.0) + (n3 - 0.5) * 0.15);
	wl = max(wl, (1.0 - smoothstep(2.5, 8.5, d_rio + (n2 - 0.5) * 5.0)) * 0.9);
	wl = max(wl, (1.0 - smoothstep(0.4, 3.0, d_que + (n2 - 0.5) * 4.0)) * 0.95);
	mistura(c, n, r, texture(lama_c, u * 0.9).rgb * 0.72, texture(lama_n, u * 0.9).rgb, 0.46, wl);
	// trilha de terra
	float wt = 1.0 - smoothstep(0.35, 1.25, d_tri + (n2 - 0.5) * 0.9 + (n3 - 0.5) * 0.4);
	mistura(c, n, r, texture(terra_c, u * 0.9).rgb * vec3(0.60, 0.55, 0.50), texture(terra_n, u * 0.9).rgb, 0.8, wt * 0.92);
	// seixos do rio
	float ws = 1.0 - smoothstep(1.6, 4.2, d_rio + (n2 - 0.5) * 2.4);
	mistura(c, n, r, texture(seixo_c, wp.xz * 0.34).rgb * 0.62, texture(seixo_n, wp.xz * 0.34).rgb, 0.34, ws);
	// acostamento
	float wa = 1.0 - smoothstep(4.4, 7.0, d_rod + (n2 - 0.5) * 2.5);
	mistura(c, n, r, texture(terra_c, wp.xz * 0.5).rgb * 0.75, texture(terra_n, wp.xz * 0.5).rgb, 0.85, wa);
	// rocha em encosta (triplanar)
	float inc = 1.0 - wn.y;
	float wr = smoothstep(0.17, 0.32, inc + (n2 - 0.5) * 0.12);
	if (wr > 0.01) {
		vec3 bl = pow(abs(wn), vec3(4.0)); bl /= bl.x + bl.y + bl.z;
		vec3 rc = texture(rocha_c, wp.zy * 0.22).rgb * bl.x + texture(rocha_c, wp.xz * 0.22).rgb * bl.y + texture(rocha_c, wp.xy * 0.22).rgb * bl.z;
		vec3 rn = texture(rocha_n, wp.zy * 0.22).rgb * bl.x + texture(rocha_n, wp.xz * 0.22).rgb * bl.y + texture(rocha_n, wp.xy * 0.22).rgb * bl.z;
		mistura(c, n, r, rc * 0.8, rn, 0.62, wr);
	}
	// queimado em volta do aviao
	float q = 1.0 - smoothstep(0.0, 6.0, d_que + (n2 - 0.5) * 6.0);
	c = mix(c, vec3(0.012, 0.010, 0.009), q * 0.75 * smoothstep(0.3, 0.6, n3 * 0.5 + n2 * 0.5));

	float umido = 1.0 - smoothstep(2.0, 9.0, d_rio);
	c *= mix(1.0, 0.62, umido);
	r = mix(r, r * 0.6, umido);
	ALBEDO = c;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.25;
	ROUGHNESS = clamp(r + (n3 - 0.5) * 0.12, 0.2, 1.0);
	AO = ao;
	SPECULAR = 0.4;
}
