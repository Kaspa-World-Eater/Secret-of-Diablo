// The ground of the 3D test: the painted ground texture laid exactly as the 2D game lays it (sampled in iso screen space,
// one texel per screen pixel), lit by real lights whose falloff is cut into stepped, dithered bands per art pixel, the
// way the browser's light map was (quantLight37): light, not an overlay.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D ground_tex : filter_nearest, repeat_enable;
uniform float ppm = 101.82;          // screen px per metre (a tile is 144 x 72 px)
uniform float cell = 4.0;            // one art pixel, in screen px
uniform float bands = 7.0;

varying vec3 wpos;

const float BAY[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// world x/z (metres, tiles) to the 2D game's iso screen px: ((x - y) * 72, (x + y) * 36)
	vec2 t = vec2(wpos.x, wpos.z);
	vec2 s = vec2((t.x - t.y) * 72.0, (t.x + t.y) * 36.0);
	ALBEDO = texture(ground_tex, s / vec2(textureSize(ground_tex, 0))).rgb;
}

void light() {
	float e = ATTENUATION * max(dot(NORMAL, LIGHT), 0.0);
	ivec2 c = ivec2(floor(FRAGCOORD.xy / cell));
	float th = (BAY[(c.y & 3) * 4 + (c.x & 3)] + 0.5) / 16.0;
	float q = floor(e * bands + 0.5 + (th - 0.5) * 0.6) / bands;   // the dither only softens each step's edge
	DIFFUSE_LIGHT += LIGHT_COLOR * q;
}
