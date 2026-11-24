shader_type spatial;
// Rodovia: UV.x = 0..1 na largura, UV.y = metros.
uniform sampler2D cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wp;
float h2(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 c = texture(cor, wp.xz * 0.28).rgb * 0.55;
	float x = (UV.x - 0.5) * 8.0;
	float gasto = smoothstep(0.35, 0.6, ru(wp.xz * 1.7) * 0.6 + ru(wp.xz * 9.0) * 0.4);
	float f1 = smoothstep(0.075, 0.05, abs(abs(x) - 0.16));
	float f2 = smoothstep(0.075, 0.05, abs(abs(x) - 3.55));
	c = mix(c, vec3(0.62, 0.44, 0.08), f1 * gasto);
	c = mix(c, vec3(0.62, 0.62, 0.60), f2 * gasto);
	float poca = smoothstep(0.60, 0.72, ru(wp.xz * 0.35) * 0.7 + ru(wp.xz * 1.1) * 0.3);
	ALBEDO = c * mix(1.0, 0.5, poca);
	NORMAL_MAP = mix(texture(nor, wp.xz * 0.28).rgb, vec3(0.5, 0.5, 1.0), poca * 0.9);
	ROUGHNESS = mix(0.62, 0.08, poca);
	SPECULAR = 0.5;
	float b = abs(UV.x - 0.5) * 2.0;
	ALPHA = 1.0 - smoothstep(0.93, 1.0, b + (ru(wp.xz * 2.0) - 0.5) * 0.08);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
