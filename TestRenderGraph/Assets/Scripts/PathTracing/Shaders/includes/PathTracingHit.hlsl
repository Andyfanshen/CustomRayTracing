#ifndef RT_PATHTRACINGHIT
#define RT_PATHTRACINGHIT

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

#include "Restir.hlsl"
#include "Utils.hlsl"
#include "BRDF.hlsl"
#include "Global.hlsl"

#pragma raytracing test

#pragma shader_feature_raytracing _NORMALMAP
#pragma shader_feature_raytracing _METALLICSPECGLOSSMAP
#pragma shader_feature_raytracing _EMISSION
#pragma shader_feature_raytracing _SURFACE_TYPE_TRANSPARENT

void DebugMethod(inout PathPayload payload, float3 output)
{
	//output = (output + float3(1,1,1)) / 2.0;
	//payload.radiance = output;
	payload.emission = output;
	payload.bounceIndexOpaque = K_MAX_BOUNCES + 1;
	return;
}

float3 GetNormalTS(float2 uv)
{
	float4 map = _NormalMap.SampleLevel(sampler__NormalMap, _NormalMap_ST.xy * uv + _NormalMap_ST.zw, 0);
	return UnpackNormal(map);
}

[shader("closesthit")]
void ClosestHitMain(inout PathPayload payload : SV_RayPayload, AttributeData attribs : SV_IntersectionAttributes)
{
	uint3 triangleIndices = UnityRayTracingFetchTriangleIndices(PrimitiveIndex());

	Vertex v0, v1, v2;
	v0 = FetchVertex(triangleIndices.x);
	v1 = FetchVertex(triangleIndices.y);
	v2 = FetchVertex(triangleIndices.z);

	float3 barycentricCoords = float3(1.0 - attribs.barycentrics.x - attribs.barycentrics.y, attribs.barycentrics.x, attribs.barycentrics.y);

	Vertex v = InterpolateVertices(v0, v1, v2, barycentricCoords);

	bool isFrontFace = HitKind() == HIT_KIND_TRIANGLE_FRONT_FACE;

	float3 localNormal = isFrontFace ? v.normal : -v.normal;

	float3 worldNormal = normalize(mul(localNormal, (float3x3)WorldToObject()));

	float3 worldPosition = mul(ObjectToWorld(), float4(v.position, 1)).xyz;

	// Bounced ray origin is pushed off of the surface using the face normal (not the interpolated normal).
	float3 e0 = v1.position - v0.position;
	float3 e1 = v2.position - v0.position;

	float3 worldFaceNormal = normalize(mul(cross(e0, e1), (float3x3)WorldToObject()));

	// Construct TBN
	// vector_ws = mul(vector_ts, TBN);
	// vector_ts = mul(TBN, vector_ws);
	float3x3 TBN = GetLocalFrame(worldNormal);

	float3 albedo = _BaseColor.xyz * _BaseMap.SampleLevel(sampler__BaseMap, _BaseMap_ST.xy * v.uv + _BaseMap_ST.zw, 0).xyz;

	// Alpha clip
	//float albedoAlpha = _BaseMap.SampleLevel(sampler__BaseMap, _BaseMap_ST.xy * v.uv + _BaseMap_ST.zw, 0).w;
	//if(albedoAlpha < _Cutoff)
	//{
	//	payload.radiance = float3(1, 1, 1);
	//	payload.emission = float3(0, 0, 0);
	//	payload.bounceRayDirection = WorldRayDirection();
	//	payload.pushOff = WorldRayDirection() * K_RAY_ORIGIN_PUSH_OFF;
	//	payload.hitPointNormal = WorldRayDirection();
	//	payload.T = RayTCurrent();
	//	return;
	//}

	float3 metallic = _Metallic;

	float smoothness = _Smoothness;

	float3 emission = float3(0, 0, 0);
	
#if _NORMALMAP
	localNormal = GetNormalTS(v.uv);
#endif

#if _METALLICSPECGLOSSMAP
	float4 metallicSmoothness = _MetallicGlossMap.SampleLevel(sampler__MetallicGlossMap, _MetallicGlossMap_ST.xy * v.uv + _MetallicGlossMap_ST.zw, 0);
	metallic = metallicSmoothness.xxx;
	smoothness *= metallicSmoothness.w;
#endif

#if _EMISSION
	emission = _EmissionColor * _EmissionMap.SampleLevel(sampler__EmissionMap, _EmissionMap_ST.xy * v.uv + _EmissionMap_ST.zw, 0).xyz;
#endif

#if _SURFACE_TYPE_TRANSPARENT
	float ior = 1.5; // _IOR
	float extinction = 10; // _ExtinctionCoefficient;

	float3 roughness = (1 - smoothness) * RandomUnitVector(payload.rngState);

	worldNormal = normalize(mul(localNormal, (float3x3)WorldToObject()) + roughness);

	float indexOfRefraction = isFrontFace ? 1 / ior : ior;

	float3 reflectionRayDir = reflect(WorldRayDirection(), worldNormal);

	float3 refractionRayDir = refract(WorldRayDirection(), worldNormal, indexOfRefraction);

	float fresnelFactor = FresnelReflectAmountTransparent(isFrontFace ? 1 : ior, isFrontFace ? ior : 1, WorldRayDirection(), worldNormal);

	float doRefraction = (RandomFloat01(payload.rngState) > fresnelFactor) ? 1 : 0;

	albedo = !isFrontFace ? exp(-(1 - _BaseColor.xyz) * RayTCurrent() * extinction) : float3(1, 1, 1);

	float3 radiance = albedo / ((doRefraction == 1) ? 1 - fresnelFactor : fresnelFactor);

	uint bounceIndexOpaque = payload.bounceIndexOpaque;

	uint bounceIndexTransparent = payload.bounceIndexTransparent + 1;

	float3 pushOff = worldFaceNormal * (doRefraction ? -K_RAY_ORIGIN_PUSH_OFF : K_RAY_ORIGIN_PUSH_OFF);

	float3 bounceRayDir = lerp(reflectionRayDir, refractionRayDir, doRefraction);
#else
	float roughness = 1 - smoothness;

	float3 view = -WorldRayDirection();
	float3 view_tangent = mul(TBN, view);
	
	float3 F0 = lerp(albedo, float3(0.04, 0.04, 0.04), metallic);
	float3 fresnel = FresnelSchlick(view, worldNormal, F0);

    float3 bounceDir_tangent;
	float3 radiance;
	if(RandomFloat01(payload.rngState) < smoothness)
	{// specular
		float pdf;
		//radiance = TestEvalGGXVNDF(view_tangent, fresnel, roughness, roughness, bounceDir_tangent, payload.rngState, pdf);
		
		float2 u = float2(RandomFloat01(payload.rngState), RandomFloat01(payload.rngState));
		float3 Ne = sampleGGX_VNDF(roughness, view_tangent, u, pdf);
        pdf /= 4 * dot(view_tangent, Ne);
        bounceDir_tangent = reflect(-view_tangent, Ne);
        radiance = EvalGGXVNDF(view_tangent, bounceDir_tangent, albedo.xyz, roughness) / pdf;
	}
	else
	{// diffuse
		bounceDir_tangent = SampleCosineHemisphere(float3(0, 0, 1), payload.rngState);
		radiance = albedo;
	}

	float3 bounceRayDir = mul(bounceDir_tangent, TBN);

	uint bounceIndexOpaque = payload.bounceIndexOpaque + 1;

	uint bounceIndexTransparent = payload.bounceIndexTransparent;

	float3 pushOff = worldFaceNormal * K_RAY_ORIGIN_PUSH_OFF;

#endif
	payload.radiance = radiance;
	payload.emission = emission;
	payload.bounceIndexOpaque = bounceIndexOpaque;
	payload.bounceIndexTransparent = bounceIndexTransparent;
	payload.bounceRayDirection = bounceRayDir;
	payload.pushOff = pushOff;
	payload.hitPointNormal = worldNormal;
	payload.T = RayTCurrent();
}

#endif