#include "UnityRaytracingMeshUtils.cginc"
#include "RayPayload.hlsl"
#include "Utils.hlsl"
#include "Global.hlsl"

#pragma raytracing test

#pragma shader_feature_raytracing _NORMALMAP
#pragma shader_feature_raytracing _METALLICMAP
#pragma shader_feature_raytracing _EMISSION
#pragma shader_feature_raytracing _TRANSPARENT

float3 GetNormalTS(float2 uv)
{
	float4 map = _NormalMap.SampleLevel(sampler__NormalMap, _NormalMap_ST.xy * uv + _NormalMap_ST.zw, 0);
	return UnpackNormal(map);
}

[shader("closesthit")]
void ClosestHitMain(inout PathPayload payload : SV_RayPayload, AttributeData attribs : SV_IntersectionAttributes)
{
	if (payload.bounceIndexOpaque == g_BounceCountOpaque)
	{
		payload.bounceIndexOpaque = -1;
		return;
	}

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
	float3 tangent = normalize(mul(v.tangent, (float3x3)WorldToObject()));
	float3 N = worldNormal;
	float3 T = normalize(tangent - dot(tangent, N) * N);
	float3 Bi = normalize(cross(T, N));
	float3x3 TBN = float3x3(T, Bi, N);

	float3 albedo = _Color.xyz * _MainTex.SampleLevel(sampler__MainTex, _MainTex_ST.xy * v.uv + _MainTex_ST.zw, 0).xyz;

	float3 metallic = _Metallic;

	float smoothness = _Glossiness;

#if _METALLICMAP
	float4 metallicSmoothness = _MetallicMap.SampleLevel(sampler__MetallicMap, _MetallicMap_ST.xy * v.uv + _MetallicMap_ST.zw, 0);
	metallic = metallicSmoothness.xxx;
	smoothness *= metallicSmoothness.w;
#endif

	smoothness = clamp(smoothness, 1e-6, 0.9999f);
	float3 emission = float3(0, 0, 0);

#if _EMISSION
	emission = _EmissionColor * _EmissionTex.SampleLevel(sampler__EmissionTex, _EmissionTex_ST.xy * v.uv + _EmissionTex_ST.zw, 0).xyz;
#endif

#if _NORMALMAP
	localNormal = GetNormalTS(v.uv);	
	worldNormal = normalize(mul(localNormal, TBN));
	N = worldNormal;
	T = normalize(T - dot(T, N) * N);
	Bi = normalize(cross(T, N));
	TBN = float3x3(T, Bi, N);
#endif

#if _TRANSPARENT
	float3 roughness = (1 - smoothness) * RandomUnitVector(payload.rngState);

	worldNormal = normalize(mul(localNormal, (float3x3)WorldToObject()) + roughness);

	float indexOfRefraction = isFrontFace ? 1 / _IOR : _IOR;

	float3 reflectionRayDir = reflect(WorldRayDirection(), worldNormal);

	float3 refractionRayDir = refract(WorldRayDirection(), worldNormal, indexOfRefraction);

	float fresnelFactor = FresnelReflectAmountTransparent(isFrontFace ? 1 : _IOR, isFrontFace ? _IOR : 1, WorldRayDirection(), worldNormal);

	float doRefraction = (RandomFloat01(payload.rngState) > fresnelFactor) ? 1 : 0;

	albedo = !isFrontFace ? exp(-(1 - _Color.xyz) * RayTCurrent() * _ExtinctionCoefficient) : float3(1, 1, 1);

	float3 radiance = albedo / ((doRefraction == 1) ? 1 - fresnelFactor : fresnelFactor);

	uint bounceIndexOpaque = payload.bounceIndexOpaque;

	uint bounceIndexTransparent = payload.bounceIndexTransparent + 1;

	float3 pushOff = worldNormal * (doRefraction ? -K_RAY_ORIGIN_PUSH_OFF : K_RAY_ORIGIN_PUSH_OFF);

	float3 bounceRayDir = lerp(reflectionRayDir, refractionRayDir, doRefraction);
#else
	float roughness = clamp(1.0 - smoothness, 1e-6, 0.9999f);

	//float fresnelFactor = FresnelReflectAmountOpaque(isFrontFace ? 1 : _IOR, isFrontFace ? _IOR : 1, WorldRayDirection(), worldNormal);

	float3 view = -WorldRayDirection();
	float3 view_tangent = mul(TBN, view);
	
	float3 F0 = lerp(float3(0.04, 0.04, 0.04), albedo, metallic);
	float3 fresnel = FresnelSchlick(view, worldNormal, F0);

    float3 bounceDir_tangent;
	float3 radiance;
	if(RandomFloat01(payload.rngState) < smoothness)
	{// specular
		radiance = EvalGGXVNDF(view_tangent, fresnel, roughness, roughness, bounceDir_tangent, payload.rngState);
	}
	else
	{// diffuse
		bounceDir_tangent = SampleCosineHemisphere(float3(0, 0, 1), payload.rngState);
		radiance = albedo;
	}

	float3 bounceRayDir = mul(bounceDir_tangent, TBN);

	uint bounceIndexOpaque = payload.bounceIndexOpaque + 1;

	uint bounceIndexTransparent = payload.bounceIndexTransparent;

	float3 pushOff = K_RAY_ORIGIN_PUSH_OFF * worldFaceNormal;

#endif
	payload.radiance = radiance;
	payload.emission = emission;
	payload.bounceIndexOpaque = bounceIndexOpaque;
	payload.bounceIndexTransparent = bounceIndexTransparent;
	payload.bounceRayOrigin = worldPosition + pushOff;
	payload.bounceRayDirection = bounceRayDir;
}