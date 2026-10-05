// The lantern glass's glow in the 3D test (the browser's glowSprite): stepped, dithered pixel rings, added as light.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec3 col = vec3(1.0);
uniform float cell = 4.0;
uniform float breath = 1.0;
const float BAY[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	// snap to art pixels in screen space, then rings
	float d = length(UV - 0.5) * 2.0;
	float gv = max(0.0, 1.0 - d);
	gv = gv * gv * 4.0;
	ivec2 c = ivec2(floor(FRAGCOORD.xy / cell));
	float th = BAY[(c.y & 3) * 4 + (c.x & 3)] / 16.0;
	float lv = floor(gv) + ((gv - floor(gv)) > th ? 1.0 : 0.0);
	ALBEDO = col * min(4.0, lv) * 0.12 * breath;
}
