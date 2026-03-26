#version 330 core
out vec4 FragColor;

in vec2 texCoord;
uniform sampler2D displayTexture;

void main() {
    float pixelState = texture(displayTexture, texCoord).r;

    if (pixelState > 0.0) {
        FragColor = vec4(1.0, 1.0, 1.0, 1.0);
    } else {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}

