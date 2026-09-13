#include <metal_stdlib>
using namespace metal;
struct Vertex { float4 position [[position]]; float2 uv; };
struct Settings { float progress; float frost; float foldSpan; float reducedMotion; };
vertex Vertex foldVertex(uint id [[vertex_id]]) {
    float2 p = float2((id << 1) & 2, id & 2);
    return {float4(p * 2 - 1, 0, 1), float2(p.x, 1 - p.y)};
}
fragment float4 foldFragment(Vertex in [[stage_in]], texture2d<float> picture [[texture(0)]], constant Settings &s [[buffer(0)]]) {
    // The desktop fills the physical display: projection beyond its captured
    // bounds continues the edge colors instead of exposing black side wedges.
    constexpr sampler tex(filter::linear, mip_filter::linear, address::clamp_to_edge);
    float p = clamp(s.progress, 0.0f, 1.0f);
    if (s.reducedMotion > 0.5) {
        return float4(picture.sample(tex, in.uv, level(0)).rgb * (1 - smoothstep(0.0, 1.0, p)), 1);
    }
    float h = 1 - in.uv.y; // Distance from the MacBook's bottom hinge.
    float theta = p * s.foldSpan;
    float depth = h * sin(theta);
    // Eye at (0.5, 0.5, D), glass moving toward the eye. Intersect the
    // eye->glass ray with the original screen plane, z=0. At h=0, t=1.
    float distance = 2.4;
    float t = distance / (distance - depth);
    float2 uv = float2(0.5 + (in.uv.x - 0.5) * t,
                       1 - (0.5 + (h * cos(theta) - 0.5) * t));
    float radius = abs(depth) * t * s.frost * 64 * (float(picture.get_height()) / 900.0) * smoothstep(0.0, 0.12, p);
    float lod = clamp(log2(1 + radius), 0.0f, float(picture.get_num_mip_levels() - 1));
    float3 color = picture.sample(tex, uv, level(lod)).rgb;
    // Spatial frosting, a restrained cool glass reflection, then extinction.
    float haze = abs(depth) * 0.13 * sin(p * M_PI_F);
    color = mix(color, float3(0.76, 0.83, 0.91), haze);
    float extinction = smoothstep(0.40, 1.0, p) * (0.42 + 0.58 * smoothstep(0.0, 0.9, h));
    color *= (1 - extinction) * (1 - smoothstep(0.86, 1.0, p));
    return float4(color, 1);
}
