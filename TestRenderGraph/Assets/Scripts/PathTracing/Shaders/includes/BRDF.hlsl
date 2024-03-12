#ifndef RT_BRDF
#define RT_BRDF

#include "./Utils.hlsl"

/************* MICROSURFACE HEIGHT DISTRIBUTION *************/

// height PDF
float HeightUniformP1(float h)
{
    return (h >= -1.0f && h <= 1.0f) ? 0.5f : 0.0f;
}

// height CDF
float HeightUniformC1(float h)
{
    return min(1.0f, max(0.0f, 0.5f * (h + 1.0f)));
}

// inverse of the height CDF
float HeightUniformInvC1(float u)
{
    return max(-1.0f, min(1.0f, 2.0f * u - 1.0f));
}

// height PDF
float HeightGaussianP1(float h)
{
    return K_INV_SQRT_2_PI * exp(-0.5f * h * h);
}

// height CDF
float HeightGaussianC1(float h)
{
    return 0.5f + 0.5f * erf(K_INV_SQRT_2 * h);
}

// inverse of the height CDF
float HeightGaussianInvC1(float u)
{
    return K_SQRT_2 * erfinv(2.0f * u - 1.0f);
}

/************* MICROSURFACE SLOPE DISTRIBUTION *************/

// projected roughness in wi
float Slope_alpha_i(float3 wi, float alpha_x, float alpha_y)
{
    float invSinTheta2 = 1.0f / (1.0f - wi.z * wi.z);
    float cosPhi2 = wi.x * wi.x * invSinTheta2;
    float sinPhi2 = wi.y * wi.y * invSinTheta2;
    return sqrt(cosPhi2 * alpha_x * alpha_x + sinPhi2 * alpha_y * alpha_y);
}

// projected roughness in wi with correlation coefficient rxy
float Slope_alpha_i(float3 wi, float alpha_x, float alpha_y, float rxy)
{
    float invSinTheta2 = 1.0f / (1.0f - wi.z * wi.z);
    float cosPhi2 = wi.x * wi.x * invSinTheta2;
    float sinPhi2 = wi.y * wi.y * invSinTheta2;
    float correlation = 2.0f * sqrt(cosPhi2 * sinPhi2) * rxy * alpha_x * alpha_y;
    return sqrt(cosPhi2 * alpha_x * alpha_x + sinPhi2 * alpha_y * alpha_y + correlation);
}

// distribution of slopes
float Slope_GGX_P22(float slope_x, float slope_y, float alpha_x, float alpha_y)
{
    float tmp = 1.0f + slope_x * slope_x / (alpha_x * alpha_x) + slope_y * slope_y / (alpha_y * alpha_y);
    return 1.0f / (K_PI * alpha_x * alpha_y) / (tmp * tmp);
}

// Smith's Lambda function
float Slope_GGX_Lambda(float3 wi, float alpha_x, float alpha_y)
{
    if(wi.z > 0.9999f) return 0.0f;
    if(wi.z < -0.9999f) return -1.0f;

    float theta_i = acos(wi.z);
    float a = 1.0f / tan(theta_i) / Slope_alpha_i(wi, alpha_x, alpha_y);

    return 0.5f * (-1.0f + sign(a) * sqrt(1.0f + 1.0f / (a * a)));
}

// general GGX Lambda function on mesosurface (non-axis-aligned & non-centered distribution)
float Slope_General_GGX_Lambda(float3 wi, float alpha_x, float alpha_y, float rxy, float2 ave_slope)
{
    if(wi.z > 0.9999f) return 0.0f;
    if(wi.z < -0.9999f) return -1.0f;

    float theta_i = acos(wi.z);
    float cosPhi_i = wi.x / sin(theta_i);
    float sinPhi_i = wi.y / sin(theta_i);
    float alpha_i = Slope_alpha_i(wi, alpha_x, alpha_y, rxy);
    float a = (1.0f / tan(theta_i) - (cosPhi_i * ave_slope.x + sinPhi_i * ave_slope.y)) / alpha_i;

    return 0.5f * (-1.0f + sign(a) * sqrt(1.0f + 1.0f / (a * a)));
}

// projected area towards incident direction
float Slope_GGX_ProjectedArea(float3 wi, float alpha_x, float alpha_y)
{
    if(wi.z > 0.9999f) return 1.0f;
    if(wi.z < -0.9999f) return 0.0f;

    float theta_i = acos(wi.z);
    float sin_theta_i = sin(theta_i);
    float alpha_i = Slope_alpha_i(wi, alpha_x, alpha_y);

    return 0.5f * (wi.z + sqrt(wi.z * wi.z + sin_theta_i * sin_theta_i * alpha_i * alpha_i));
}

// distribution of normals (NDF)
float Slope_D(float3 wm, float alpha_x, float alpha_y)
{
    if(wm.z <= 0.0f) return 0.0f;

    float slope_x = -wm.x / wm.z;
    float slope_y = -wm.y / wm.z;

    return Slope_GGX_P22(slope_x, slope_y, alpha_x, alpha_y) / (wm.z * wm.z * wm.z * wm.z);
}

// distribution of visible normals (VNDF) | PDF
float Slope_D_wi(float3 wi, float3 wm, float alpha_x, float alpha_y)
{
    if(wm.z <= 0.0f) return 0.0f;

    float projectedArea = Slope_GGX_ProjectedArea(wi, alpha_x, alpha_y);
    if(projectedArea == 0) return 0;

    float c = 1.0f / projectedArea;
    return c * max(0.0f, dot(wi, wm)) * Slope_D(wm, alpha_x, alpha_y);
}

// sample the distribution of visible slopes with alpha=1.0
float2 Slope_GGX_Sample_P22_11(float theta_i, float u_1, float u_2)
{
    float2 slope;

    if(theta_i < 0.0001f)
    {
        float r = sqrt(u_1 / (1.0f - u_1));
        float phi = K_TWO_PI * u_2;
        slope.x = r * cos(phi);
        slope.y = r * sin(phi);
        return slope;
    }

    float sin_theta_i = sin(theta_i);
    float cos_theta_i = cos(theta_i);
    float tan_theta_i = sin_theta_i / cos_theta_i;

    float slope_i = cos_theta_i / sin_theta_i;

    float projectedArea = 0.5f * (cos_theta_i + 1.0f);
    if(projectedArea < 0.0001f || isnan(projectedArea)) return float2(0, 0);

    float c = 1.0f / projectedArea;
    float A = 2.0f * u_1 / cos_theta_i / c - 1.0f;
    float B = tan_theta_i;
    float tmp = 1.0f / (A * A - 1.0f);
    float D = sqrt(max(0.0f, B * B * tmp * tmp - (A * A - B * B) * tmp));
    float slope_x_1 = B * tmp - D;
    float slope_x_2 = B * tmp + D;
    slope.x = (A < 0.0f || slope_x_2 > 1.0f / tan_theta_i) ? slope_x_1 : slope_x_2;

    float u2, s;
    if(u_2 > 0.5f)
    {
        s = 1.0f;
        u2 = 2.0f * (u_2 - 0.5f);
    }
    else
    {
        s = -1.0f;
        u2 = 2.0f * (0.5f - u_2);
    }
    float z = (u2 * (u2 * (u2 * 0.27385f - 0.73369f) + 0.46341f)) / (u2 * (u2 * (u2 * 0.093073f + 0.309420f) - 1.0f) + 0.597999f);
    slope.y = s * z * sqrt(1.0f + slope.x * slope.x);

    return slope;
}

// sample the VNDF 2016
float3 Slope_Sample_D_wi(float3 wi, float alpha_x, float alpha_y, float u_1, float u_2)
{
    // stretch to match configuration with alpha=1.0
    float3 wi_11 = normalize(float3(alpha_x * wi.x, alpha_y * wi.y, wi.z));

    // sample visible slope with alpha=1.0
    float2 slope_11 = Slope_GGX_Sample_P22_11(acos(wi_11.z), u_1, u_2);

    // align with view direction
    float phi = atan2(wi_11.y, wi_11.x);
    float2 slope = float2(cos(phi) * slope_11.x - sin(phi) * slope_11.y,
                            sin(phi) * slope_11.x + cos(phi) * slope_11.y);

    // stretch back
    slope.x *= alpha_x;
    slope.y *= alpha_y;

    if(isnan(slope.x))
    {
        if(wi.z > 0) return float3(0.0f, 0.0f, 1.0f);
        else return normalize(float3(wi.x, wi.y, 0.0f));
    }

    return normalize(float3(-slope.x, -slope.y, 1.0f));
}

/************* MICROSURFACE *************/

// masking function
float MIC_GGX_G1(float3 wi, float alpha_x, float alpha_y)
{
    if(wi.z > 0.9999f) return 1.0f;
    if(wi.z <= 0.0f) return 0.0f;

    float lambda = Slope_GGX_Lambda(wi, alpha_x, alpha_y);
    return 1.0f / (1.0f + lambda);
}

// masking function at height h0
float MIC_GGX_G1(float3 wi, float h0, float alpha_x, float alpha_y)
{
    if(wi.z > 0.9999f) return 1.0f;
    if(wi.z <= 0.0f) return 0.0f;
    
    float C1_h0 = HeightGaussianC1(h0);
    float lambda = Slope_GGX_Lambda(wi, alpha_x, alpha_y);
    return pow(C1_h0, lambda);
}

// sample height in outgoing direction
float MIC_SampleHeight(float3 wr, float hr, float alpha_x, float alpha_y, float u)
{
    if(wr.z > 0.9999f) return K_FLT_MAX;
    if(wr.z < -0.9999f) return HeightGaussianInvC1(u * HeightGaussianC1(hr));
    if(abs(wr.z) < 0.0001f) return hr;

    float G1 = MIC_GGX_G1(wr, hr, alpha_x, alpha_y);

    if(u > 1.0f - G1) return K_FLT_MAX; // leave the microsurface

    float lambda = Slope_GGX_Lambda(wr, alpha_x, alpha_y);
    return HeightGaussianInvC1(HeightGaussianC1(hr) / pow(1.0f - u, 1.0f / lambda));
}

// evaluate local phase function
float Conductor_EvalPhaseFunction(float3 wi, float3 wo, float alpha_x, float alpha_y)
{
    // half vector
    float3 wh = normalize(wi + wo);
    if(wh.z < 0.0f) return 0.0f;

    return 0.25f * Slope_D_wi(wi, wh, alpha_x, alpha_y) / dot(wi, wh);
}

// sample local phase function
float3 Conductor_SamplePhaseFunction(float3 wi, float alpha_x, float alpha_y, inout uint seed)
{
    float u1 = RandomFloat01(seed);
    float u2 = RandomFloat01(seed);
    float3 wm = Slope_Sample_D_wi(wi, alpha_x, alpha_y, u1, u2);
    float3 wo = -wi + 2.0f * wm * dot(wi, wm);

    return wo;
}

// evaluate BSDF limited to single scattering
// this is in average equivalent to eval(wi, wo, 1);
float Conductor_EvalSingleScattering(float3 wi, float3 wo, float alpha_x, float alpha_y)
{
    // half vector
    float3 wh = normalize(wi + wo);
    float D = Slope_D(wh, alpha_x, alpha_y);

    // masking-shadowing
    float lambda_wi = Slope_GGX_Lambda(wi, alpha_x, alpha_y);
    float lambda_wo = Slope_GGX_Lambda(wo, alpha_x, alpha_y);
    float G2 = 1.0f / (1.0f + lambda_wi + lambda_wo);

    // BRDF * cos
    return D * G2 / (4.0f * wi.z);
}

// sample BSDF with a random walk
// scatteringOrder is set to the number of bounces computed for this sample
float3 Conductor_Sample(float3 wi, float alpha_x, float alpha_y, inout int scatteringOrder, inout uint seed)
{
    // init
    float3 wr = -wi;
    float hr = 1.0f + HeightGaussianInvC1(0.999f);

    // random walk
    scatteringOrder = 0;
    float u;
    while(scatteringOrder < 16)
    {
        u = RandomFloat01(seed);
        hr = MIC_SampleHeight(wr, hr, alpha_x, alpha_y, u);

        // leave the microsurface ?
        if(hr == K_FLT_MAX) break;
        else scatteringOrder++;

        // next direction
        //example for conductor
        wr = Conductor_SamplePhaseFunction(-wr, alpha_x, alpha_y, seed);

        if(isnan(hr) || isnan(wr.z)) return float3(0, 0, 1);
    }

    return wr;
}

// evaluate BSDF with a random walk (stochastic but unbiased)
// scatteringOrder=0 --> contribution from all scattering events
// scatteringOrder=1 --> contribution from 1st bounce only
// scatteringOrder=2 --> contribution from 2nd bounce only, etc..
float Conductor_Eval(float3 wi, float3 wo, float alpha_x, float alpha_y, int scatteringOrder, inout uint seed)
{
    if(wo.z < 0) return 0;

    // init
    float3 wr = -wi;
    float hr = 1.0f + HeightUniformInvC1(0.999f);
    float sum = 0;

    // random walk
    int current_scatteringOrder = 0;
    float u;
    while(scatteringOrder == 0 || current_scatteringOrder <= scatteringOrder)
    {
        // next height
        u = RandomFloat01(seed);
        hr = MIC_SampleHeight(wr, hr, alpha_x, alpha_y, u);

        // leave the microsurface ?
        if(hr == K_FLT_MAX) break;
        else current_scatteringOrder++;

        // next event estimation
        // example for conductor
        float phaseFunc = Conductor_EvalPhaseFunction(-wr, wo, alpha_x, alpha_y);
        float shadowing = MIC_GGX_G1(wo, hr, alpha_x, alpha_y);
        float I = phaseFunc * shadowing;
        
        if( IsFiniteNumber(I) && (scatteringOrder == 0 || current_scatteringOrder == scatteringOrder))
            sum += I;

        // next direction
        // example for conductor
        wr = Conductor_SamplePhaseFunction(-wr, alpha_x, alpha_y, seed);

        if(isnan(hr) || isnan(wr.z)) return 0.0f;
    }

    return sum;
}

float3 Dielectric_Refract(float3 wi, float3 wm, float eta)
{
    float cos_theta_i = dot(wi, wm);
    float cos_theta_t2 = 1.0f - (1.0f - cos_theta_i * cos_theta_i) / (eta * eta);
    float cos_theta_t = -sqrt(max(0.0f, cos_theta_t2));

    return wm * (dot(wi, wm) / eta + cos_theta_t) - wi / eta;
}

float Dielectric_Fresnel(float3 wi, float3 wm, float eta)
{
    float cos_theta_i = dot(wi, wm);
    float cos_theta_t2 = 1.0f - (1.0f - cos_theta_i * cos_theta_i) / (eta * eta);

    // total internal reflection
    if(cos_theta_t2 <= 0.0f) return 1.0f;

    float cos_theta_t = sqrt(cos_theta_t2);
    float Rs = (cos_theta_i - eta * cos_theta_t) / (cos_theta_i + eta * cos_theta_t);
    float Rp = (eta * cos_theta_i - cos_theta_t) / (eta * cos_theta_i + cos_theta_t);
    float F = 0.5f * (Rs * Rs + Rp * Rp);
    return F;
}

// evaluate local phase function
float Dielectric_EvalPhaseFunction(float3 wi, float3 wo, float m_eta, float alpha_x, float alpha_y, bool wi_outside, bool wo_outside)
{
    float eta = wi_outside ? m_eta : 1.0f / m_eta;

    if(wi_outside == wo_outside) // reflection
    {
        // half vector
        float3 wh = normalize(wi + wo);
        return (wi_outside) ? 
        (0.25f * Slope_D_wi(wi, wh, alpha_x, alpha_y) / dot(wi, wh) * Dielectric_Fresnel(wi, wh, eta)) :
        (0.25f * Slope_D_wi(-wi, -wh, alpha_x, alpha_y) / dot(-wi, -wh) * Dielectric_Fresnel(-wi, -wh, eta));
    }
    else // transmission
    {
        float3 wh = -normalize(wi + wo * eta);
        wh *= (wi_outside) ? (sign(wh.z)) : (-sign(wh.z));

        if(dot(wh, wi) < 0) return 0;

        return (wi_outside) ?
        eta * eta * (1.0f - Dielectric_Fresnel(wi, wh, eta)) * Slope_D_wi(wi, wh, alpha_x, alpha_y) * max(0.0f, -dot(wo, wh)) * 1.0f / pow(dot(wi, wh) + eta * dot(wo, wh), 2.0f) :
        eta * eta * (1.0f - Dielectric_Fresnel(-wi, -wh, eta)) * Slope_D_wi(-wi, -wh, alpha_x, alpha_y) * max(0.0f, -dot(-wo, -wh)) * 1.0f / pow(dot(-wi, -wh) + eta * dot(-wo, -wh), 2.0f);
    }
}

// sample local phase function
float3 Dielectric_SamplePhaseFunction(float3 wi, float m_eta, float alpha_x, float alpha_y, bool wi_outside, inout bool wo_outside, inout uint seed)
{
    float u1 = RandomFloat01(seed);
    float u2 = RandomFloat01(seed);

    float eta = wi_outside ? m_eta : 1.0f / m_eta;

    float3 wm = wi_outside ? Slope_Sample_D_wi(wi, alpha_x, alpha_y, u1, u2) : Slope_Sample_D_wi(-wi, alpha_x, alpha_y, u1, u2);

    float F = Dielectric_Fresnel(wi, wm, eta);

    if(RandomFloat01(seed) < F)
    {// reflection
        return -wi + 2.0f * wm * dot(wi, wm);
    }
    else
    {// refraction
        wo_outside = !wi_outside;
        return normalize(Dielectric_Refract(wi, wm, eta));
    }
}

// evaluate BSDF limited to single scattering
// this is in average equivalent to eval(wi, wo, 1);
float Dielectric_EvalSingleScattering(float3 wi, float3 wo, float m_eta, float alpha_x, float alpha_y)
{
    bool wi_outside = true;
    bool wo_outside = wo.z > 0;

    float eta = m_eta;

    if(wo_outside) // reflection
    {
        // D
        float3 wh = normalize(wi + wo);
        float D = Slope_D(wh, alpha_x, alpha_y);

        // masking-shadowing
        float lambda_wi = Slope_GGX_Lambda(wi, alpha_x, alpha_y);
        float lambda_wo = Slope_GGX_Lambda(wo, alpha_x, alpha_y);
        float G2 = 1.0f / (1.0f + lambda_wi + lambda_wo);

        // BRDF
        return Dielectric_Fresnel(wi, wh, eta) * D * G2 / (4.0f * wi.z);
    }
    else // refraction
    {
        // D
        float3 wh = -normalize(wi + wo * eta);
        if(eta < 1.0f) wh = -wh;
        float D = Slope_D(wh, alpha_x, alpha_y);

        // G2
        float lambda_wi = Slope_GGX_Lambda(wi, alpha_x, alpha_y);
        float lambda_wo = Slope_GGX_Lambda(-wo, alpha_x, alpha_y);
        float G2 = beta(1.0f + lambda_wi, 1.0f + lambda_wo);

        // BSDF
        return max(0.0f, dot(wi, wh)) * max(0.0f, -dot(wo, wh)) * 1.0f / wi.z * eta * eta * (1.0f - Dielectric_Fresnel(wi, wh, eta)) * G2 * D / pow(dot(wi, wh) + eta * dot(wo, wh), 2.0f);
    }
}

// sample final BSDF with a random walk
// scatteringOrder is set to the number of bounces computed for this sample
float3 Dielectric_Sample(float3 wi, float m_eta, float alpha_x, float alpha_y, inout int scatteringOrder, inout uint seed)
{
    // init
    float3 wr = -wi;
    float hr = 1.0f + HeightGaussianInvC1(0.999f);
    bool outside = true;

    // random walk;
    scatteringOrder = 0;
    while(scatteringOrder < 16)
    {
        // next height
        float u = RandomFloat01(seed);
        hr = (outside) ? MIC_SampleHeight(wr, hr, alpha_x, alpha_y, u) : -MIC_SampleHeight(-wr, -hr, alpha_x, alpha_y, u);

        // leave the microsurface ?
        if(hr == K_FLT_MAX || hr == -K_FLT_MAX) break;
        else scatteringOrder++;

        // next direction
        wr = Dielectric_SamplePhaseFunction(-wr, m_eta, alpha_x, alpha_y, outside, outside, seed);

        if(isnan(hr) || isnan(wr.z)) return float3(0, 0, 1);
    }

    return wr;
}

// evaluate BSDF with a random walk (stochastic but unbiased)
// scatteringOrder=0 --> contribution from all scattering events
// scatteringOrder=1 --> contribution from 1st bounce only
// scatteringOrder=2 --> contribution from 2nd bounce only, etc..
float Dielectric_Eval(float3 wi, float3 wo, float m_eta, float alpha_x, float alpha_y, int scatteringOrder, inout uint seed)
{
    // init
    float3 wr = -wi;
    float hr = 1.0f + HeightGaussianInvC1(0.999f);
    bool outside = true;

    float sum = 0.0f;

    // random walk
    int current_scatteringOrder = 0;
    while(scatteringOrder == 0 || current_scatteringOrder <= scatteringOrder)
    {
        // next height
        float u = RandomFloat01(seed);
        hr = (outside) ? MIC_SampleHeight(wr, hr, alpha_x, alpha_y, u) : -MIC_SampleHeight(-wr, -hr, alpha_x, alpha_y, u);

        // leave the microsurface ?
        if(hr == K_FLT_MAX || hr == - K_FLT_MAX) break;
        else current_scatteringOrder++;

        // next event estimation
        float phaseFunc = Dielectric_EvalPhaseFunction(-wr, wo, m_eta, alpha_x, alpha_y, outside, (wo.z > 0));
        float shadowing = (wo.z > 0) ? MIC_GGX_G1(wo, hr, alpha_x, alpha_y) : MIC_GGX_G1(-wo, -hr, alpha_x, alpha_y);
        float I = phaseFunc * shadowing;

        if(IsFiniteNumber(I) && (scatteringOrder == 0 || current_scatteringOrder == scatteringOrder)) sum += I;

        // next direction
        wr = Dielectric_SamplePhaseFunction(-wr, m_eta, alpha_x, alpha_y, outside, outside, seed);

        if(isnan(hr) || isnan(wr.z)) return 0.0f;
    }

    return sum;
}

// sample local phase function
float3 Diffuse_SamplePhaseFunction(float3 wi, float alpha_x, float alpha_y, inout uint seed)
{
    float u1 = RandomFloat01(seed);
    float u2 = RandomFloat01(seed);
    float u3 = RandomFloat01(seed);
    float u4 = RandomFloat01(seed);

    float3 wm = Slope_Sample_D_wi(wi, alpha_x, alpha_y, u1, u2);

    // sample diffuse reflection
    float3 w1, w2;
    BuildOrthonormalBasis(w1, w2, wm);

    float r1 = 2.0f * u3 - 1.0f;
    float r2 = 2.0f * u4 - 1.0f;

    float phi, r;
    if(r1 == 0 && r2 == 0)
    {
        r = phi = 0;
    }
    else if(r1 * r1 > r2 * r2)
    {
        r = r1;
        phi = (K_PI / 4.0f) * (r2 / r1);
    }else
    {
        r = r2;
        phi = (K_PI / 2.0f) - (r1 / r2) * (K_PI / 4.0f);
    }

    float x = r * cos(phi);
    float y = r * sin(phi);
    float z = sqrt(max(0.0f, 1.0f - x * x - y * y));
    float3 wo = x * w1 + y * w2 + z * wm;
    
    return wo;
}

// evaluate local phase function 
float Diffuse_EvalPhaseFunction(float3 wi, float3 wo, float alpha_x, float alpha_y, inout uint seed)
{
    float u1 = RandomFloat01(seed);
    float u2 = RandomFloat01(seed);
    float3 wm = Slope_Sample_D_wi(wi, alpha_x, alpha_y, u1, u2);

    return 1.0f / K_PI * max(0.0f, dot(wo, wm));
}

// evaluate BSDF limited to single scattering 
// this is in average equivalent to eval(wi, wo, 1);
float Diffuse_EvalSingleScattering(float3 wi, float3 wo, float alpha_x, float alpha_y, inout uint seed)
{
    float u1 = RandomFloat01(seed);
    float u2 = RandomFloat01(seed);
    float3 wm = Slope_Sample_D_wi(wi, alpha_x, alpha_y, u1, u2);

    // shadowing-masking
    float lambda_wi = Slope_GGX_Lambda(wi, alpha_x, alpha_y);
    float lambda_wo = Slope_GGX_Lambda(wo, alpha_x, alpha_y);
    float G2 = (1.0f + lambda_wi) / (1.0f + lambda_wi + lambda_wo);

    return 1.0f / K_PI * max(0.0f, dot(wm, wo)) * G2;
}

/************* Sample GGX VNDF Hemisphere 2018 *************/
float3 SampleGGXVNDF_Hemisphere_2018(float3 Vh, float u1, float u2)
{
    // orthonormal basis (with special case if cross product is 0)
    float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
    float3 T1 = lensq > 0 ? float3(-Vh.y, Vh.x, 0) * rcp(sqrt(lensq)) : float3(1, 0, 0);
    float3 T2 = cross(Vh, T1);

    // parameterization of the cross section
    float r = sqrt(u1);
    float phi = K_TWO_PI * u2;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi);
    float s = 0.5 * (1.0 + Vh.z);
    t2 = (1.0 - s) * sqrt(1.0 - t1 * t1) + s * t2;

    // reprojection onto hemisphere
    float3 Nh = t1 * T1 + t2 * T2 + sqrt(max(0.0, 1.0 - t1 * t1 - t2 * t2)) * Vh;

    return Nh;
}

/************* Sample GGX VNDF Cap-based 2023 *************/
float3 SampleGGXVNDF_Cap_2023(float3 Vh, float u1, float u2)
{
    // sample a spherical cap in (-wi.z, 1]
    float phi = K_TWO_PI * u1;
    float z = mad(1.0f - u2, 1.0f + Vh.z, -Vh.z);
    float sinTheta = sqrt(clamp(1.0f - z * z, 0.0f, 1.0f));
    float x = sinTheta * cos(phi);
    float y = sinTheta * sin(phi);
    float3 c = float3(x, y, z);

    // compute halfway direction;
    float3 Nh = c + Vh;

    return Nh;
}

/************* Sample GGX VNDF Cap-based 2023 - PDF *************/
float GGXVNDF_Cap_2023_PDF(float3 i, float3 o, float alpha_x, float alpha_y)
{
    float3 m = normalize(i + o);
    float ndf = Slope_D(m, alpha_x, alpha_y);
    float2 ai = float2(alpha_x * i.x, alpha_y * i.y);
    float len2 = dot(ai, ai);
    float t = sqrt(len2 + i.z * i.z);
    return ndf * (t - i.z) / (2.0f * len2);
}

/************* Sample GGX VNDF Bounded 2023 *************/
float3 SampleGGXVNDF_Cap_Bounded_2023(float3 Ve, float3 Vh, float alpha_x, float alpha_y, float u1, float u2)
{
    // sample a spherical cap in (-wi.z, 1]
    float phi = K_TWO_PI * u1;

    float a = saturate(min(alpha_x, alpha_y)); // Eq. 6
    float s = 1.0f + length(float2(Ve.x, Ve.y)); // Omit sgn for a<=1
    float a2 = a * a; float s2 = s * s;
    float k = (1.0f - a2) * s2 / (s2 + a2 * Ve.z * Ve.z); // Eq. 5
    float b = Ve.z > 0 ? k * Vh.z : Vh.z;

    float z = mad(1.0f - u2, 1.0f + b, -b);
    float sinTheta = sqrt(clamp(1.0f - z * z, 0.0f, 1.0f));
    float x = sinTheta * cos(phi);
    float y = sinTheta * sin(phi);
    float3 o_std = float3(x, y, z);

    // compute halfway direction;
    float3 Nh = o_std + Vh;

    return Nh;
}

/************* Sample GGX VNDF Bounded 2023 - PDF *************/
float GGXVNDF_Cap_Bounded_2023_PDF(float3 i, float3 o, float alpha_x, float alpha_y)
{
    float3 m = normalize(i + o);
    float ndf = Slope_D(m, alpha_x, alpha_y);
    float2 ai = float2(alpha_x * i.x, alpha_y * i.y);
    float len2 = dot(ai, ai);
    float t = sqrt(len2 + i.z * i.z);
    if(i.z >= 0.0f)
    {
        float a = saturate(min(alpha_x, alpha_y));
        float s = 1.0f + length(float2(i.x , i.y));
        float a2 = a * a; float s2 = s * s;
        float k = (1.0f - a2) * s2 / (s2 + a2 * i.z * i.z);
        return ndf / (2.0f * (k * i.z + t)); // Eq. 8 * || dm / do ||
    }
    return ndf * (t - i.z) / (2.0f * len2); // = Eq. 7 * || dm / do ||
}


float GGXVNDF_D_Ve(float3 Ve, float3 Ne, float alpha_x, float alpha_y)
{
    float G1 = MIC_GGX_G1(Ne, alpha_x, alpha_y);
    float D = Slope_D(Ne, alpha_x, alpha_y);

    return G1 * max(0.0, dot(Ne, Ve)) * D / Ve.z;
}

float GGXVNDF_PDF(float3 Ve, float3 Ne, float alpha_x, float alpha_y)
{
    float D_Ve = GGXVNDF_D_Ve(Ve, Ne, alpha_x, alpha_y);
    return 0.25f * D_Ve / dot(Ve, Ne);
}

float3 SampleGGXVNDF(float3 Ve, float alpha_x, float alpha_y, float u1, float u2)
{
    // warp to the hemisphere configuration
    float3 Vh = normalize(float3(alpha_x * Ve.x, alpha_y * Ve.y, Ve.z));

    // sample the hemisphere    
    float3 Nh = SampleGGXVNDF_Hemisphere_2018(Vh, u1, u2);
    //float3 Nh = SampleGGXVNDF_Cap_2023(Vh, u1, u2);
    //float3 Nh = SampleGGXVNDF_Cap_Bounded_2023(Ve, Vh, alpha_x, alpha_y, u1, u2);

    // warp back to the ellipsoid configuration
    float3 Ne = normalize(float3(alpha_x * Nh.x, alpha_y * Nh.y, max(0.0, Nh.z)));

    return Ne;
}

float3 EvalGGXVNDF(float3 Ve, float3 fresnel, float alpha_x, float alpha_y, inout float3 Li, inout uint seed)
{
    float u1 = RandomFloat01(seed);
    float u2 = RandomFloat01(seed);
    float3 Ne = SampleGGXVNDF(Ve, alpha_x, alpha_y, u1, u2);
    Li = reflect(-Ve, Ne);

    float lambda_wi = Slope_GGX_Lambda(Li, alpha_x, alpha_y);
    float lambda_wo = Slope_GGX_Lambda(Ve, alpha_x, alpha_y);

    // BRDF * Ve.z / pdf = F * D * G2 / (4 * cos_theta_v * cos_theta_l) * Ve.z / pdf = F * G2 / G1
    // when G2 is height-correlated, G2 / G1 = (1 + lambda_wo) / (1 + lambda_wi + lambda_wo)
    return fresnel * (1.0f + lambda_wo) / (1.0f + lambda_wi + lambda_wo);
}

float3 TestEvalGGXVNDF(float3 Ve, float3 fresnel, float alpha_x, float alpha_y, inout float3 Li, inout uint seed, inout float pdf)
{
    float u1 = RandomFloat01(seed);
    float u2 = RandomFloat01(seed);
    float3 Vh = normalize(float3(alpha_x * Ve.x, alpha_y * Ve.y, Ve.z));
    float3 Ne = SampleGGXVNDF_Cap_Bounded_2023(Ve, Vh, alpha_x, alpha_y, u1, u2);
    Li = reflect(-Ve, Ne);

    float lambda_wi = Slope_GGX_Lambda(Li, alpha_x, alpha_y);
    float lambda_wo = Slope_GGX_Lambda(Ve, alpha_x, alpha_y);

    pdf = GGXVNDF_Cap_Bounded_2023_PDF(Li, Ve, alpha_x, alpha_y);
    return fresnel * (1.0f + lambda_wo) / (1.0f + lambda_wi + lambda_wo);
}

/************* OTHERS *************/

float3 SampleCosineHemisphere(float3 normal, inout uint state)
{
    return normalize(normal + RandomUnitVector(state));
}


/** Evaluates the GGX (Trowbridge-Reitz) normal distribution function (D).

    Introduced by Trowbridge and Reitz, "Average irregularity representation of a rough surface for ray reflection", Journal of the Optical Society of America, vol. 65(5), 1975.
    See the correct normalization factor in Walter et al. https://dl.acm.org/citation.cfm?id=2383874
    We use the simpler, but equivalent expression in Eqn 19 from http://blog.selfshadow.com/publications/s2012-shading-course/hoffman/s2012_pbs_physics_math_notes.pdf

    For microfacet models, D is evaluated for the direction h to find the density of potentially active microfacets (those for which microfacet normal m = h).
    The 'alpha' parameter is the standard GGX width, e.g., it is the square of the linear roughness parameter in Disney's BRDF.
    Note there is a singularity (0/0 = NaN) at NdotH = 1 and alpha = 0, so alpha should be clamped to some epsilon.

    \param[in] alpha GGX width parameter (should be clamped to small epsilon beforehand).
    \param[in] cosTheta Dot product between shading normal and half vector, in positive hemisphere.
    \return D(h)
*/

float evalNdfGGX(float alpha, float cosTheta)
{
    float a2 = alpha * alpha;
    float d = ((cosTheta * a2 - cosTheta) * cosTheta + 1);
    return a2 / (d * d * K_PI);
}

/** Evaluates the PDF for sampling the GGX normal distribution function using Walter et al. 2007's method.
    See https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf

    \param[in] alpha GGX width parameter (should be clamped to small epsilon beforehand).
    \param[in] cosTheta Dot product between shading normal and half vector, in positive hemisphere.
    \return D(h) * cosTheta
*/

float evalPdfGGX_NDF(float alpha, float cosTheta)
{
    return evalNdfGGX(alpha, cosTheta) * cosTheta;
}

/** Samples the GGX (Trowbridge-Reitz) normal distribution function (D) using Walter et al. 2007's method.
    Note that the sampled half vector may lie in the negative hemisphere. Such samples should be discarded.
    See Eqn 35 & 36 in https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf
    See Listing A.1 in https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf

    \param[in] alpha GGX width parameter (should be clamped to small epsilon beforehand).
    \param[in] u Uniform random number (2D).
    \param[out] pdf Sampling probability.
    \return Sampled half vector in local space.
*/
float3 sampleGGX_NDF(float alpha, float2 u, out float pdf)
{
    float alphaSqr = alpha * alpha;
    float phi = u.y * (2 * K_PI);
    float tanThetaSqr = alphaSqr * u.x / (1 - u.x);
    float cosTheta = 1 / sqrt(1 + tanThetaSqr);
    float r = sqrt(max(1 - cosTheta * cosTheta, 0));

    pdf = evalPdfGGX_NDF(alpha, cosTheta);
    return float3(cos(phi) * r, sin(phi) * r, cosTheta);
}

/** Evaluates the Smith masking function (G1) for the GGX normal distribution.
    See Eq 34 in https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf

    The evaluated direction is assumed to be in the positive hemisphere relative the half vector.
    This is the case when both incident and outgoing direction are in the same hemisphere, but care should be taken with transmission.

    \param[in] alphaSqr Squared GGX width parameter.
    \param[in] cosTheta Dot product between shading normal and evaluated direction, in the positive hemisphere.
*/

float evalG1GGX(float alphaSqr, float cosTheta)
{
    if (cosTheta <= 0) return 0;
    float cosThetaSqr = cosTheta * cosTheta;
    float tanThetaSqr = max(1 - cosThetaSqr, 0) / cosThetaSqr;
    return 2 / (1 + sqrt(1 + alphaSqr * tanThetaSqr));
}

/** Evaluates the PDF for sampling the GGX distribution of visible normals (VNDF).
    See http://jcgt.org/published/0007/04/01/paper.pdf

    \param[in] alpha GGX width parameter (should be clamped to small epsilon beforehand).
    \param[in] wi Incident direction in local space, in the positive hemisphere.
    \param[in] h Half vector in local space, in the positive hemisphere.
    \return D_V(h) = G1(wi) * D(h) * max(0,dot(wi,h)) / wi.z
*/
float evalPdfGGX_VNDF(float alpha, float3 wi, float3 h)
{
    float G1 = evalG1GGX(alpha * alpha, wi.z);
    float D = evalNdfGGX(alpha, h.z);
    float pdf = G1 * D * max(0.f, dot(wi, h)) / wi.z;
    //if(isnan(D)) pdf = 13;
    return pdf;
}

/** Samples the GGX (Trowbridge-Reitz) using the distribution of visible normals (VNDF).
    The GGX VDNF yields significant variance reduction compared to sampling of the GGX NDF.
    See http://jcgt.org/published/0007/04/01/paper.pdf

    \param[in] alpha Isotropic GGX width parameter (should be clamped to small epsilon beforehand).
    \param[in] wi Incident direction in local space, in the positive hemisphere.
    \param[in] u Uniform random number (2D).
    \param[out] pdf Sampling probability.
    \return Sampled half vector in local space, in the positive hemisphere.
*/
float3 sampleGGX_VNDF(float alpha, float3 wi, float2 u, out float pdf)
{
    float alpha_x = alpha, alpha_y = alpha;

    // Transform the view vector to the hemisphere configuration.
    float3 Vh = normalize(float3(alpha_x * wi.x, alpha_y * wi.y, wi.z));

    // Construct orthonormal basis (Vh,T1,T2).
    float3 T1 = (Vh.z < 0.9999f) ? normalize(cross(float3(0, 0, 1), Vh)) : float3(1, 0, 0); // TODO: fp32 precision
    float3 T2 = cross(Vh, T1);

    // Parameterization of the projected area of the hemisphere.
    float r = sqrt(u.x);
    float phi = (2.f * K_PI) * u.y;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi);
    float s = 0.5f * (1.f + Vh.z);
    t2 = (1.f - s) * sqrt(1.f - t1 * t1) + s * t2;

    // Reproject onto hemisphere.
    float3 Nh = t1 * T1 + t2 * T2 + sqrt(max(0.f, 1.f - t1 * t1 - t2 * t2)) * Vh;

    // Transform the normal back to the ellipsoid configuration. This is our half vector.
    float3 h = normalize(float3(alpha_x * Nh.x, alpha_y * Nh.y, max(0.f, Nh.z)));

    pdf = evalPdfGGX_VNDF(alpha, wi, h);
    return h;
}

/** Evaluates the Smith lambda function for the GGX normal distribution.
    See Eq 72 in http://jcgt.org/published/0003/02/03/paper.pdf

    \param[in] alphaSqr Squared GGX width parameter.
    \param[in] cosTheta Dot product between shading normal and the evaluated direction, in the positive hemisphere.
*/

float evalLambdaGGX(float alphaSqr, float cosTheta)
{
    if (cosTheta <= 0) return 0;
    float cosThetaSqr = cosTheta * cosTheta;
    float tanThetaSqr = max(1 - cosThetaSqr, 0) / cosThetaSqr;
    return 0.5 * (-1 + sqrt(1 + alphaSqr * tanThetaSqr));
}

/** Evaluates the separable form of the masking-shadowing function for the GGX normal distribution, using Smith's approximation.
    See Eq 98 in http://jcgt.org/published/0003/02/03/paper.pdf

    \param[in] alpha GGX width parameter (should be clamped to small epsilon beforehand).
    \param[in] cosThetaI Dot product between shading normal and incident direction, in positive hemisphere.
    \param[in] cosThetaO Dot product between shading normal and outgoing direction, in positive hemisphere.
    \return G(cosThetaI, cosThetaO)
*/

float evalMaskingSmithGGXSeparable(float alpha, float cosThetaI, float cosThetaO)
{
    float alphaSqr = alpha * alpha;
    float lambdaI = evalLambdaGGX(alphaSqr, cosThetaI);
    float lambdaO = evalLambdaGGX(alphaSqr, cosThetaO);
    return 1 / ((1 + lambdaI) * (1 + lambdaO));
}

/** Evaluates the height-correlated form of the masking-shadowing function for the GGX normal distribution, using Smith's approximation.
    See Eq 99 in http://jcgt.org/published/0003/02/03/paper.pdf

    Eric Heitz recommends using it in favor of the separable form as it is more accurate and of similar complexity.
    The function is only valid for cosThetaI > 0 and cosThetaO > 0  and should be clamped to 0 otherwise.

    \param[in] alpha GGX width parameter (should be clamped to small epsilon beforehand).
    \param[in] cosThetaI Dot product between shading normal and incident direction, in positive hemisphere.
    \param[in] cosThetaO Dot product between shading normal and outgoing direction, in positive hemisphere.
    \return G(cosThetaI, cosThetaO)
*/

float evalMaskingSmithGGXCorrelated(float alpha, float cosThetaI, float cosThetaO)
{
    float alphaSqr = alpha * alpha;
    float lambdaI = evalLambdaGGX(alphaSqr, cosThetaI);
    float lambdaO = evalLambdaGGX(alphaSqr, cosThetaO);
    return 1 / (1 + lambdaI + lambdaO);
}

/** Evaluates the Fresnel term using Schlick's approximation.
    Introduced in http://www.cs.virginia.edu/~jdl/bib/appearance/analytic%20models/schlick94b.pdf

    The Fresnel term equals f0 at normal incidence, and approaches f90=1.0 at 90 degrees.
    The formulation below is generalized to allow both f0 and f90 to be specified.

    \param[in] f0 Specular reflectance at normal incidence (0 degrees).
    \param[in] f90 Reflectance at orthogonal incidence (90 degrees), which should be 1.0 for specular surface reflection.
    \param[in] cosTheta Cosine of angle between microfacet normal and incident direction (LdotH).
    \return Fresnel term.
*/

float3 evalFresnelSchlick(float3 f0, float3 f90, float cosTheta)
{
    return f0 + (f90 - f0) * pow(max(1 - cosTheta, 0), 5); // Clamp to avoid NaN if cosTheta = 1+epsilon
}

float evalFresnelSchlick(float f0, float f90, float cosTheta)
{
    return f0 + (f90 - f0) * pow(max(1 - cosTheta, 0), 5); // Clamp to avoid NaN if cosTheta = 1+epsilon
}

float3 EvalGGXVNDF(const float3 wi, const float3 wo, float3 albedo, float alpha)
{
    if(min(wi.z, wo.z) < 1e-5) return float3(0, 0, 0);

    float3 h = normalize(wi + wo);
    float wiDotH = dot(wi, h);

    float D = evalNdfGGX(alpha, h.z);
    float G = evalMaskingSmithGGXCorrelated(alpha, wi.z, wo.z);
    float3 F = evalFresnelSchlick(albedo, 1.f, wiDotH);

    return F * D * G * 0.25f / wi.z;
}

#endif