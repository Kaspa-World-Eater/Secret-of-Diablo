shader_type canvas_item;
// The glass of an orb (zz_hud54.js glass()): the liquid in six flat steps, a slow swirl in small clusters, a meniscus,
// rising bubbles, the dark empty glass and a hard window highlight. No gradients, no glow. N = texels across.
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float t = 0.0;
uniform float N = 152.0;
uniform vec4 c0 : source_color; uniform vec4 c1 : source_color; uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color; uniform vec4 c4 : source_color; uniform vec4 c5 : source_color;
uniform vec4 men : source_color;
uniform bool pearl = false;
uniform float dim = 0.0;

float hash2(vec2 p) { float s = sin(p.x * 127.1 + p.y * 311.7) * 43758.5453; return fract(s); }
vec3 liq(int i) {
	if (i <= 0) return c0.rgb; if (i == 1) return c1.rgb; if (i == 2) return c2.rgb;
	if (i == 3) return c3.rgb; if (i == 4) return c4.rgb; return c5.rgb;
}
void fragment() {
	vec2 ij = floor(UV * N);
	float u = (ij.x + 0.5) / N * 2.0 - 1.0, v = (ij.y + 0.5) / N * 2.0 - 1.0, rr = u * u + v * v;
	if (rr > 1.0) { COLOR = vec4(0.0); }
	else {
		vec2 cl = floor(ij / 2.0);
		float lvl = 1.0 - 2.0 * clamp(fill, 0.0, 1.0);
		float wave = 0.018 * sin(u * 7.0 + t * 2.3) + 0.01 * sin(u * 13.0 - t * 1.7);
		vec3 c;
		if (v >= lvl + wave && fill > 0.001) {
			int idx = 3;
			if (rr > 0.86) idx -= 2; else if (rr > 0.62) idx -= 1;
			float sw = sin(u * 5.2 + v * 3.1 + t * 0.7) + sin(u * -3.3 + v * 6.7 - t * 0.9) + (hash2(cl) - 0.5) * 0.9;
			if (sw > 1.35) idx += 1; else if (sw < -1.5) idx -= 1;
			if (u < -0.15 && v < 0.2 && rr < 0.62 && rr > 0.18) idx += 1;
			if (v < lvl + wave + 0.035) c = men.rgb;
			else {
				c = liq(clamp(idx, 0, 5));
				if (pearl && hash2(cl + vec2(floor(t * 2.0), 0.0)) > 0.965) {
					float k = mod(cl.x + cl.y, 3.0);
					c = k < 0.5 ? vec3(0.902, 0.859, 0.914) : (k < 1.5 ? vec3(0.835, 0.906, 0.894) : vec3(0.937, 0.890, 0.824));
				}
			}
			float bx = floor((u + 1.0) * 6.0);
			float bph = fract(t * (0.25 + mod(bx, 5.0) * 0.06) + bx * 0.37);
			float by = 1.0 - bph * (1.0 - lvl);
			if (mod(bx, 3.0) < 0.5 && abs(v - by) < 0.025 && abs(u - (bx / 6.0 - 1.0 + 0.08)) < 0.025) c = men.rgb;
		} else {
			int ei = 2; if (rr > 0.8) ei = 1; if (rr > 0.93) ei = 0;
			if (u > 0.25 && u < 0.4 && v < lvl - 0.1) ei = 3;
			vec3 EMP[4] = vec3[](vec3(0.016, 0.012, 0.024), vec3(0.031, 0.027, 0.043), vec3(0.051, 0.047, 0.067), vec3(0.075, 0.071, 0.094));
			c = EMP[ei];
		}
		float ang = atan(v, u);
		if (rr > 0.5 && rr < 0.66 && ang < -1.9 && ang > -2.75) c = c * 0.45 + vec3(140.0, 138.0, 132.0) / 255.0;
		if ((u + 0.36) * (u + 0.36) + (v + 0.44) * (v + 0.44) < 0.006) c = vec3(0.98, 0.965, 0.91);
		c = mix(c, c * 0.45, dim);
		COLOR = vec4(c, 1.0);
	}
}
