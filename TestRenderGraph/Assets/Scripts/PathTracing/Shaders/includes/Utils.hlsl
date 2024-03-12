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

/************* RAY TRACING STRUCTURE *************/

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

/************* RANDOM NUMBERS GENERATOR *************/

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

/************* BASIC FUNCTIONS *************/
bool IsFiniteNumber(float x)
{
    return (x <= K_FLT_MAX && x >= -K_FLT_MAX);
}

float erf(float x)
{
    float a1 =  0.254829592f;
    float a2 = -0.284496736f;
    float a3 =  1.421413741f;
    float a4 = -1.453152027f;
    float a5 =  1.061405429f;
    float p  =  0.3275911f;

    float sign = x < 0 ? -1 : 1;
    x = abs(x);

    float t = 1.0f / (1.0f + p * x);
    float y = 1.0f - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-x * x);

    return sign * y;
}

float erfinv(float x)
{
    float w, p;
    w = - log((1.0f - x) * (1.0f + x));
    if(w < 5.0f)
    {
        w = w - 2.5f;
        p = 2.81022636e-08f;
        p = 3.43273939e-07f + p * w;
        p = -3.5233877e-06f + p * w;
        p = -4.39150654e-06f + p * w;
        p = 0.00021858087f + p * w;
        p = -0.00125372503f + p * w;
        p = -0.00417768164f + p * w;
        p = 0.246640727f + p * w;
        p = 1.50140941f + p * w;
    }
    else
    {
        w = sqrt(w) - 3.0f;
        p = -0.000200214257f;
        p = 0.000100950558f + p * w;
        p = 0.00134934322f + p * w;
        p = -0.00367342844f + p * w;
        p = 0.00573950773f + p * w;
        p = -0.0076224613f + p * w;
        p = 0.00943887047f + p * w;
        p = 1.00167406f + p * w;
        p = 2.83297682f + p * w;
    }

    return p * x;
}

float abgam(float x)
{
    float gam[10], temp;

    gam[0] = 1./ 12.;
    gam[1] = 1./ 30.;
    gam[2] = 53./ 210.;
    gam[3] = 195./ 371.;
    gam[4] = 22999./ 22737.;
    gam[5] = 29944523./ 19733142.;
    gam[6] = 109535241009./ 48264275462.;
    temp = 0.5 * log(2 * K_PI) - x + (x - 0.5) * log(x)
    + gam[0] / (x + gam[1] / (x + gam[2] / (x + gam[3] / (x + gam[4] /
	    (x + gam[5] / (x + gam[6] / x))))));

    return temp;
}

float gamma(float x)
{
    return exp(abgam(x + 5)) / (x * (x + 1) * (x + 2) * (x + 3) * (x + 4));
}

float beta(float m, float n)
{
    return gamma(m) * gamma(n) / gamma(m + n);
}

// build orthonormal basis (Building an Orthonormal Basis from a 3D Unit Vector Without Normalization, [Frisvad2012])
void BuildOrthonormalBasis(inout float3 omega_1, inout float3 omega_2, inout float3 omega_3)
{
    if(omega_3.z < -0.9999999f)
    {
        omega_1 = float3(0.0f, -1.0f, 0.0f);
        omega_2 = float3(-1.0f, 0.0f, 0.0f);
    }
    else
    {
        float a = 1.0f / (1.0f + omega_3.z);
        float b = -omega_3.x * omega_3.y * a;
        omega_1 = float3(1.0f - omega_3.x * omega_3.x * a, b, -omega_3.x);
        omega_2 = float3(b, 1.0f - omega_3.y * omega_3.y * a, -omega_3.y);
    }
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