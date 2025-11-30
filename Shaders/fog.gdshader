shader_type spatial;
render_mode unshaded; // Keep this if you want it to glow in the dark

// ... (Your existing uniforms) ...
uniform sampler2D albedo_texture;
uniform vec2 uv_scale = vec2(2.0, 2.0);
uniform vec2 scroll_speed = vec2(0.2, 0.0);
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Added source_color hint for picker
uniform float emission_strength : hint_range(0.0, 5.0) = 1.0;

// NEW: Brightness control
uniform float brightness : hint_range(0.0, 2.0) = 0.5;

// ... (Wave uniforms) ...
uniform float wave_amplitude : hint_range(0.0, 0.5) = 0.1;
uniform float wave_frequency : hint_range(0.0, 10.0) = 3.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // ... (Your existing UV logic) ...
    vec2 continuous_uv = UV * uv_scale;
    continuous_uv += scroll_speed * TIME;
    vec2 distorted_uv = continuous_uv;
    distorted_uv.x += sin(continuous_uv.y * wave_frequency + TIME * wave_speed) * wave_amplitude;
    distorted_uv.y += cos(continuous_uv.x * wave_frequency + TIME * wave_speed) * wave_amplitude;
    vec2 final_uv = fract(distorted_uv);

    vec4 tex_color = texture(albedo_texture, final_uv);

    // APPLY BRIGHTNESS HERE
    vec3 base_color = tex_color.rgb * color_tint.rgb * brightness;

    ALBEDO = base_color;
    EMISSION = base_color * emission_strength; // Emission scales with brightness
    ALPHA = tex_color.a * color_tint.a * alpha;
}