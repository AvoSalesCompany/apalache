shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;
// Janela de aviao: reflexo leve da cabine, riscos, gelo na borda, condensacao.
uniform vec3 reflexo : source_color = vec3(0.50, 0.40, 0.26);
uniform float forca = 1.0;
uniform float rachado = 0.0;
float h2(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float fr = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	float ri = smoothstep(0.965, 0.99, ru(vec2(p.x * 3.0 + p.y * 2.0, (p.y - p.x * 0.4) * 90.0))) * 0.10;
	float gelo = smoothstep(0.62, 1.02, r + (ru(p * 9.0) - 0.5) * 0.35) * (0.5 + 0.5 * ru(p * 60.0));
	vec2 c = floor(p * 26.0);
	vec2 q = fract(p * 26.0) - 0.5 + (vec2(h2(c), h2(c + 9.0)) - 0.5) * 0.6;
	float gt = smoothstep(0.17, 0.05, length(q)) * step(0.80, h2(c + 3.0)) * smoothstep(0.1, -0.9, p.y);
	float faixa = smoothstep(0.22, 0.0, abs(p.x * 0.8 + p.y * 0.5 - 0.25)) * 0.35;
	float cr = 0.0;
	if (rachado > 0.0) {
		float a = atan(p.y - 0.2, p.x + 0.1);
		cr = smoothstep(0.03, 0.0, abs(fract(a * 1.9 + ru(vec2(r * 5.0, 2.0)) * 0.5) - 0.5) * r) * rachado;
		cr += smoothstep(0.02, 0.0, abs(fract(r * 3.0 + ru(p * 4.0) * 0.5) - 0.5) * 0.3) * rachado * 0.5;
	}
	ALBEDO = mix(vec3(0.02), vec3(0.55, 0.62, 0.72), clamp(gelo * 0.6 + gt + cr + ri, 0.0, 1.0));
	EMISSION = reflexo * (fr * 0.05 + faixa * 0.012) * forca;
	ROUGHNESS = mix(0.04, 0.6, clamp(gelo + cr, 0.0, 1.0));
	SPECULAR = 0.6;
	ALPHA = clamp(0.06 + fr * 0.30 + gelo * 0.20 + gt * 0.35 + ri + cr * 0.7, 0.0, 0.92);
}
