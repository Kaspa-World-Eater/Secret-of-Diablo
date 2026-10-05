shader_type canvas_item;
// The grimdark grade for the free LPC art (Godmarrow's law: muddy, desaturated, one bold mass per figure):
// pull the colour toward its own grey, then tint by the land.
uniform float desat = 0.4;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(g), desat) * tint.rgb;
	COLOR = c;
}
