shader_type canvas_item;
// The light map (y_light21.js L37), one texel per art pixel (a 4 px cell on screen), read by shaders/dark.gdshader.
// The land's ambient at half strength; the flames and the lantern laid over it (lighten keeps the hottest where pools
// meet; small lights add); then the excess over the ambient cut into bands of 12 with a Bayer step between, capped at 160.
uniform vec3 amb = vec3(1.0);
uniform int n_lights = 0;
uniform vec4 lA[48];     // x, y (texels), r (texels), A (alpha x LK)
uniform vec4 lB[48];     // rgb, mode: 0 add (addLightRaw), 1 lighten (lightenRaw), 2 lighten with FALL37, squashed (shadowLight)
uniform vec4 lC[48];     // y squash, the hole whose edges stop it (-1 none)
uniform int n_occ = 0;
uniform vec4 occ[128];   // edges (texels)
uniform float occ_h[128];
const float BAY[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
float cross2(vec2 a, vec2 b) { return a.x * b.y - a.y * b.x; }
bool crosses(vec2 L, vec2 P, vec2 A, vec2 B) {
	vec2 r = P - L;
	vec2 s = B - A;
	float den = cross2(r, s);
	if (abs(den) < 1e-5) return false;
	vec2 q = A - L;
	float t = cross2(q, s) / den;
	float u = cross2(q, r) / den;
	return t > 0.0 && t < 1.0 && u >= 0.0 && u <= 1.0;
}
float fall5(float t) {
	if (t < 0.2) return mix(1.0, 0.66, t / 0.2);
	if (t < 0.45) return mix(0.66, 0.32, (t - 0.2) / 0.25);
	if (t < 0.75) return mix(0.32, 0.1, (t - 0.45) / 0.3);
	return mix(0.1, 0.0, clamp((t - 0.75) / 0.25, 0.0, 1.0));
}
float fall37(float t) {
	if (t < 0.2) return mix(1.0, 0.9, t / 0.2);
	if (t < 0.45) return mix(0.9, 0.66, (t - 0.2) / 0.25);
	if (t < 0.7) return mix(0.66, 0.33, (t - 0.45) / 0.25);
	if (t < 0.88) return mix(0.33, 0.1, (t - 0.7) / 0.18);
	return mix(0.1, 0.0, clamp((t - 0.88) / 0.12, 0.0, 1.0));
}
void fragment() {
	vec2 p = floor(FRAGCOORD.xy) + 0.5;
	vec3 ambS = amb * 0.5;
	vec3 Lmax = ambS;
	vec3 Ladd = vec3(0.0);
	for (int i = 0; i < n_lights; i++) {
		vec4 a = lA[i];
		vec2 dv = p - a.xy;
		dv.y /= lC[i].x;
		float t = length(dv) / a.z;
		if (t >= 1.0) continue;
		int hi = int(lC[i].y);
		if (hi >= 0) {
			bool blocked = false;
			for (int k = 0; k < n_occ; k++) {
				if (int(occ_h[k]) != hi) continue;
				vec4 e = occ[k];
				if (crosses(a.xy, p, e.xy, e.zw)) { blocked = true; break; }
			}
			if (blocked) continue;
		}
		vec4 b = lB[i];
		if (b.w < 0.5) Ladd += b.rgb * a.w * fall5(t);
		else Lmax = max(Lmax, min(vec3(1.0), ambS + b.rgb * a.w * (b.w > 1.5 ? fall37(t) : fall5(t))));
	}
	vec3 L = min(vec3(1.0), Lmax + Ladd);
	float I = max(max(L.r, L.g), L.b) * 255.0;
	float Ai = max(max(ambS.r, ambS.g), ambS.b) * 255.0;
	if (I > Ai + 0.5) {
		ivec2 qc = ivec2(floor(FRAGCOORD.xy)) & ivec2(3);
		float bq = (BAY[qc.y * 4 + qc.x] + 0.5) / 16.0;
		float q = (I - Ai) / 12.0;
		float lv = floor(q) + ((fract(q) - 0.28) * 2.2 > bq ? 1.0 : 0.0);
		L *= min(Ai + lv * 12.0, 160.0) / I;
	}
	COLOR = vec4(L, 1.0);
}
