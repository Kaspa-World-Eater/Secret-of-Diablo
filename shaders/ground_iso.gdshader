// The zone's ground, painted as the web build paints it (zz_ground55.js): every cell has a ground class; each class has
// a seamless 320x160 texture anchored to the world at 2 texels per world px; grass mixes two variants by a slow noise;
// borders between outdoor classes are frayed by warping the lookup; the feet of walls and cliffs darken.
shader_type canvas_item;

uniform sampler2DArray gtex : filter_nearest;
uniform sampler2D cls : filter_nearest;
uniform int layer_a[16];
uniform int layer_b[16];
uniform vec2 grid_size = vec2(64.0, 64.0);
uniform float gain = 1.0;
uniform int wet[16];               // 1: standing water (it moves: a slow swell in the texture, and now and then a cold glint)
uniform float wind = 0.5;

varying vec2 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

int cls_at(vec2 t) {
	ivec2 c = ivec2(floor(t));
	if (c.x < 0 || c.y < 0 || c.x >= int(grid_size.x) || c.y >= int(grid_size.y)) return 0;
	return int(texelFetch(cls, c, 0).r * 255.0 + 0.5);
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }

void fragment() {
	vec2 W = wpos / 4.0;                                   // web world px
	vec2 t = vec2((W.x / 18.0 + W.y / 9.0) * 0.5, (W.y / 9.0 - W.x / 18.0) * 0.5);
	int c = cls_at(t);
	if (c >= 1 && c <= 10) {
		vec2 warp = vec2(vn(t * 2.7), vn(t * 2.7 + 17.3)) - 0.5;
		int c2 = cls_at(t + warp * 0.62);
		if (c2 >= 1 && c2 <= 10) c = c2;
	}
	if (c == 0) {
		COLOR = vec4(0.015, 0.015, 0.02, 1.0);
	} else {
		float dith = hash(floor(W)) * 0.12 - 0.06;
		bool v2 = vn(vec2(W.x / 70.0, W.y / 35.0)) + dith > 0.5;
		int L = v2 ? layer_b[c] : layer_a[c];
		vec2 wl = W * 2.0;
		bool water = wet[c] == 1;
		if (water) {
			// the swell: rows slide a little against each other, slowly, harder in the gust
			float sw = sin(TIME * 0.9 + W.y * 0.21 + W.x * 0.05) + 0.6 * sin(TIME * 1.7 - W.y * 0.37);
			wl.x += floor(sw * (1.2 + wind * 1.4));
		}
		ivec2 tx = ivec2(mod(floor(wl), vec2(320.0, 160.0)));
		vec4 col = texelFetch(gtex, ivec3(tx, L), 0);
		if (water) {
			// a cold glint where the surface catches the sky, a pixel at a time (never a glow)
			float g = vn(floor(W) * 0.35 + vec2(TIME * 0.35, -TIME * 0.2));
			float g2 = hash(floor(W) + floor(TIME * 3.0));
			if (g > 0.78 && g2 > 0.93) col.rgb = mix(col.rgb, vec3(0.62, 0.72, 0.78), 0.45);
			col.rgb *= 0.94 + 0.06 * sin(TIME * 1.3 + W.x * 0.08 + W.y * 0.13);
		}
		// the feet of walls and cliffs: darken toward any void neighbour
		vec2 f = fract(t);
		float dv = 0.0;
		if (cls_at(t + vec2(-1.0, 0.0)) == 0) dv = max(dv, 1.0 - f.x);
		if (cls_at(t + vec2(1.0, 0.0)) == 0) dv = max(dv, f.x);
		if (cls_at(t + vec2(0.0, -1.0)) == 0) dv = max(dv, 1.0 - f.y);
		if (cls_at(t + vec2(0.0, 1.0)) == 0) dv = max(dv, f.y);
		dv = smoothstep(0.45, 1.0, dv);
		col.rgb *= gain * (1.0 - dv * 0.55);
		COLOR = vec4(col.rgb, 1.0);
	}
}
