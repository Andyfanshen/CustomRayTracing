#define K_PI                            3.1415926535f
#define K_HALF_PI                       1.5707963267f
#define K_QUARTER_PI                    0.7853981633f
#define K_TWO_PI                        6.283185307f
#define K_INV_PI                        0.3183098862f
#define K_T_MIN                         0
#define K_T_MAX                         10000
#define K_MAX_BOUNCES                   1000
#define K_RAY_ORIGIN_PUSH_OFF           0.002
#define K_MISS_SHADER_INDEX             0
#define K_MISS_SHADER_SHADOW_INDEX      1
#define K_MISS_SHADER_PT_INDEX          0

#include "UnityRaytracingMeshUtils.cginc"

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

// Unpack normal as DXT5nm (1, y, 1, x) or BC5 (x, y, 0, 1)
// Note neutral texture like "bump" is (0, 0, 1, 1) to work with both plain RGB normal and DXT5nm/BC5
float3 UnpackNormalmapRGorAG(float4 packednormal)
{
    // This do the trick
    packednormal.x *= packednormal.w;

    float3 normal;
    normal.xy = packednormal.xy * 2 - 1;
    normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
    return normal;
}
inline float3 UnpackNormal(float4 packednormal)
{
#if defined(UNITY_NO_DXT5nm)
    return packednormal.xyz * 2 - 1;
#else
    return UnpackNormalmapRGorAG(packednormal);
#endif
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

float FresnelReflectAmountOpaque(float n1, float n2, float3 incident, float3 normal)
{
    // Schlick's aproximation
    float r0 = (n1 - n2) / (n1 + n2);
    r0 *= r0;
    float cosX = -dot(normal, incident);
    float x = 1.0 - cosX;
    float xx = x * x;
    return r0 + (1.0 - r0) * xx * xx * x;
}

float FresnelReflectAmountTransparent(float n1, float n2, float3 incident, float3 normal)
{
    // Schlick's aproximation
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

float3 SampleCosineHemisphere(float3 normal, inout uint state)
{
    return normalize(normal + RandomUnitVector(state));
}

float GGX_Lambda(float3 view, float roughnessX, float roughnessY)
{
    float xx = roughnessX * roughnessX * view.x * view.x;
    float yy = roughnessY * roughnessY * view.y * view.y;
    float zz = view.z * view.z;
    return (-1.0 + sqrt(1.0 + (xx + yy) / zz)) / 2.0;
}

float GGX_G1(float3 view, float roughnessX, float roughnessY)
{
    return 1.0 / (1.0 + GGX_Lambda(view, roughnessX, roughnessY));
}

float GGX_G2(float3 bounceDir, float3 view, float roughnessX, float roughnessY)
{
    return 1.0 / (1.0 + GGX_Lambda(bounceDir, roughnessX, roughnessY) + GGX_Lambda(view, roughnessX, roughnessY));
}

float GGX_Eval(float3 wh, float roughnessX, float roughnessY)
{
    float xx = wh.x * wh.x / roughnessX / roughnessX;
    float yy = wh.y * wh.y / roughnessY / roughnessY;
    float zz = wh.z * wh.z;
    float nn = (xx + yy + zz) * (xx + yy + zz);
    return 1.0 / (K_PI * (roughnessX * roughnessY) * nn);
}

float GGX_PDF(float3 view, float3 normal, float roughnessX, float roughnessY)
{
    return GGX_G1(view, roughnessX, roughnessY) * abs(dot(view, normal)) * GGX_Eval(normal, roughnessX, roughnessY) / abs(view.z);
}

float3 SampleGGXVNDF(float3 view, float roughnessX, float roughnessY, inout uint state)
{
    float u1 = RandomFloat01(state);
    float u2 = RandomFloat01(state);

    float3 v = normalize(float3(roughnessX * view.x, roughnessY * view.y, view.z));

    float3 T1 = (v.z < 0.9999) ? normalize(cross(v, float3(0.0, 0.0, 1.0))) : float3(1.0, 0.0, 0.0);
    float3 T2 = cross(T1, v);

    float a = 1.0 / (1.0 + v.z);
    float r = sqrt(u1);
    float phi = (u2 < a) ? u2 / a * K_PI : K_PI + (u2 - a) / (1.0 - a) * K_PI;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi) * ((u2 < a) ? 1.0 : v.z);

    float3 n = t1 * T1 + t2 * T2 + v * sqrt(1.0 - t1 * t1 - t2 * t2);

    return normalize(float3(roughnessX * n.x, roughnessY * n.y, n.z));
}

float3 SampleBSDF(float3x3 TBN, float3 view, float3 normal, float roughness, float3 diffuseColor, float3 specularColor, float specularChance, float fresnel, out float3 bounceDir, out float pdf, inout uint state)
{
    float3 view_tangent = mul(TBN, view);
    float3 bounceDir_tangent;

    if(RandomFloat01(state) < specularChance)
    {
        float3 wh = SampleGGXVNDF(view_tangent, roughness, roughness, state);
        bounceDir_tangent = reflect(-view_tangent, wh);
        pdf = GGX_PDF(view_tangent, wh, roughness, roughness) / (4.0 * dot(view_tangent, wh));
    }
    else
    {
        bounceDir_tangent = SampleCosineHemisphere(float3(0, 0, 1), state);
        pdf = K_INV_PI * bounceDir_tangent;
    }

    pdf = clamp(pdf, 0.0, 1.0);

    bounceDir = mul(bounceDir_tangent, TBN);

    if(dot(view, normal) * dot(bounceDir, normal) < 0) pdf = 0.0;
    if(dot(view_tangent, bounceDir_tangent) < 0) return float3(0.0, 0.0, 0.0);

    float cosThetaO = abs(view_tangent.z);
    float cosThetaI = abs(bounceDir_tangent.z);
    float3 wh = bounceDir_tangent + view_tangent;

    if(cosThetaI == 0.0 || cosThetaO == 0.0) return float3(0.0, 0.0, 0.0);
    if(wh.x == 0.0 && wh.y == 0.0 && wh.z == 0.0) return float3(0.0, 0.0, 0.0);

    wh = normalize(wh);

    float3 specRefl = specularColor * GGX_Eval(wh, roughness, roughness) * GGX_G2(view_tangent, bounceDir_tangent, roughness, roughness) * fresnel / (4.0 * cosThetaI * cosThetaO);

    float3 diffRefl = K_INV_PI * diffuseColor * (1.0 - fresnel);

    return lerp(diffRefl, specRefl, specularChance);
}