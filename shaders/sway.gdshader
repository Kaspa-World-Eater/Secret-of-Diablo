// Things that answer the wind (zz_atmos62.js "one shared gust"): young trees and saplings, cloth, cobwebs, chains.
// The top of the sprite leans; the foot stays put. Each thing sways on its own beat (its place in the world).
shader_type canvas_item;
uniform float wind = 0.5;
uniform float amp = 6.0;          // screen px at the top, in a full gust
uniform float speed = 1.3;

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float ph = wp.x * 0.013 + wp.y * 0.021;
	float s = sin(TIME * speed + ph) * 0.6 + sin(TIME * speed * 2.3 + ph * 1.7) * 0.25;
	float lean = (1.0 - UV.y) * (1.0 - UV.y);
	VERTEX.x += lean * amp * (0.25 + wind) * s + lean * amp * 0.35 * wind;
}
