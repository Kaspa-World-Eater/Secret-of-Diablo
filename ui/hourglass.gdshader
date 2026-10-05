shader_type canvas_item;
// The Empty Hand's orb is an hourglass (zz_monk_sand.js hgOld): two sands in one glass, held in a small bone frame.
// Amber sand (Radiance) heaps in the lower bulb; black sand (Absence) hangs in the upper one, falling the wrong way.
// While he casts a stream runs through the neck (amber down, black up); as the sand runs back grains lift off it.
// Flat stepped values, one texel per art pixel, a slow ring of stars in the dark glass, a hard window glint.
uniform float fR = 0.0;      // the lower bulb, 0..1
uniform float fA = 0.0;      // the upper bulb, 0..1
uniform float t = 0.0;
uniform float N = 152.0;
uniform int pour = -1;       // 0 amber falling, 1 black rising, -1 none
uniform bool run = false;

const vec3 AMB[6] = vec3[6](vec3(0.227, 0.110, 0.024), vec3(0.416, 0.212, 0.063), vec3(0.612, 0.353, 0.102), vec3(0.800, 0.525, 0.173), vec3(0.941, 0.706, 0.282), vec3(1.0, 0.878, 0.541));
const vec3 INK[6] = vec3[6](vec3(0.016, 0.008, 0.031), vec3(0.055, 0.039, 0.094), vec3(0.102, 0.075, 0.188), vec3(0.165, 0.125, 0.282), vec3(0.329, 0.251, 0.541), vec3(0.659, 0.565, 0.878));
const vec3 BG[4] = vec3[4](vec3(0.020, 0.016, 0.031), vec3(0.035, 0.031, 0.051), vec3(0.055, 0.051, 0.078), vec3(0.082, 0.075, 0.110));
const vec3 GLS[4] = vec3[4](vec3(0.110, 0.125, 0.149), vec3(0.243, 0.267, 0.314), vec3(0.478, 0.510, 0.565), vec3(0.847, 0.847, 0.878));
const vec3 BONE[6] = vec3[6](vec3(0.055, 0.047, 0.039), vec3(0.173, 0.149, 0.125), vec3(0.353, 0.314, 0.267), vec3(0.557, 0.510, 0.447), vec3(0.761, 0.722, 0.643), vec3(0.925, 0.894, 0.816));
const float NECK = 0.06;
const float V0 = 0.09;
const float V1 = 0.72;
const float MAXW = 0.42;

float hash2(vec2 p) { float s = sin(p.x * 127.1 + p.y * 311.7) * 43758.5453; return fract(s); }

// the bulb's half-width at height |v| (the neck at 0)
float bw(float av) {
	if (av < V0) return NECK;
	if (av > V1) return -1.0;
	float q = (av - (V0 + V1) / 2.0) / ((V1 - V0) / 2.0) * 0.96 - 0.1;
	return NECK + (MAXW - NECK) * sqrt(max(0.0, 1.0 - q * q));
}
// the height the sand reaches for a fraction of the bulb's volume (integrated from the wide bottom up)
float lvl(float f) {
	float tot = 0.0;
	for (int i = 0; i < 60; i++) { tot += max(0.0, bw(V1 - (V1 - V0) * (float(i) + 0.5) / 60.0)); }
	float want = f * tot;
	float acc = 0.0;
	for (int i = 0; i < 60; i++) {
		acc += max(0.0, bw(V1 - (V1 - V0) * (float(i) + 0.5) / 60.0));
		if (acc >= want) { return V1 - (V1 - V0) * (float(i) + 1.0) / 60.0; }
	}
	return V0;
}

void fragment() {
	vec2 ij = floor(UV * N);
	float u = (ij.x + 0.5) / N * 2.0 - 1.0;
	float v = (ij.y + 0.5) / N * 2.0 - 1.0;
	float rr = u * u + v * v;
	if (rr > 1.0) { COLOR = vec4(0.0); }
	else {
		float au = abs(u);
		float av = abs(v);
		float g = hash2(floor(ij / 2.0));
		float g1 = hash2(ij);
		vec3 c = BG[rr > 0.86 ? 0 : (rr > 0.55 ? 1 : 2)];
		float ang = atan(v, u) + t * 0.05;
		float rad = sqrt(rr);
		if (rad > 0.74 && rad < 0.9 && hash2(vec2(floor(ang * 40.0), 7.0)) > 0.86 && abs(rad - 0.82) < 0.012) c = BG[3];
		float w = bw(av);
		float lvR = fR > 0.004 ? lvl(fR) : 9.0;
		float lvA = fA > 0.004 ? lvl(fA) : 9.0;
		float px = 2.0 / N;
		if (av > 0.72 && av < 0.84 && au < 0.56) {
			// the frame's two bone plates
			int e = (av > 0.82 || au > 0.54) ? 1 : (av < 0.735 ? (v < 0.0 ? 2 : 4) : 3);
			c = BONE[(u < -0.3 && e >= 3) ? e + 1 : e];
			if (abs(au - 0.28) < 0.02 && av > 0.745 && av < 0.8) c = BONE[1];
		} else if (au > 0.47 && au < 0.53 && av <= 0.72) {
			// the two turned pillars
			bool turn = sin(av * 34.0) > 0.5;
			c = BONE[au < 0.49 ? (u < 0.0 ? 4 : 2) : (au > 0.515 ? 1 : (turn ? 3 : 2))];
		} else if (w > 0.0 && au < w) {
			bool top = v < 0.0;
			int sand = -1;
			float mR = 0.05 * fR * (1.0 - pow(min(1.0, au / MAXW), 2.0));
			float mA = 0.05 * fA * (1.0 - pow(min(1.0, au / MAXW), 2.0));
			if (!top && lvR < 9.0 && v > lvR - mR) sand = 0;
			if (top && lvA < 9.0 && -v > lvA - mA) sand = 1;
			if (sand == 0) {
				int k = 3 - (au > w - 0.05 ? 1 : 0) + (g > 0.9 ? 1 : 0) - (g < 0.08 ? 1 : 0);
				if (v > 0.55) k -= 1;
				if (v < lvR - mR + 0.03) k = 4;
				if (run && g1 > 0.992) k = 5;
				c = AMB[clamp(k, 0, 5)];
			} else if (sand == 1) {
				int k = 2 + (g > 0.9 ? 1 : 0) - (g < 0.06 ? 1 : 0) + (au > w - 0.05 ? -1 : 0);
				if (v < -0.55) k -= 1;
				float edge = -v - (lvA - mA);
				if (edge < 0.035) k = 4;
				if (edge < 0.012) k = 5;
				if (g1 > 0.994) k = 5;
				c = INK[clamp(k, 0, 5)];
			} else {
				c = GLS[0];
				if (au > w - px * 1.5) c = GLS[1];
				if (u < 0.0 && au > w - 0.1 && au < w - 0.05 && av > 0.2 && av < 0.6) c = GLS[2];
			}
			// the streams through the neck
			if (au < 0.018) {
				float fl = mod(ij.y + floor(t * 60.0), 3.0);
				if (pour == 0 && v > -0.02 && v < lvR) c = fl > 0.5 ? AMB[4] : AMB[5];
				if (pour == 1 && v < 0.02 && -v < lvA) c = fl > 0.5 ? INK[3] : INK[5];
			}
			if (au > w - px * 0.9) c = GLS[1];
		}
		float k = rr > 0.9 ? 0.7 : 1.0;
		c *= k;
		if ((u + 0.52) * (u + 0.52) + (v + 0.5) * (v + 0.5) < 0.004) c = vec3(0.98, 0.965, 0.91);
		COLOR = vec4(c, 1.0);
	}
}
