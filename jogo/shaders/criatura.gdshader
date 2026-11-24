shader_type spatial;
render_mode cull_back;
// Pele do Chamador. UV/UV2 guardam a posicao na pose original. COLOR.g = osso.
uniform float dissolve = 0.0;

float h3(vec3 p) { p = fract(p * vec3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
float ru(vec3 p) { vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z); }
float fbm(vec3 p) { return ru(p) * 0.5 + ru(p * 2.1) * 0.28 + ru(p * 4.3) * 0.14 + ru(p * 9.0) * 0.08; }

void fragment() {
	vec3 p = vec3(UV, UV2.x);
	float osso = smoothstep(0.35, 0.75, COLOR.g);
	float pelo = ru(p * vec3(150.0, 34.0, 60.0)) * 0.55 + ru(p * vec3(260.0, 60.0, 110.0)) * 0.45;
	float falha = smoothstep(0.46, 0.60, fbm(p * 5.0));
	vec3 pele = mix(vec3(0.060, 0.046, 0.036), vec3(0.135, 0.118, 0.104), fbm(p * 9.0));
	vec3 pel = mix(vec3(0.020, 0.015, 0.011), vec3(0.075, 0.056, 0.040), pelo);
	vec3 c = mix(pel, pele, falha);
	c = mix(c, vec3(0.28, 0.25, 0.19) * (0.45 + 0.8 * fbm(p * 22.0)), osso);
	float foc = smoothstep(0.15, 0.24, COLOR.g) * (1.0 - osso);
	c = mix(c, vec3(0.10, 0.085, 0.072), foc * 0.5);
	float dz = fbm(p * 14.0);
	if (dissolve > 0.0 && dz < dissolve) discard;
	float e = 0.004;
	vec3 g = vec3(fbm(p * 26.0 + vec3(e * 26.0, 0, 0)), fbm(p * 26.0 + vec3(0, e * 26.0, 0)), fbm(p * 26.0 + vec3(0, 0, e * 26.0))) - fbm(p * 26.0);
	NORMAL = normalize(NORMAL - (VIEW_MATRIX * vec4(g, 0.0)).xyz * 2.2 * (1.0 - osso * 0.5));
	ALBEDO = c;
	ROUGHNESS = mix(mix(0.85, 0.42, falha), 0.55, osso);
	SPECULAR = 0.45;
}
