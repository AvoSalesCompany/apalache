shader_type spatial;
render_mode cull_back;
// Plastico do interior do aviao: textura fina, emendas, encardido nas bordas.
uniform vec3 cor : source_color = vec3(0.56, 0.53, 0.46);
uniform float sujo = 0.35;
uniform float emenda = 1.0;
uniform float tecido = 0.0;
varying vec3 op;
float h2(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { return ru(p) * 0.5 + ru(p * 2.1 + 3.0) * 0.3 + ru(p * 4.7 + 9.0) * 0.2; }
void vertex() { op = VERTEX; }
void fragment() {
	vec2 u = UV;
	vec3 c = cor;
	float gr = ru(u * 420.0);
	float gr2 = ru(u * 150.0 + 7.0);
	float m = fbm(u * 1.7);
	c *= 0.90 + 0.16 * m;
	// emenda vertical entre paineis
	float d = abs(fract(u.y / 0.80 + 0.5) - 0.5) * 0.80;
	float l = smoothstep(0.006, 0.002, d) * emenda;
	c *= 1.0 - l * 0.7;
	float mancha = smoothstep(0.50, 0.85, fbm(u * vec2(2.0, 3.3) + 20.0)) * sujo;
	c = mix(c, c * vec3(0.62, 0.55, 0.44), mancha);
	c = mix(c, c * vec3(0.70, 0.66, 0.58), smoothstep(0.05, 0.0, d) * sujo * 0.7);
	float t = 0.0;
	if (tecido > 0.0) {
		t = (sin(u.x * 900.0) * sin(u.y * 900.0)) * 0.5 + 0.5;
		c *= mix(1.0, 0.72 + 0.4 * t, tecido) * (0.85 + 0.3 * gr2);
	}
	ALBEDO = c;
	ROUGHNESS = mix(0.52 + 0.16 * gr, 0.95, tecido) + mancha * 0.2;
	SPECULAR = mix(0.42, 0.15, tecido);
	vec2 e = vec2(1.0 / 420.0, 0.0);
	vec2 b = vec2(gr - ru(u * 420.0 + vec2(0.6, 0.0)), gr - ru(u * 420.0 + vec2(0.0, 0.6))) * mix(0.16, 0.5, tecido);
	NORMAL_MAP = vec3(0.5 + b * 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.7;
}
