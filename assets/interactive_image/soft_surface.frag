#include <flutter/runtime_effect.glsl>

uniform vec4 uImage;
uniform vec2 uContact;
uniform vec2 uDrag;
uniform float uRadius;
uniform float uIndentation;
uniform vec3 uBackground;
uniform sampler2D uPhoto;

out vec4 fragColor;

void main() {
    vec2 position = FlutterFragCoord().xy;
    vec2 local = (position - uContact) / uRadius;
    vec2 shape = local - 0.28 * uDrag;
    float distanceFromContact = length(shape);
    float falloff = 1.0 - smoothstep(0.0, 1.0, distanceFromContact);
    float ridge = smoothstep(0.08, 0.5, distanceFromContact) * falloff;
    vec2 displaced = position + uRadius * uIndentation *
        (0.76 * shape - 0.32 * uDrag) * falloff;
    vec4 photo = texture(uPhoto, clamp((displaced - uImage.xy) / uImage.zw, 0.0, 1.0));

    // The shallow depression catches light along one side and shades the other.
    float slope = dot(shape / max(distanceFromContact, 0.01), vec2(0.54, 0.84));
    float light = uIndentation * (ridge * 0.82 * slope - falloff * 0.28);
    vec3 shaded = clamp(photo.rgb * (1.0 + light) + max(light, 0.0) * photo.a * 0.12,
                        0.0, photo.a);
    vec3 surface = shaded + uBackground * (1.0 - photo.a);
    float coverage = smoothstep(0.0, 0.20, falloff) *
        smoothstep(0.0, 0.18, abs(uIndentation));
    fragColor = vec4(surface * coverage, coverage);
}
