shader_type spatial;
render_mode cull_back, diffuse_burley;
// Chao da floresta: folhas, lama, musgo, rocha, seixos do rio e trilha.
uniform sampler2D splat : filter_linear, repeat_disable;
uniform sampler2D folha_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D folha_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D folha_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lama_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lama_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocha_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocha_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D seixo_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D seixo_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terra_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terra_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D neve_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D neve_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pisada_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pisada_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float neve = 1.0;
uniform vec3 luz_dir = vec3(0.6, 0.5, 0.6);
uniform vec3 luz_cor = vec3(0.0);
varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = NORMAL;
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = cross(NORMAL, TANGENT);
}

float h2(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
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
	float inc = 1.0 - wn.y;
	// ---- quanta neve ha aqui
	float q = 1.0 - smoothstep(0.0, 6.0, d_que + (n2 - 0.5) * 6.0);
	float pel = smoothstep(0.66, 0.80, fbm(wp.xz * 0.23 + 51.0) + (n3 - 0.5) * 0.10);
	float wt = 1.0 - smoothstep(0.35, 1.45, d_tri + (n2 - 0.5) * 0.9 + (n3 - 0.5) * 0.4);
	float cob = neve;
	cob *= 1.0 - smoothstep(0.26, 0.46, inc + (n2 - 0.5) * 0.22 + (n3 - 0.5) * 0.08);
	cob *= smoothstep(1.6, 3.6, d_rio + (n2 - 0.5) * 2.2);
	cob *= 1.0 - 0.82 * pel;
	cob *= 1.0 - 0.45 * wt * smoothstep(0.45, 0.75, n2);
	cob *= 1.0 - q * 0.96 * smoothstep(0.20, 0.55, n3 * 0.45 + n2 * 0.62);

	vec3 c = vec3(0.0), n = vec3(0.5, 0.5, 1.0);
	float ao = 1.0;
	float r = 0.72;
	vec2 u = wp.xz * 0.42;
	if (cob < 0.985) {
		vec2 ub = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * wp.xz * 0.27 + 0.37;
		float mt = smoothstep(0.35, 0.65, n2);
		c = mix(texture(folha_c, u).rgb, texture(folha_c, ub).rgb, mt);
		n = mix(texture(folha_n, u).rgb, texture(folha_n, ub).rgb, mt);
		ao = mix(texture(folha_a, u).r, texture(folha_a, ub).r, mt);
		c *= mix(0.62, 0.92, n1) * vec3(0.88, 0.90, 0.95);
		float wl = (1.0 - smoothstep(2.5, 8.5, d_rio + (n2 - 0.5) * 5.0)) * 0.9;
		wl = max(wl, (1.0 - smoothstep(0.4, 3.0, d_que + (n2 - 0.5) * 4.0)) * 0.95);
		mistura(c, n, r, texture(lama_c, u * 0.9).rgb * 0.66, texture(lama_n, u * 0.9).rgb, 0.46, wl);
		mistura(c, n, r, texture(terra_c, u * 0.9).rgb * vec3(0.56, 0.54, 0.52), texture(terra_n, u * 0.9).rgb, 0.8, wt * 0.92);
		float ws = 1.0 - smoothstep(1.6, 4.2, d_rio + (n2 - 0.5) * 2.4);
		mistura(c, n, r, texture(seixo_c, wp.xz * 0.34).rgb * 0.60, texture(seixo_n, wp.xz * 0.34).rgb, 0.34, ws);
		float wr = smoothstep(0.17, 0.32, inc + (n2 - 0.5) * 0.12);
		if (wr > 0.01) {
			vec3 bl = pow(abs(wn), vec3(4.0)); bl /= bl.x + bl.y + bl.z;
			vec3 rc = texture(rocha_c, wp.zy * 0.22).rgb * bl.x + texture(rocha_c, wp.xz * 0.22).rgb * bl.y + texture(rocha_c, wp.xy * 0.22).rgb * bl.z;
			vec3 rn = texture(rocha_n, wp.zy * 0.22).rgb * bl.x + texture(rocha_n, wp.xz * 0.22).rgb * bl.y + texture(rocha_n, wp.xy * 0.22).rgb * bl.z;
			mistura(c, n, r, rc * vec3(0.66, 0.68, 0.72), rn, 0.62, wr);
		}
		c = mix(c, vec3(0.012, 0.010, 0.009), q * 0.80 * smoothstep(0.3, 0.6, n3 * 0.5 + n2 * 0.5));
	}	float umido = (1.0 - smoothstep(2.0, 9.0, d_rio)) * (1.0 - cob);
	c *= mix(1.0, 0.62, umido);
	r = mix(r, r * 0.6, umido);
	// ---- neve por cima, entrando primeiro nos vaos
	float spark = 0.0;
	if (cob > 0.01) {
		vec2 un = wp.xz * 0.21;
		vec2 un2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * wp.xz * 0.083 + 0.31;
		vec3 nc = mix(texture(neve_c, un).rgb, texture(neve_c, un2).rgb, 0.45);
		vec3 nn = mix(texture(neve_n, un).rgb, texture(neve_n, un2).rgb, 0.5);
		float pis = clamp(wt * 0.9, 0.0, 1.0);
		if (pis > 0.01) {
			nc = mix(nc, texture(pisada_c, wp.xz * 0.33).rgb * vec3(0.80, 0.81, 0.84), pis);
			nn = mix(nn, texture(pisada_n, wp.xz * 0.33).rgb, pis);
		}
		// ondas de vento
		float e = 0.35;
		float w0 = fbm(wp.xz * vec2(0.30, 0.62));
		float wx = fbm((wp.xz + vec2(e, 0.0)) * vec2(0.30, 0.62));
		float wz = fbm((wp.xz + vec2(0.0, e)) * vec2(0.30, 0.62));
		nn.xy += vec2(w0 - wx, wz - w0) * 0.55;
		float l = lum(nc);
		nc = mix(vec3(0.70, 0.76, 0.84), vec3(0.90, 0.92, 0.95), clamp(l * 1.25, 0.0, 1.0)) * (0.90 + 0.14 * n1);
		// sujeira de agulhas e casca debaixo das arvores
		nc = mix(nc, vec3(0.24, 0.22, 0.19), smoothstep(0.70, 0.78, ru(wp.xz * 19.0) * 0.6 + ru(wp.xz * 43.0) * 0.4) * smoothstep(0.50, 0.66, n1) * 0.45);
		// cinza perto do aviao
		nc = mix(nc, vec3(0.10, 0.095, 0.09), (1.0 - smoothstep(0.0, 13.0, d_que)) * 0.55 * smoothstep(0.3, 0.7, n2));
		float k = smoothstep(0.30, 0.62, cob + (0.5 - lum(c) * 2.0) * 0.35 * (1.0 - cob));
		c = mix(c, nc, k);
		n = mix(n, nn, k);
		r = mix(r, 0.66, k);
		ao = mix(ao, 1.0, k);
		// cristais que piscam contra a luz
		float longe = 1.0 - smoothstep(4.0, 15.0, -VERTEX.z);
		if (longe > 0.0) {
			vec2 cel = floor(wp.xz * 150.0);
			if (h2(cel) > 0.965) {
				vec3 nr = normalize(vec3(h2(cel + 3.1) - 0.5, 1.6, h2(cel + 7.7) - 0.5));
				vec3 hv = normalize(normalize(luz_dir) + normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz));
				spark = smoothstep(0.985, 0.999, dot(nr, hv)) * k * longe;
			}
		}
	}
	EMISSION = luz_cor * spark;
	ALBEDO = c;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.15;
	ROUGHNESS = clamp(r + (n3 - 0.5) * 0.10, 0.08, 1.0);
	AO = ao;
	SPECULAR = 0.42;
}