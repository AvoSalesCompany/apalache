shader_type sky;
// Ceu completo: noite de lua cheia, amanhecer, dia de inverno e por do sol.
uniform vec3 lua = vec3(0.6, 0.5, 0.6);
uniform vec3 sol = vec3(0.0, -1.0, 0.0);
uniform float raio = 0.030;
uniform float nuvens = 0.5;
uniform float brilho = 1.0;
uniform float dia = 0.0;        // 0 noite .. 1 dia
uniform float crep = 0.0;       // cor do horizonte ao nascer/por do sol
uniform float neblina = 0.35;   // veu branco no horizonte

float h3(vec3 p) { p = fract(p * vec3(443.897, 441.423, 437.195)); p += dot(p, p.yzx + 19.19); return fract((p.x + p.y) * p.z); }
float h2(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++) { s += a * ru(p); p = p * 2.07 + vec2(13.1, 7.7); a *= 0.5; } return s; }

void sky() {
	vec3 d = EYEDIR;
	vec3 l = normalize(lua);
	vec3 s = normalize(sol);
	float h = clamp(d.y, 0.0, 1.0);
	float m = dot(d, l);
	float ms = max(dot(d, s), 0.0);
	float noite = 1.0 - smoothstep(0.0, 0.55, dia);
	// --- noite
	vec3 c = mix(vec3(0.020, 0.029, 0.048), vec3(0.0035, 0.006, 0.014), pow(h, 0.42)) * brilho;
	float ang = acos(clamp(m, -1.0, 1.0));
	vec3 hal = vec3(0.52, 0.64, 0.86) * (0.16 * exp(-ang * 3.2) + 0.40 * exp(-ang * 11.0) + 0.9 * exp(-ang * 38.0)) * brilho;
	// --- dia
	vec3 azul = mix(vec3(0.60, 0.70, 0.82), vec3(0.14, 0.27, 0.52), pow(h, 0.50));
	vec2 dh = normalize(d.xz + vec2(0.0001)), sh = normalize(s.xz + vec2(0.0001));
	float perto = pow(clamp(dot(dh, sh) * 0.5 + 0.5, 0.0, 1.0), 3.0);
	vec3 quente = mix(vec3(0.34, 0.24, 0.36), mix(vec3(1.0, 0.36, 0.10), vec3(1.0, 0.70, 0.34), exp(-h * 9.0)), perto);
	float faixa = exp(-h * mix(7.0, 3.2, perto));
	vec3 cd = mix(azul, quente, clamp(crep * faixa * (0.45 + 0.65 * perto), 0.0, 1.0));
	cd = mix(cd, vec3(0.74, 0.78, 0.83) * mix(vec3(1.0), vec3(1.05, 0.80, 0.66), crep * 0.8), neblina * exp(-h * 6.0));
	cd += vec3(1.0, 0.62, 0.30) * (0.35 * pow(ms, 8.0) + 0.9 * pow(ms, 90.0)) * mix(0.35, 1.0, crep);
	float forca = dia;
	c = c * noite + cd * forca;
	float cob = 0.0;
	if (!AT_CUBEMAP_PASS) {
		if (noite > 0.01) {
			vec3 p = d * 170.0;
			vec3 ip = floor(p);
			float st = h3(ip);
			if (st > 0.988 && d.y > 0.0) {
				vec3 f = fract(p) - 0.5;
				float e = smoothstep(0.28, 0.0, length(f)) * (st - 0.988) / 0.012;
				c += vec3(0.75, 0.85, 1.0) * e * 0.55 * (0.7 + 0.3 * sin(TIME * 2.0 + st * 900.0)) * smoothstep(0.0, 0.25, d.y) * noite * noite * brilho;
			}
		}
		// disco do sol
		float as = acos(clamp(dot(d, s), -1.0, 1.0));
		float ds = smoothstep(0.0135, 0.0115, as) * dia;
		// nuvens
		if (d.y > 0.01) {
			vec2 q = d.xz / (d.y + 0.16) * 0.9 + vec2(TIME * 0.006, TIME * 0.0025);
			float n = fbm(q * 1.5) * 0.75 + fbm(q * 5.0 + 3.0) * 0.25;
			cob = smoothstep(0.50 - nuvens * 0.12, 0.80 - nuvens * 0.12, n) * smoothstep(0.02, 0.20, d.y);
			float prata = pow(max(m, 0.0), 5.0);
			vec3 cn = mix(vec3(0.008, 0.011, 0.018), vec3(0.16, 0.19, 0.25), prata * (1.0 - cob * 0.6)) * brilho * noite;
			vec3 nd = mix(vec3(0.46, 0.51, 0.58), vec3(0.84, 0.86, 0.88), 1.0 - cob * 0.6);
			nd = mix(nd, mix(vec3(0.46, 0.30, 0.36), vec3(1.15, 0.52, 0.24), perto) * (1.1 - cob * 0.45), crep * smoothstep(0.75, 0.0, h));
			nd += vec3(1.0, 0.7, 0.4) * pow(ms, 10.0) * (1.0 - cob) * 0.6;
			c = mix(c, cn + nd * forca, cob * 0.88);
		}
		c += vec3(1.0, 0.80, 0.55) * ds * mix(28.0, 14.0, crep) * (1.0 - cob * 0.8) * smoothstep(-0.02, 0.0, d.y);
		// lua
		float disco = smoothstep(raio, raio * 0.96, ang);
		if (disco > 0.0) {
			vec3 tx = normalize(cross(vec3(0.0, 1.0, 0.0), l));
			vec3 ty = cross(l, tx);
			vec2 uv = vec2(dot(d, tx), dot(d, ty)) / raio;
			float mar = fbm(uv * 1.7 + 4.0);
			float cra = fbm(uv * 7.0);
			float b = mix(1.0, 0.50, smoothstep(0.44, 0.62, mar)) * (0.82 + 0.36 * cra);
			b *= 0.72 + 0.28 * sqrt(max(0.0, 1.0 - dot(uv, uv)));
			c = mix(c, vec3(1.0, 0.975, 0.92) * b * 3.4 * brilho, disco * (1.0 - cob * 0.72) * noite);
		}
	}
	c += hal * (1.0 - cob * 0.45) * noite;
	vec3 baixo = mix(vec3(0.010, 0.014, 0.022) * brilho * noite, vec3(0.62, 0.66, 0.72) * forca, dia);
	c = mix(c, baixo, smoothstep(0.02, -0.12, d.y));
	COLOR = c;
}