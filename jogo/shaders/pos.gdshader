shader_type canvas_item;
// Pos-processamento: grao, vinheta, aberracao, medo, dano, desmaio.
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float grao = 0.045;
uniform float vinheta = 0.55;
uniform float medo = 0.0;
uniform float dano = 0.0;
uniform float tonto = 0.0;
uniform float frio = 0.0;
uniform float preto = 0.0;
uniform float branco = 0.0;
uniform float gama = 1.0;
uniform float pulso = 0.0;

float h(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	uv += vec2(sin(TIME * 1.3 + uv.y * 4.0), cos(TIME * 1.1 + uv.x * 4.0)) * tonto * 0.022;
	uv -= c * pulso * 0.012 * medo;
	float ab = 0.0007 + 0.0035 * medo * r2 * 2.0 + tonto * 0.006;
	vec3 col;
	float lod = tonto * 2.6;
	col.r = textureLod(tela, uv + c * ab * 2.0, lod).r;
	col.g = textureLod(tela, uv, lod).g;
	col.b = textureLod(tela, uv - c * ab * 2.0, lod).b;
	if (tonto > 0.01) {
		vec3 d = textureLod(tela, uv + vec2(0.018, 0.006) * tonto, lod).rgb;
		col = mix(col, max(col, d), 0.5 * tonto);
	}
	float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(col, vec3(l), 0.10 + medo * 0.38);
	col = mix(col, col * vec3(0.86, 0.96, 1.12), frio * 0.7);
	col = pow(max(col, vec3(0.0)), vec3(gama));
	float v = smoothstep(0.12, 0.92, length(c * vec2(1.0, 0.82)) * (1.0 + medo * 0.35));
	col *= 1.0 - v * (vinheta + medo * 0.35);
	// geada nas bordas
	float gd = smoothstep(0.32, 0.75, length(c)) * frio;
	col += vec3(0.5, 0.62, 0.75) * gd * 0.10 * (0.4 + 0.6 * h(floor(uv * vec2(420.0, 240.0))));
	// sangue nas bordas
	float sg = smoothstep(0.22, 0.75, length(c)) * dano;
	col = mix(col, vec3(0.16, 0.004, 0.004) * (0.4 + col), sg * 0.85);
	float g = h(FRAGCOORD.xy + fract(TIME * 7.13) * 911.0) - 0.5;
	col += g * grao * (0.35 + 0.65 * (1.0 - clamp(l * 2.0, 0.0, 1.0)));
	col = mix(col, vec3(1.0), branco);
	col *= 1.0 - preto;
	COLOR = vec4(col, 1.0);
}
