shader_type spatial;
// Serra vista de cima, rolando sob o aviao.
uniform vec2 desloc = vec2(0.0);
uniform float rugosa = 1.0;
varying vec3 wp;
varying float alt;
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float serra(vec2 p) {
	float a = 1.0, s = 0.0; vec2 q = p * 0.0016;
	for (int i = 0; i < 4; i++) { float n = 1.0 - abs(ru(q) * 2.0 - 1.0); s += a * n * n; q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * q * 2.1 + 5.3; a *= 0.45; }
	return s * 170.0;
}
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = w.xz + desloc;
	float e = 9.0;
	float h = serra(p);
	float hx = serra(p + vec2(e, 0.0)), hz = serra(p + vec2(0.0, e));
	VERTEX.y += h;
	NORMAL = normalize(vec3(h - hx, e, h - hz));
	wp = vec3(p.x, w.y + h, p.y);
	alt = h;
}
void fragment() {
	// copas das arvores
	float c = ru(wp.xz * 0.16) * 0.5 + ru(wp.xz * 0.37) * 0.35 + ru(wp.xz * 0.9) * 0.15;
	float e = 1.6;
	float cx = ru((wp.xz + vec2(e, 0)) * 0.16) * 0.5 + ru((wp.xz + vec2(e, 0)) * 0.37) * 0.35;
	float cz = ru((wp.xz + vec2(0, e)) * 0.16) * 0.5 + ru((wp.xz + vec2(0, e)) * 0.37) * 0.35;
	float c0 = ru(wp.xz * 0.16) * 0.5 + ru(wp.xz * 0.37) * 0.35;
	vec3 g = vec3(c0 - cx, 0.0, c0 - cz) * 2.6 * rugosa;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(g, 0.0)).xyz);
	ALBEDO = mix(vec3(0.030, 0.040, 0.034), vec3(0.085, 0.092, 0.075), c);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
