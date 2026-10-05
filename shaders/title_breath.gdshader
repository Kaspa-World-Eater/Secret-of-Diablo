shader_type canvas_item;
// The god's dying breath (zp_title.js ttDrawBreath): slow and heavy, it spills from the open mouth, runs down over the
// chin and pools across the altar, thinner where it lies over the blood. Three flat grey-violet tones on the chapel's
// pixel grid, dithered at their edges. The rect covers chapel px (210, 94) .. (470, 270): 260 x 176.

uniform float time = 0.0;

const float GX = 340.0;
const float MY0 = 107.0;     // the mouth (TT_GY + 38 * TT_FS)
const float HZ = 139.0;      // the altar's back edge
const float SX = 340.0;
const float SY = 202.0;
const float SRX = 75.0;
const float SRY = 32.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return a + (b - a) * s.x + (c - a) * s.y + (a - b - c + d) * s.x * s.y;
}
float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.03 + 7.1) * 0.3 + noise(p * 4.1 + 3.3) * 0.2;
}
float b4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float v[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return v[y * 4 + x] / 16.0 - 0.47;
}

void fragment() {
	vec2 P = floor(UV * vec2(260.0, 176.0)) + vec2(210.0, 94.0);
	float t = floor(time * 15.0) / 15.0;      // the breath is slow: 15 steps a second
	float X = P.x;
	float Y = P.y;
	float u = X - GX;
	float yy = Y - MY0;
	float br = 0.75 + 0.25 * sin(t * 0.55);
	float wd = 6.0 + max(0.0, yy) * 0.55;
	float core = exp(-pow(u / wd, 2.0)) * clamp(1.0 - yy / 150.0, 0.0, 1.0) * clamp((yy + 4.0) / 8.0, 0.0, 1.0);
	float inB = pow((X - SX) / SRX, 2.0) + pow((Y - SY) / SRY, 2.0) < 1.0 ? 0.2 : 1.0;
	float pool = Y > HZ ? inB * 0.5 * exp(-pow((Y - 176.0) / 34.0, 2.0)) * exp(-pow(u / 125.0, 2.0)) : 0.0;
	float d = max(core * br * (inB < 1.0 ? 0.55 : 1.0), pool * (0.8 + 0.2 * br));
	d *= fbm(vec2(X * 0.05 + sin(t * 0.15) * 0.6, (Y - t * 9.0) * 0.06 + u * u * 0.0004)) * 2.1 - 0.35;
	float q = d + b4(P) * 0.18;
	if (q > 0.62) { COLOR = vec4(100.0, 88.0, 116.0, 0.34 * 255.0) / 255.0; }
	else if (q > 0.4) { COLOR = vec4(72.0, 60.0, 84.0, 0.26 * 255.0) / 255.0; }
	else if (q > 0.22) { COLOR = vec4(50.0, 42.0, 60.0, 0.18 * 255.0) / 255.0; }
	else { COLOR = vec4(0.0); }
}
