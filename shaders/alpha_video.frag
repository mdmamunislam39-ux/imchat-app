#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uLayout; // 0.0 = horizontal (left/right), 1.0 = vertical (top/bottom)
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
    // FlutterFragCoord() gives coordinates in physical pixels of the canvas area
    vec2 uv = FlutterFragCoord().xy / uSize;
    
    vec2 colorUv;
    vec2 alphaUv;
    
    if (uLayout < 0.5) {
        // Horizontal: Left is color, Right is mask
        colorUv = vec2(uv.x * 0.5, uv.y);
        alphaUv = vec2(0.5 + uv.x * 0.5, uv.y);
    } else {
        // Vertical: Top is color, Bottom is mask
        colorUv = vec2(uv.x, uv.y * 0.5);
        alphaUv = vec2(uv.x, 0.5 + uv.y * 0.5);
    }
    
    vec4 colorSample = texture(uTexture, colorUv);
    vec4 alphaSample = texture(uTexture, alphaUv);
    
    // Grayscale alpha value (using red channel of the mask video side)
    float alpha = alphaSample.r;
    
    // Output color with premultiplied alpha
    fragColor = vec4(colorSample.rgb * alpha, alpha);
}
