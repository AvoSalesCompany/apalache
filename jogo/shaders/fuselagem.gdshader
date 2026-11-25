shader_type spatial;
render_mode cull_disabled;
// Casco do aviao: chapas, rebites, faixa pintada, sujeira, amassados e fuligem.
uniform sampler2D nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float queimado = 0.0;
uniform float faixa = 1.0;
uniform vec3 base : source_color = vec3(0.60, 0.61, 0.60);
uniform vec3 cor1 : source_color = vec3(0.07, 0.13, 0.24);
uniform vec3 cor2 : source_color = vec3(0.45, 0.12, 0.07);
varying vec3 op;

float h2(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { return ru(p) * 0.5 + ru(p * 2.1 + 3.0) * 0.3 + ru(p * 4.7 + 9.0) * 0.2; }

void vertex() { op = VERTEX; }

void fragment() {
	vec2 u = UV;
	vec3 c = base;
	// faixa da companhia
	float y = op.y;
	float f1 = smoothstep(0.004, 0.0, abs(y + 0.03) - 0.085);
	float f2 = smoothstep(0.004, 0.0, abs(y + 0.155) - 0.022);
	c = mix(c, cor1, f1 * faixa);
	c = mix(c, cor2, f2 * faixa);
	c = mix(c, vec3(0.30, 0.31, 0.32), smoothstep(-0.50, -0.56, y) * faixa);
	// chapas
	vec2 g = abs(fract(u / vec2(0.62, 0.80)) - 0.5) * vec2(0.62, 0.80);
	vec2 bd = vec2(0.31, 0.40) - g;
	float d = min(bd.x, bd.y);
	float linha = smoothstep(0.0055, 0.002, d);
	// rebites
	vec2 r = vec2(0.0);
	float reb = 0.0;
	vec2 rv = abs(vec2(d - 0.022, fract((bd.x < bd.y ? u.y : u.x) / 0.045) * 0.045 - 0.0225));
	reb = smoothstep(0.0065, 0.004, length(rv));
	// sujeira escorrida
	float su = fbm(vec2(u.y * 3.0, u.x * 0.7)) * 0.6 + fbm(u * 5.0) * 0.4;
	float esc = smoothstep(0.42, 0.75, su);
	c *= mix(1.0, 0.62, esc * 0.8);
	c *= 1.0 - linha * 0.75;
	c *= 1.0 - reb * 0.18;
	// tinta descascada
	float des = smoothstep(0.70, 0.74, fbm(u * 2.3 + 17.0) + 0.06 * ru(u * 40.0));
	c = mix(c, vec3(0.42, 0.43, 0.44), des * 0.8);
	float metal = des * 0.8;
	float rug = mix(0.46, 0.34, des) + esc * 0.18;
	// fuligem e barro da queda
	if (queimado > 0.0) {
		float q = smoothstep(1.0 - queimado * 0.75, 1.15 - queimado * 0.55, fbm(op.zy * 0.9 + op.x * 0.4) + 0.22 * fbm(op.zx * 4.0));
		c = mix(c, vec3(0.012, 0.011, 0.010), q * 0.94);
		float ba = smoothstep(-0.2, -1.0, y + (fbm(op.zx * 2.0) - 0.5) * 0.9);
		c = mix(c, vec3(0.055, 0.040, 0.026) * (0.6 + 0.8 * ru(op.zx * 14.0)), ba * 0.85 * queimado);
		rug = mix(rug, 0.95, max(q, ba));
		metal *= 1.0 - q;
		float ris = smoothstep(0.93, 0.97, ru(vec2(u.x * 38.0, u.y * 1.4)));
		c = mix(c, vec3(0.45), ris * 0.5 * (1.0 - q));
	}
	ALBEDO = c;
	METALLIC = metal;
	ROUGHNESS = clamp(rug, 0.2, 1.0);
	SPECULAR = 0.5;
	vec3 n = texture(nor, u * 0.6).rgb;
	// ondulacao das chapas (reflexo vivo)
	vec2 w = vec2(ru(u * 3.1) - ru(u * 3.1 + vec2(0.15, 0.0)), ru(u * 3.1 + 5.0) - ru(u * 3.1 + vec2(5.0, 5.15))) * (0.35 + queimado * 1.6);
	n.xy += w + vec2(linha * 0.15, 0.0);
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 0.8;
	if (!FRONT_FACING) { ALBEDO = c * 0.25; }
}
