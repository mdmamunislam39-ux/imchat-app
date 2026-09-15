#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uLayout; // 0.0 = horiz (Color L, Mask R), 1.0 = vert (Color T, Mask B), 2.0 = horiz (Mask L, Color R), 3.0 = vert (Mask T, Color B)
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
    // FlutterFragCoord() gives coordinates in physical pixels of the canvas area
    vec2 uv = FlutterFragCoord().xy / uSize;
    
    vec2 colorUv;
    vec2 alphaUv;
    
    if (uLayout < 0.5) {
        // 0.0: Horizontal: Left is color, Right is mask
        colorUv = vec2(uv.x * 0.5, uv.y);
        alphaUv = vec2(0.5 + uv.x * 0.5, uv.y);
    } else if (uLayout < 1.5) {
        // 1.0: Vertical: Top is color, Bottom is mask
        colorUv = vec2(uv.x, uv.y * 0.5);
        alphaUv = vec2(uv.x, 0.5 + uv.y * 0.5);
    } else if (uLayout < 2.5) {
        // 2.0: Horizontal Inverted: Left is mask, Right is color
        alphaUv = vec2(uv.x * 0.5, uv.y);
        colorUv = vec2(0.5 + uv.x * 0.5, uv.y);
    } else {
        // 3.0: Vertical Inverted: Top is mask, Bottom is color
        alphaUv = vec2(uv.x, uv.y * 0.5);
        colorUv = vec2(uv.x, 0.5 + uv.y * 0.5);
    }
    
    vec4 colorSample = texture(uTexture, colorUv);
    vec4 alphaSample = texture(uTexture, alphaUv);
    
    // Grayscale alpha value (using red channel of the mask video side)
    float alpha = alphaSample.r;
    
    // Output color with premultiplied alpha
    fragColor = vec4(colorSample.rgb * alpha, alpha);
}
