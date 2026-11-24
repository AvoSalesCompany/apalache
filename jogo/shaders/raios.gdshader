shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, ambient_light_disabled;
// Raios de lua em espaco de tela: a luz "vaza" pelos buracos da copa.
uniform sampler2D prof : hint_depth_texture, filter_nearest;
uniform vec3 lua = vec3(0.6, 0.5, 0.6);
uniform vec3 cor : source_color = vec3(0.62, 0.74, 1.0);
uniform float forca = 0.36;

void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }

void fragment() {
	vec3 v = (VIEW_MATRIX * vec4(normalize(lua), 0.0)).xyz;
	float frente = smoothstep(0.10, 0.62, -v.z);
	vec3 res = vec3(0.0);
	if (frente > 0.0) {
		vec4 c = PROJECTION_MATRIX * vec4(v * 100.0, 1.0);
		vec2 m = c.xy / c.w * 0.5 + 0.5;
		vec2 uv = SCREEN_UV;
		float asp = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
		vec2 dl = (m - uv);
		float len = length(dl * vec2(asp, 1.0));
		dl *= min(1.0, 0.85 / max(len, 0.001));
		float j = fract(52.9829189 * fract(dot(FRAGCOORD.xy + mod(TIME * 60.0, 64.0) * 5.588, vec2(0.06711056, 0.00583715))));
		const int N = 40;
		float ac = 0.0, dec = 1.0;
		for (int i = 0; i < N; i++) {
			vec2 p = uv + dl * (float(i) + j) / float(N);
			if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) break;
			float ceu = step(texture(prof, p).r, 0.00002);
			float dist = length((p - m) * vec2(asp, 1.0));
			ac += ceu * dec * (0.22 * exp(-dist * 2.4) + 1.1 * exp(-dist * 8.5));
			dec *= 0.985;
		}
		ac /= float(N);
		res = cor * ac * forca * frente;
	}
	ALBEDO = res;
}
