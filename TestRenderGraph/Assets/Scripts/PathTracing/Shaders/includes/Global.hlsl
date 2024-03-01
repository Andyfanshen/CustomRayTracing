#ifndef RT_GLOBAL
#define RT_GLOBAL

float4 _BaseColor;

Texture2D<float4> _BaseMap;
float4 _BaseMap_ST;
SamplerState sampler__BaseMap;

Texture2D<float4> _NormalMap;
float4 _NormalMap_ST;
SamplerState sampler__NormalMap;

Texture2D<float4> _MetallicGlossMap;
float4 _MetallicGlossMap_ST;
SamplerState sampler__MetallicGlossMap;

float _Smoothness;
float _Metallic;
float _IOR;

Texture2D<float4> _EmissionMap;
float4 _EmissionMap_ST;
SamplerState sampler__EmissionMap;
float4 _EmissionColor;

float _ExtinctionCoefficient;

//------------------------------------------------------------------

RaytracingAccelerationStructure g_AccelStruct : register(t0, space1);

RWTexture2D<float4> g_Output : register(u0);
RWTexture2D<float4> g_DebugTex : register(u1);
RWTexture2D<float4> g_Reservoir0 : register(u2);

#endif