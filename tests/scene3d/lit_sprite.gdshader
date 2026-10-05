// A painted sprite standing in the 3D test: a camera-facing card (so the art is never foreshortened), cut by its alpha,
// lit by the real lights with the same stepped, dithered falloff as the ground. `wrap` lets light reach a figure's face
// even though the card faces the camera; its own shadow proxy darkens the side away from the lamp.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, depth_prepass_alpha, world_vertex_coords;

uniform sampler2D tex : filter_nearest, source_color;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);   // uv rect of the frame in the sheet
uniform float flip = 0.0;
uniform float cell = 4.0;
uniform float bands = 7.0;
uniform float wrap = 0.55;
uniform vec3 emit = vec3(0.0);

const float BAY[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	// stand upright and turn to face the camera about the vertical only (so a card never leans into what stands behind
	// it), and stretch by 1/cos 30 so the art shows at exactly its painted size under the 30-degree camera
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 local = VERTEX - o;
	vec3 r = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	VERTEX = o + r * local.x + vec3(0.0, 1.0, 0.0) * local.y * 1.1547;
	NORMAL = normalize(vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z));
}

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) uv.x = 1.0 - uv.x;
	vec4 c = texture(tex, region.xy + uv * region.zw);
	if (c.a < 0.5) discard;
	ALBEDO = c.rgb;
	EMISSION = emit * c.rgb;
}

void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	float e = ATTENUATION * (wrap + (1.0 - wrap) * ndl);
	ivec2 cc = ivec2(floor(FRAGCOORD.xy / cell));
	float th = (BAY[(cc.y & 3) * 4 + (cc.x & 3)] + 0.5) / 16.0;
	float q = floor(e * bands + 0.5 + (th - 0.5) * 0.6) / bands;   // the dither only softens each step's edge
	DIFFUSE_LIGHT += LIGHT_COLOR * q;
}
