shader_type sky;
// Noite de lua cheia: lua com crateras, halo, estrelas e nuvens prateadas.
uniform vec3 lua = vec3(0.6, 0.5, 0.6);
uniform float raio = 0.030;
uniform float nuvens = 0.5;
uniform float brilho = 1.0;

float h3(vec3 p) { p = fract(p * vec3(443.897, 441.423, 437.195)); p += dot(p, p.yzx + 19.19); return fract((p.x + p.y) * p.z); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++) { s += a * ru(p); p = p * 2.07 + vec2(13.1, 7.7); a *= 0.5; } return s; }

void sky() {
	vec3 d = EYEDIR;
	vec3 l = normalize(lua);
	float h = clamp(d.y, 0.0, 1.0);
	float m = dot(d, l);
	vec3 c = mix(vec3(0.020, 0.029, 0.048), vec3(0.0035, 0.006, 0.014), pow(h, 0.42));
	// halo
	float ang = acos(clamp(m, -1.0, 1.0));
	vec3 hal = vec3(0.52, 0.64, 0.86) * (0.16 * exp(-ang * 3.2) + 0.40 * exp(-ang * 11.0) + 0.9 * exp(-ang * 38.0));
	float cob = 0.0;
	if (!AT_CUBEMAP_PASS) {
		// estrelas
		vec3 p = d * 170.0;
		vec3 ip = floor(p);
		float s = h3(ip);
		if (s > 0.988 && d.y > 0.0) {
			vec3 f = fract(p) - 0.5;
			float e = smoothstep(0.28, 0.0, length(f)) * (s - 0.988) / 0.012;
			c += vec3(0.75, 0.85, 1.0) * e * 0.55 * (0.7 + 0.3 * sin(TIME * 2.0 + s * 900.0)) * smoothstep(0.0, 0.25, d.y);
		}
		// nuvens
		if (d.y > 0.01) {
			vec2 q = d.xz / (d.y + 0.16) * 0.9 + vec2(TIME * 0.006, TIME * 0.0025);
			float n = fbm(q * 1.5) * 0.75 + fbm(q * 5.0 + 3.0) * 0.25;
			cob = smoothstep(0.50 - nuvens * 0.12, 0.80 - nuvens * 0.12, n) * smoothstep(0.02, 0.20, d.y);
			float prata = pow(max(m, 0.0), 5.0);
			vec3 cn = mix(vec3(0.008, 0.011, 0.018), vec3(0.16, 0.19, 0.25), prata * (1.0 - cob * 0.6));
			c = mix(c, cn, cob * 0.88);
		}
		// disco
		float disco = smoothstep(raio, raio * 0.96, ang);
		if (disco > 0.0) {
			vec3 tx = normalize(cross(vec3(0.0, 1.0, 0.0), l));
			vec3 ty = cross(l, tx);
			vec2 uv = vec2(dot(d, tx), dot(d, ty)) / raio;
			float mar = fbm(uv * 1.7 + 4.0);
			float cra = fbm(uv * 7.0);
			float b = mix(1.0, 0.50, smoothstep(0.44, 0.62, mar)) * (0.82 + 0.36 * cra);
			b *= 0.72 + 0.28 * sqrt(max(0.0, 1.0 - dot(uv, uv)));
			c = mix(c, vec3(1.0, 0.975, 0.92) * b * 3.4, disco * (1.0 - cob * 0.72));
		}
	}
	c += hal * (1.0 - cob * 0.45);
	c = mix(c, vec3(0.010, 0.014, 0.022), smoothstep(0.02, -0.12, d.y));
	COLOR = c * brilho;
}
