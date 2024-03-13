#ifndef RT_UTILS
#define RT_UTILS

/************* COSNTANTS *************/

#define K_PI                            3.1415926535f
#define K_INV_PI                        0.3183098862f
#define K_HALF_PI                       1.5707963267f
#define K_QUARTER_PI                    0.7853981633f
#define K_TWO_PI                        6.283185307f
#define K_SQRT_PI                       1.772453851f
#define K_INV_SQRT_PI                   0.5641895835f
#define K_INV_2_SQRT_PI                 0.2820947918f
#define K_INV_SQRT_2_PI                 0.3989422804f
#define K_SQRT_2                        1.4142135624f
#define K_INV_SQRT_2                    0.7071067812f
#define K_T_MIN                         0
#define K_T_MAX                         10000
#define K_FLT_MAX                       3.402823466e+38f
#define K_MAX_BOUNCES                   1000
#define K_RAY_ORIGIN_PUSH_OFF           0.002
#define K_MISS_SHADER_INDEX             0
#define K_MISS_SHADER_SHADOW_INDEX      1
#define K_MISS_SHADER_PT_INDEX          0

#include "UnityRaytracingMeshUtils.cginc"

struct PathPayload
{
    float3 radiance;
    float3 emission;
    uint bounceIndexOpaque;
    uint bounceIndexTransparent;
    float3 bounceRayDirection;
    float3 pushOff;
    float3 hitPointNormal;
    uint rngState;
    float T;
};

struct AttributeData
{
    float2 barycentrics;
};

struct Vertex
{
    float3 position;
    float3 normal;
    float3 tangent;
    float2 uv;
};

Vertex FetchVertex(uint vertexIndex)
{
    Vertex v;
    v.position = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributePosition);
    v.normal = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributeNormal);
    v.tangent = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributeTangent);
    v.uv = UnityRayTracingFetchVertexAttribute2(vertexIndex, kVertexAttributeTexCoord0);
    return v;
}

Vertex InterpolateVertices(Vertex v0, Vertex v1, Vertex v2, float3 barycentrics)
{
    Vertex v;
#define INTERPOLATE_ATTRIBUTE(attr) v.attr = v0.attr * barycentrics.x + v1.attr * barycentrics.y + v2.attr * barycentrics.z
    INTERPOLATE_ATTRIBUTE(position);
    INTERPOLATE_ATTRIBUTE(normal);
    INTERPOLATE_ATTRIBUTE(tangent);
    INTERPOLATE_ATTRIBUTE(uv);
    return v;
}

uint WangHash(inout uint seed)
{
    seed = (seed ^ 61) ^ (seed >> 16);
    seed *= 9;
    seed = seed ^ (seed >> 4);
    seed *= 0x27d4eb2d;
    seed = seed ^ (seed >> 15);
    return seed;
}

float RandomFloat01(inout uint seed)
{
    return float(WangHash(seed)) / float(0xFFFFFFFF);
}

float3 RandomUnitVector(inout uint state)
{
    float z = RandomFloat01(state) * 2.0f - 1.0f;
    float a = RandomFloat01(state) * K_TWO_PI;
    float r = sqrt(1.0f - z * z);
    float x = r * cos(a);
    float y = r * sin(a);
    return float3(x, y, z);
}

float3 FresnelSchlick(float3 incident, float3 normal, float3 F0)
{
    // Schlick's aproximation with F0
    float cosX = dot(normal, incident);
    float x = 1.0 - cosX;
    float xx = x * x;
    return F0 + (1.0 - F0) * xx * xx * x;
}

float FresnelReflectAmountOpaque(float n1, float n2, float3 incident, float3 normal)
{
    // Schlick's aproximation without F0
    float r0 = (n1 - n2) / (n1 + n2);
    r0 *= r0;
    float cosX = -dot(normal, incident);
    float x = 1.0 - cosX;
    float xx = x * x;
    return r0 + (1.0 - r0) * xx * xx * x;
}

float FresnelReflectAmountTransparent(float n1, float n2, float3 incident, float3 normal)
{
    // Schlick's aproximation without F0
    float r0 = (n1 - n2) / (n1 + n2);
    r0 *= r0;
    float cosX = -dot(normal, incident);

    if (n1 > n2)
    {
        float n = n1 / n2;
        float sinT2 = n * n * (1.0 - cosX * cosX);
        // Total internal reflection
        if (sinT2 >= 1.0)
            return 1;
        cosX = sqrt(1.0 - sinT2);
    }

    float x = 1.0 - cosX;
    float xx = x * x;
    return r0 + (1.0 - r0) * xx * xx * x;
}

#endif