shader_type canvas_item;
render_mode blend_add;
// heroRim37 (y_light21.js:240-268): the hero's silhouette lit along the edge that faces the light, two px deep, added.
uniform vec2 off = vec2(-2.0, -2.0);   // toward the light, in the atlas's px
uniform vec4 rim : source_color = vec4(1.0);
void fragment() {
	vec2 px = 1.0 / vec2(textureSize(TEXTURE, 0));
	float a = texture(TEXTURE, UV).a;
	float b = texture(TEXTURE, UV + off * px).a;
	COLOR = vec4(rim.rgb, a * (1.0 - b) * rim.a);
}
