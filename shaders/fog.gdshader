// low drifting fog over the moor, fixed to the world (the camera offset is fed in), darker at the screen's edges
shader_type canvas_item;
uniform vec2 cam = vec2(0.0);
uniform float density = 0.2;
uniform vec4 tint : source_color = vec4(0.3, 0.31, 0.33, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { v += a * vn(p); p = p * 2.02 + 3.1; a *= 0.5; } return v; }
void fragment() {
	vec2 sz = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 w = (SCREEN_UV - 0.5) * sz + cam;
	float t = TIME * 0.02;
	float f = fbm(w * vec2(0.0022, 0.0044) + vec2(t, t * 0.3));
	f = smoothstep(0.35, 0.85, f + fbm(w * 0.006 - vec2(t * 1.7, 0.0)) * 0.35);
	vec2 q = SCREEN_UV - 0.5;
	float vig = smoothstep(0.35, 0.85, length(q * vec2(1.0, 1.25)));
	vec4 fog = vec4(tint.rgb, f * density);
	vec4 dark = vec4(0.0, 0.0, 0.0, vig * 0.72);
	COLOR = vec4(mix(fog.rgb, dark.rgb, dark.a / max(0.001, dark.a + fog.a)), 1.0 - (1.0 - fog.a) * (1.0 - dark.a));
}
