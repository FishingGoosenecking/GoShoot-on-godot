shader_type canvas_item;

uniform vec2 light_pos;
uniform vec2 screen_size;

uniform float radius = 200.0;
uniform float darkness = 0.65;
uniform float softness = 0.35;

void fragment() {

    vec2 screen_pos = SCREEN_UV * screen_size;

    float dist = distance(screen_pos, light_pos);

    float edge_start = radius * (1.0 - softness);

    // Fully clear in center
    if (dist < edge_start) {
        discard;
    }

    // Fade zone
    float alpha = smoothstep(edge_start, radius*0.7, dist);

    // Apply darkness strength
    alpha *= darkness;

    COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
