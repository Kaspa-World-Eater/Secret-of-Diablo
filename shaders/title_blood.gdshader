shader_type canvas_item;
// The title's Seer's bowl (zp_title.js ttDrawBlood): the blood's surface, painted per chapel pixel. It sways a little,
// every drop from the god's chin sends out a ring that bends it, and in it, broken by the rings, the reflection of
// whoever looks down: a hooded figure with two points of light for eyes. The candles behind stand in it as streaks.
// The rect covers the surface's bounding box (152 x 66 chapel px); UV maps to chapel pixels.

uniform sampler2D refl : filter_nearest;   // ttBuildRefl's mask (220 x 110): value / 40 = 0 none, 1 hood, 2 face, 3 eye, 5 edge
uniform vec4 rings[8];                      // x, y, r, t (t < 0: unused)
uniform float time = 0.0;
uniform vec3 pal[9];

const float SX = 340.0;
const float SY = 202.0;
const float SRX = 75.0;
const float SRY = 32.0;
const float RS = 1.35;

float b4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = y * 4 + x;
	float v[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return v[i] / 16.0 - 0.47;
}

void fragment() {
	vec2 P = floor(UV * vec2(152.0, 66.0)) + vec2(SX - SRX - 1.0, SY - SRY - 1.0);
	float X = P.x;
	float Y = P.y;
	float u = (X - SX) / SRX;
	float v = (Y - SY) / SRY;
	float rr = u * u + v * v;
	if (rr > 1.0) {
		COLOR = vec4(0.0);
	} else {
		float crest = 0.0;
		float bend = 0.0;
		for (int k = 0; k < 8; k++) {
			vec4 r = rings[k];
			if (r.w < 0.0) { continue; }
			float d = length(vec2(X - r.x, (Y - r.y) * 2.2));
			float f = max(0.0, 1.0 - r.w / 3.4);
			float q = d - r.z;
			if (abs(q) < 5.0) {
				bend += sin(q * 1.4) * 2.2 * f;
				if (abs(q) < 0.9) { crest += f; }
				else if (q > 0.9 && q < 2.0) { crest -= f * 0.5; }
			}
		}
		float sx = X + sin(Y * 0.31 + time * 1.1) * 0.9 + bend;
		float sy = Y + sin(X * 0.07 + time * 0.7) * 0.6 + bend * 0.5;
		float L = 3.6 - rr * 2.2;
		vec2 rs = vec2(220.0, 110.0);
		float ri = floor((sx - SX) * RS + rs.x / 2.0 + 0.5);
		float rj = floor((sy - SY) * RS + rs.y * 0.6 + 0.5);
		float m = 0.0;
		if (ri >= 0.0 && rj >= 0.0 && ri < rs.x && rj < rs.y) {
			m = floor(texture(refl, (vec2(ri, rj) + 0.5) / rs).r * 255.0 / 40.0 + 0.5);
		}
		if (m == 1.0) { L -= 2.4; }
		else if (m == 5.0) { L -= 0.4; }
		else if (m == 2.0) { L -= 1.4; }
		else if (m == 4.0) { L -= 0.4; }
		else if (m == 3.0) { L = 7.4 + sin(time * 2.0) * 0.4; }
		// the candle clusters behind the bowl, mirrored in it
		for (int c = 0; c < 2; c++) {
			float mx = SX - ((c == 0 ? 236.0 : 452.0) - SX) * 0.42;
			float my = SY - 17.0;
			float dx = abs(sx - mx);
			float dy = abs(sy - my);
			if (dx < 0.8 && dy < 3.5) { L = max(L, 8.0 - dy * 0.5); }
			else if (dx < 5.0 && dy < 7.0 && m != 1.0) { L += (5.0 - dx) * 0.1; }
		}
		L += crest * 2.2 + b4(P) * 0.9;
		if (rr > 0.88) { L = min(L, 1.0 + (1.0 - rr) * 8.0); }
		int li = clamp(int(floor(L)), 0, 8);
		COLOR = vec4(pal[li], 1.0);
	}
}
