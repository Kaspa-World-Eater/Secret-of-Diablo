// a life or mana orb: dark liquid that slowly turns, a meniscus, dim glass above it
shader_type canvas_item;
uniform vec4 liquid : source_color = vec4(0.45, 0.05, 0.05, 1.0);
uniform float level = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) discard;
	float surface = 1.0 - level * 2.0 + sin(p.x * 5.0 + TIME * 1.6) * 0.025;
	vec3 glass = vec3(0.03, 0.03, 0.035);
	float n = vn(p * 3.0 + vec2(TIME * 0.15, -TIME * 0.1)) * 0.6 + vn(p * 7.0 - TIME * 0.2) * 0.4;
	vec3 liq = liquid.rgb * (0.55 + n * 0.7) * (1.0 - r * 0.45);
	vec3 col = p.y > surface ? liq : glass;
	col += vec3(0.25) * smoothstep(0.035, 0.0, abs(p.y - surface)) * step(surface, 1.0) * 0.4;
	// a curved highlight on the glass, faint
	col += vec3(0.5) * smoothstep(0.25, 0.0, length(p - vec2(-0.35, -0.45))) * 0.12;
	col *= smoothstep(1.0, 0.86, r) * 0.6 + 0.4;
	COLOR = vec4(col, 1.0);
}
