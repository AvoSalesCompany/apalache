shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;
// Riacho de montanha: correnteza, espuma e reflexo da lua.
uniform sampler2D prof : hint_depth_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap, repeat_disable;

float h2(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
float ru(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float onda(vec2 p) {
	float t = TIME;
	return ru(p * vec2(2.2, 1.0) - vec2(0.0, t * 1.7)) * 0.5 + ru(p * vec2(5.0, 2.6) - vec2(t * 0.25, t * 2.4)) * 0.32 + ru(p * vec2(11.0, 6.0) - vec2(-t * 0.3, t * 3.4)) * 0.18;
}

void fragment() {
	vec2 u = UV;
	float e = 0.05;
	float o = onda(u);
	float ox = onda(u + vec2(e, 0.0)) - o;
	float oz = onda(u + vec2(0.0, e)) - o;
	vec3 n = normalize(NORMAL + (TANGENT * -ox + BINORMAL * oz) * 2.2);
	NORMAL = n;
	float d = texture(prof, SCREEN_UV).r;
	vec4 q = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float fundo = max(0.0, VERTEX.z - q.z / q.w);
	vec2 ruv = SCREEN_UV + n.xy * 0.018 * min(1.0, fundo * 3.0);
	ruv = clamp(ruv, vec2(0.002), vec2(0.985));
	vec3 atras = texture(tela, ruv).rgb;
	float op = 1.0 - exp(-fundo * 2.6);
	float esp = smoothstep(0.60, 0.80, o + (1.0 - smoothstep(0.0, 0.16, fundo)) * 0.30);
	ALBEDO = mix(vec3(0.008, 0.014, 0.014), vec3(0.42, 0.48, 0.52), esp * 0.55);
	EMISSION = atras * vec3(0.80, 0.90, 0.88) * (1.0 - op) * (1.0 - esp * 0.5);
	ROUGHNESS = mix(0.07, 0.5, esp);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	ALPHA = smoothstep(0.0, 0.03, fundo);
}
