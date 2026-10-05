shader_type canvas_item;
// A figure's shadow, dithered at the world's grain into two steps of the world's shadow colour (y_light21.js:298-303,
// zz_zz_shadow70.js:103-109). For silhouettes (sil = true) the strength is al x the frame's alpha, fading toward the
// tip; for wedges it comes in the vertex colour.
uniform bool sil = true;
uniform float al = 0.4;
uniform float levels = 2.6;          // the strength is cut at v x levels into 0, 1, 2
uniform vec2 steps = vec2(0.412, 0.706);   // the alpha of step 1 and step 2 (105, 180 of 255)
uniform float uv_feet = 1.0;         // the feet and the head, in the atlas's v
uniform float uv_head = 0.0;
uniform float th_off = 0.0;          // the step test: (fract - th_off) x th_mul against the Bayer cell
uniform float th_mul = 1.0;
const float B[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

void fragment() {
	float v;
	if (sil) {
		float a = texture(TEXTURE, UV).a;
		float t = clamp((uv_feet - UV.y) / max(0.0001, uv_feet - uv_head), 0.0, 1.0);
		v = al * a * (1.0 - 0.85 * pow(t, 1.4));
	} else {
		v = COLOR.a;
	}
	v *= levels;
	ivec2 c = ivec2(floor(FRAGCOORD.xy / 4.0)) & ivec2(3);
	float b = (B[c.y * 4 + c.x] + 0.5) / 16.0;
	float lv = min(2.0, floor(v) + ((fract(v) - th_off) * th_mul > b ? 1.0 : 0.0));
	float o = lv < 0.5 ? 0.0 : (lv < 1.5 ? steps.x : steps.y);
	COLOR = vec4(8.0 / 255.0, 6.0 / 255.0, 14.0 / 255.0, o);
}
