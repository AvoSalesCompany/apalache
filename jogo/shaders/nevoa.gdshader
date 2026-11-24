shader_type fog;
// Banco de neblina baixo com ruido, para o riacho e as baixadas.
uniform float dens = 0.06;
uniform vec3 cor : source_color = vec3(0.75, 0.82, 0.95);

float h3(vec3 p) { p = fract(p * vec3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
float ru(vec3 p) { vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z); }

void fog() {
	vec3 p = WORLD_POSITION;
	float n = ru(p * vec3(0.10, 0.22, 0.10) + vec3(TIME * 0.10, 0.0, TIME * 0.05)) * 0.65 + ru(p * vec3(0.27, 0.5, 0.27) - vec3(TIME * 0.12, 0.0, 0.0)) * 0.35;
	float borda = smoothstep(0.0, 0.35, min(min(UVW.x, 1.0 - UVW.x), min(UVW.z, 1.0 - UVW.z)));
	float alt = smoothstep(1.0, 0.25, UVW.y);
	DENSITY = dens * smoothstep(0.30, 0.75, n) * borda * alt;
	ALBEDO = cor;
}
