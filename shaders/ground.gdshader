// The Ashen Moor's ground: two painted variants of the moor mixed by a slow world noise with a dithered edge,
// patches of bare dirt, and the Pilgrim Road winding through. All textures repeat in world space.
shader_type canvas_item;

uniform sampler2D main_b : repeat_enable, filter_nearest;
uniform sampler2D dirt : repeat_enable, filter_nearest;
uniform sampler2D road : repeat_enable, filter_nearest;
uniform float road_y = 0.0;      // world y of the road's centre line at x = 0
uniform float road_w = 70.0;     // half width in world units
uniform vec2 camp = vec2(0.0);   // the camp clearing
uniform float camp_r = 260.0;

varying vec2 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; } return v; }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }

void fragment() {
	vec2 uv = UV;
	vec4 a = texture(TEXTURE, uv);
	vec4 b = texture(main_b, uv * 1.0 + vec2(0.37, 0.11));
	float dith = hash(floor(wpos * 0.5)) * 0.12 - 0.06;
	float n = fbm(wpos * 0.0035) + dith;
	vec4 col = mix(a, b, step(0.52, n));
	// bare dirt where the moor has been worn through
	float d = fbm(wpos * 0.006 + 13.1) + dith;
	float dm = step(0.66, d);
	// the camp clearing is trodden bare
	float cd = length((wpos - camp) * vec2(1.0, 2.0));
	dm = max(dm, step(cd + fbm(wpos * 0.02) * 90.0, camp_r));
	col = mix(col, texture(dirt, uv * 1.0 + vec2(0.21, 0.63)), dm);
	// the Pilgrim Road: a winding line, ragged at its edges
	float ry = road_y + sin(wpos.x * 0.0021) * 160.0 + sin(wpos.x * 0.0057 + 1.3) * 50.0;
	float rd = abs(wpos.y - ry) + (fbm(wpos * 0.03) - 0.5) * 44.0;
	col = mix(col, texture(road, uv), step(rd, road_w));
	// a slow darkening in the hollows
	col.rgb *= 0.78 + 0.3 * fbm(wpos * 0.0012 + 4.0);
	COLOR = col;
}
