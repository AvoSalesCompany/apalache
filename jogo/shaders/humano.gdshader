shader_type spatial;
// Passageiro: COLOR r=pele g=camisa b=calca, preto=cabelo/sapato
uniform vec3 pele : source_color = vec3(0.62, 0.43, 0.34);
uniform vec3 camisa : source_color = vec3(0.2, 0.25, 0.32);
uniform vec3 calca : source_color = vec3(0.08, 0.09, 0.12);
uniform vec3 cabelo : source_color = vec3(0.04, 0.028, 0.02);
varying vec3 op;
float h2(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
void vertex() { op = VERTEX; }
void fragment() {
	float s = max(0.001, COLOR.r + COLOR.g + COLOR.b);
	vec3 c = (pele * COLOR.r + camisa * COLOR.g + calca * COLOR.b) / s;
	c = mix(cabelo, c, smoothstep(0.25, 0.7, s));
	float tec = h2(floor(op.xy * 420.0)) * 0.12 + 0.94;
	ALBEDO = c * tec;
	ROUGHNESS = mix(0.9, 0.55, COLOR.r);
	SPECULAR = 0.3;
}
