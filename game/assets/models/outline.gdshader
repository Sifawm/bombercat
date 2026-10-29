shader_type spatial;
// Ink outline drawn as a second pass behind every model: its back faces, pushed out in screen
// space along the smoothed normal the importer keeps in TANGENT, so the line has the same
// thickness however far the camera is. They are also pushed away from the camera, so the line
// only shows where a model stands out from what is behind it, not around stickers and tape.
render_mode unshaded, cull_front;

uniform vec4 color : source_color = vec4(0.165, 0.106, 0.239, 1.0);
// Thickness as a fraction of the picture's height, and never thinner than this many pixels, for
// the small pictures of a single Cat.
uniform float width = 0.0016;
uniform float min_pixels = 1.5;
// Metres the outline sits behind the model.
uniform float depth = 0.15;

void vertex() {
	vec4 seen = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// The sun's shadow map is drawn with an orthographic projection; pushed out there, the outline
	// would shade the whole model. ponytail: an orthographic game camera would lose its outlines.
	bool for_camera = PROJECTION_MATRIX[3][3] != 1.0;
	if (for_camera) {
		seen.xyz += normalize(seen.xyz) * depth;
	}
	vec4 clip = PROJECTION_MATRIX * seen;
	if (for_camera) {
		vec2 normal = (PROJECTION_MATRIX * vec4(MODELVIEW_NORMAL_MATRIX * TANGENT, 0.0)).xy;
		float thickness = max(width, min_pixels / VIEWPORT_SIZE.y);
		vec2 push = normalize(normal + vec2(1e-6)) * thickness * 2.0;
		push.x *= VIEWPORT_SIZE.y / VIEWPORT_SIZE.x;
		clip.xy += push * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = color.rgb;
}
