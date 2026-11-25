shader_type spatial;
render_mode sss_mode_skin, diffuse_burley;
// Pele humana: poros, oleosidade, sangue correndo por baixo. Serve tambem para os mortos.
uniform sampler2D cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tinta : source_color = vec3(1.0);
uniform float palidez = 0.0;
uniform float sangue = 0.0;
uniform float geada = 0.0;
uniform float barba = 0.0;
uniform vec3 barba_cor : source_color = vec3(0.10, 0.07, 0.05);
uniform float semente = 0.0;
uniform float corta = 99.0;
varying float alt_c;
varying vec3 wn;
float h2(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { return ru(p) * 0.5 + ru(p * 2.13 + 7.1) * 0.3 + ru(p * 4.7 + 3.3) * 0.2; }
void vertex() { alt_c = VERTEX.y; wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz; }
void fragment() {
	if (alt_c > corta) discard;
	vec3 c = texture(cor, UV).rgb * tinta;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	// variacao de cor viva
	c *= 0.94 + 0.12 * fbm(UV * 60.0);
	// morto: perde o vermelho, arroxeia
	vec3 morto = mix(vec3(l), vec3(0.62, 0.64, 0.70) * (0.35 + l), 0.65);
	morto = mix(morto, morto * vec3(0.78, 0.72, 0.86), smoothstep(0.45, 0.7, fbm(UV * 9.0 + semente)));
	c = mix(c, morto, palidez);
	float rug = 0.50 + 0.14 * (fbm(UV * 34.0) - 0.5) + palidez * 0.1;
	// barba por fazer / barba
	float bm = smoothstep(0.25, 0.75, COLOR.r) * barba;
	float fio = ru(UV * vec2(1500.0, 620.0)) * 0.6 + ru(UV * vec2(900.0, 1900.0)) * 0.4;
	c = mix(c, barba_cor * (0.35 + 0.9 * fio), bm * smoothstep(0.25, 0.6, fio * 0.5 + bm * 0.6));
	rug = mix(rug, 0.85, bm);
	float sg = smoothstep(0.56, 0.62, fbm(UV * 8.0 + semente * 3.1)) * sangue;
	c = mix(c, vec3(0.085, 0.006, 0.005), sg * 0.92);
	rug = mix(rug, 0.28, sg);
	float gd = smoothstep(0.25, 0.8, wn.y * 0.55 + fbm(UV * 40.0) * 0.7 - 0.05) * geada;
	c = mix(c, vec3(0.80, 0.85, 0.90), gd * 0.75);
	float e = 0.0006;
	vec2 pq = UV * 900.0;
	float p0 = ru(pq), px = ru(pq + vec2(0.6, 0.0)), py = ru(pq + vec2(0.0, 0.6));
	NORMAL = normalize(NORMAL + (TANGENT * (p0 - px) + BINORMAL * (p0 - py)) * 0.10);
	ALBEDO = c;
	ROUGHNESS = mix(rug, 0.75, gd);
	SPECULAR = 0.42;
	SSS_STRENGTH = 0.30 * (1.0 - palidez * 0.6) * (1.0 - gd);
}