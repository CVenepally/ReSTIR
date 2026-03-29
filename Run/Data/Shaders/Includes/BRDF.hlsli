#pragma once

#include "RTUtils.hlsli"

#define BRDF_DIFFUSE 0
#define BRDF_SPECULAR 1

static const float PI                   = 3.14159265f;
static const float ONE_OVER_PI          = 1.f / PI;
static const float ONE_OVER_TWO_PI      = 1.f / (2*PI);

// F0 is Base Reflectivity when a object is viewed head on (or at grazing angles)
// Every surface has some amount of reflectance, even the ones that have 0 metalness to them.
// Minimum is 2%. Some engines go with 4%. 
static const float MIN_DIELECTRIC_F0    = 0.04;

struct BrdfData
{
    float3  m_baseColor;
    float   m_roughness;
    float   m_metalness;
    
    float3  m_pixelNormal;
    float3  m_pixelToLight;
    float3  m_lightToPixel;
    float3  m_rayDirection;
    float3  m_viewVector;
    float3  m_halfVector;
    
    float3  m_surfaceNormal;
    float3  m_surfaceTangent;
    float3  m_surfaceBitangent;
    
    float3  m_diffuseReflectance;
    float3  m_F0;
    float3  m_F;
};

//-------------------------------------------------------------------------------------------------------------------------------------
// Math Utils
//-------------------------------------------------------------------------------------------------------------------------------------
float AngleBetweenVectors(float3 a, float3 b)
{
    float dotProduct = dot(normalize(a), normalize(b));
    
    return acos(saturate(dotProduct));
}

//-------------------------------------------------------------------------------------------------------------------------------------
float3 GetVectorInTBNSpace(float3 vec, float3 tangent, float3 bitangent, float3 normal)
{
    return float3(dot(vec, tangent), dot(vec, bitangent), dot(vec, normal));
}

//-------------------------------------------------------------------------------------------------------------------------------------
float3 GetVectorInWorldSpace(float3 vec, float3 tangent, float3 bitangent, float3 normal)
{
    return vec.x * tangent + vec.y * bitangent + vec.z * normal;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float4 GetRotationToZAxis(float3 input)
{
	// Handle special case when input is exact or near opposite of (0, 0, 1)
    if (input.z < -0.99999f)
        return float4(1.0f, 0.0f, 0.0f, 0.0f);

    return normalize(float4(input.y, -input.x, 0.0f, 1.0f + input.z));
}

//-------------------------------------------------------------------------------------------------------------------------------------
float4 invertRotation(float4 q)
{
    return float4(-q.x, -q.y, -q.z, q.w);
}

//-------------------------------------------------------------------------------------------------------------------------------------
float3 rotatePoint(float4 q, float3 v)
{
    const float3 qAxis = float3(q.x, q.y, q.z);
    return 2.0f * dot(qAxis, v) * qAxis + (q.w * q.w - dot(qAxis, qAxis)) * v + 2.0f * q.w * cross(qAxis, v);
}


//-------------------------------------------------------------------------------------------------------------------------------------
// Utils
//-------------------------------------------------------------------------------------------------------------------------------------
float3 ComputeDiffuseReflectance(float3 baseColor, float metalness)
{
    return baseColor.rgb * (1.f - metalness);

}

//-------------------------------------------------------------------------------------------------------------------------------------
float Luminance(float3 rgb)
{
    return dot(rgb, float3(0.2126f, 0.7152f, 0.0722f));
}
//-------------------------------------------------------------------------------------------------------------------------------------
// SpecularF0
float3 ComputeSpecularBaseReflectivity(float3 baseColor, float metalness)
{
    return lerp(float3(MIN_DIELECTRIC_F0.xxx), baseColor, metalness);
}

//Roughness Conversions-------------------------------------------------------------------------------------------------------------------
float GetLinearRoughness(float roughness) // alpha (α)
{
    return roughness * roughness;
}

//-------------------------------------------------------------------------------------------------------------------------------------
// In the metallic-roughness workflow (commly used work flow for PBR) there is no term or texture that specifies specularity/shininess directly
// This is used to to convert Beckmann Roughness (alpha = r*r) into shininess.
float ConvertAlphaToPhongShininess(float alpha)
{  
   return (2.0f / min(0.9999f, max(0.0002f, (alpha * alpha)))) - 2.0f;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float GetOrenNayarRoughness(float roughness) // sigma (σ)
{
    float alpha         = GetLinearRoughness(roughness);
    float arctanAlpha   = atan(alpha);
    
    return arctanAlpha * 1.f / 0.7071067f;
}

//-------------------------------------------------------------------------------------------------------------------------------------
// Since Phong isn't physically accurate to modern standards, this was a proposed change to make it comply with the rules of BRDF (energy conservation to be specific)
float PhongNormalizationTerm(float shininess)
{
    return (1.0f + shininess) * ONE_OVER_TWO_PI;
}

//-------------------------------------------------------------------------------------------------------------------------------------
// MICROFACET SPECULAR MODEL UTILS
//-------------------------------------------------------------------------------------------------------------------------------------
// Needs 3 Terms
// F - Fresnel Term
// G - Geometric Attenuation - Attuenation of reflected light due to the geomettry of microsurface that could occur when other microfacets block the reflected light (Changes with NDFs)
// D - Normal Distribution Function - How much light is reflected between given L and V assuming nothing is occluded my other microfacets. (BeckmannNDF, GGXNDF)

//-------------------------------------------------------------------------------------------------------------------------------------
// NORMAL DISTRIBUTION FUNCTIONS (D-Term)
//-------------------------------------------------------------------------------------------------------------------------------------
float ComputeBeckmannNDF(BrdfData data)
{
    float3 halfVector = data.m_halfVector;
    float3 normal = data.m_pixelNormal;
    
    float normalToHalfVectorAngle = saturate(dot(normal, halfVector));// Cos theta h in the formula
    normalToHalfVectorAngle = max(normalToHalfVectorAngle, EPS);
    
    float linearRoughness = GetLinearRoughness(data.m_roughness);
    
    float alphaSquared = max(0.0001f, linearRoughness * linearRoughness);
    
    float normalToHalfVectorP2 = normalToHalfVectorAngle * normalToHalfVectorAngle;
    float normalToHalfVectorP4 = normalToHalfVectorP2 * normalToHalfVectorP2;
    
    normalToHalfVectorP2 = max(normalToHalfVectorP2, EPS);
    normalToHalfVectorP4 = max(normalToHalfVectorP4, EPS);
    
    float numerator = exp((normalToHalfVectorP2 - 1) / (alphaSquared * normalToHalfVectorP2));
    float denom = PI * alphaSquared * normalToHalfVectorP4;
    
    return numerator / denom;   
}

//-------------------------------------------------------------------------------------------------------------------------------------
float ComputeGGXNDF(BrdfData data)
{
    float alpha = GetLinearRoughness(data.m_roughness);
    float alphaSquared = alpha * alpha;
    
    float normalToHalfVectorAngle = dot(data.m_pixelNormal, data.m_halfVector); // Cos theta h in the formula
    float normalToHalfVectorP2      = normalToHalfVectorAngle * normalToHalfVectorAngle;

    float slope = ((alphaSquared - 1) * normalToHalfVectorP2) + 1; // This is what gives the specular lobe (reflection) the shape.
    
    slope = max(slope, EPS);
    
    float denom = PI *  slope * slope;
    
    return alphaSquared / denom;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float Smith_G1_GGX(float alpha, float NdotS, float alphaSquared, float NdotSSquared)
{
    NdotSSquared = max(NdotSSquared, 1e-6f);
    return 2.0f / (sqrt(((alphaSquared * (1.0f - NdotSSquared)) + NdotSSquared) / NdotSSquared) + 1.0f);
}

//-------------------------------------------------------------------------------------------------------------------------------------
float Smith_G2_Over_G1_HeightCorrelated(float alpha, float nDotL, float nDotV)
{
    float G1V = Smith_G1_GGX(alpha, nDotV, alpha * alpha, nDotV * nDotV);
    float G1L = Smith_G1_GGX(alpha, nDotL, alpha * alpha, nDotL * nDotL);
    return G1L / (G1V + G1L - G1V * G1L);
}

//-------------------------------------------------------------------------------------------------------------------------------------
// Geometric Attenuation (G-Term)
//-------------------------------------------------------------------------------------------------------------------------------------
// #ToDo: Implement other G-Term functions as well. For time reasons, going with Frostbite's optimized GGX
float SmithG2_GGX_HeightCorrelated_Frostbite(float alphaSquared, float NdotL, float NdotV)
{
    float a = NdotV * sqrt(alphaSquared + NdotL * (NdotL - alphaSquared * NdotL));
    float b = NdotL * sqrt(alphaSquared + NdotV * (NdotV - alphaSquared * NdotV));
    return 0.5f / (a + b);
}

//-------------------------------------------------------------------------------------------------------------------------------------
// FRESNEL TERM (FRESNEL-SCHLIKK) -> F-Term
//-------------------------------------------------------------------------------------------------------------------------------------
// #ToDo: READ THE BRDF CRASH COURSE THING AGAIN TO GET BETTER UNDERSTANDING
float ShadowedF90(float3 F0)
{
    const float t = (1.0f / MIN_DIELECTRIC_F0);
    return min(1.0f, t * Luminance(F0));
}

//-------------------------------------------------------------------------------------------------------------------------------------
float3 ComputeFresnelSchlick(float3 f0, float f90, float NdotS)
{
    return f0 + (f90 - f0) * pow(1.0f - NdotS, 5.0f);
}

//-------------------------------------------------------------------------------------------------------------------------------------
// DIFFUSE BRDFs
//-------------------------------------------------------------------------------------------------------------------------------------
float3 CalculateDiffuse_Lambert(BrdfData data)
{
    return data.m_diffuseReflectance * (dot(data.m_pixelNormal, data.m_pixelToLight) * ONE_OVER_PI);
}

//-------------------------------------------------------------------------------------------------------------------------------------
float3 CalculateDiffuse_OrenNayar(BrdfData data)
{
    float3 diffuseReflectance = ComputeDiffuseReflectance(data.m_baseColor, data.m_metalness);
    
    float orenNayarRoughness = GetOrenNayarRoughness(data.m_roughness);
    
    float sigmaSquared = orenNayarRoughness * orenNayarRoughness;
    
    float A = 1.f - (0.5f * (sigmaSquared / (sigmaSquared + 0.33f)));
    float B = 0.45f * (sigmaSquared / (sigmaSquared + 0.03f));
    
    float angleBetweenLightVectorAndNormal = acos(dot(data.m_pixelNormal, data.m_pixelToLight)); // thetaL term
    float angleBetweenViewVectorAndNormal = acos(dot(data.m_pixelNormal, data.m_viewVector)); // thetaV term
    
    float alpha = max(angleBetweenLightVectorAndNormal, angleBetweenViewVectorAndNormal);
    float beta  = min(angleBetweenLightVectorAndNormal, angleBetweenViewVectorAndNormal);
    
    float3 projectedLightVector = data.m_pixelToLight - dot(data.m_pixelNormal, data.m_pixelToLight) * data.m_pixelNormal;
    float3 projectedViewVector = data.m_viewVector - dot(data.m_pixelNormal, data.m_viewVector) * data.m_pixelNormal;
    
    float angleBetweenProjectedLightVectorAndNormal = acos(dot(data.m_pixelNormal, projectedLightVector)); // phiL term
    float angleBetweenProjectedViewVectorAndNormal = acos(dot(data.m_pixelNormal, projectedViewVector)); // phiV term
    float cosinePhiDiff = cos(angleBetweenProjectedViewVectorAndNormal - angleBetweenProjectedLightVectorAndNormal);
    
    return (diffuseReflectance * ONE_OVER_PI) * (A + (B * max(0, cosinePhiDiff) * sin(alpha) * tan(beta)));

}

//-------------------------------------------------------------------------------------------------------------------------------------
// SPECULAR BRDFs
//-------------------------------------------------------------------------------------------------------------------------------------
float3 CalculateSpecular_Phong(BrdfData data)
{
    float   alpha                 = data.m_roughness * data.m_roughness;
    float   shininess             = ConvertAlphaToPhongShininess(alpha);
    float3  specularReflectance   = ComputeSpecularBaseReflectivity(data.m_baseColor, data.m_metalness);
    float3 reflectedRay = reflect(data.m_lightToPixel, data.m_pixelNormal);
    
    return specularReflectance * (PhongNormalizationTerm(shininess) * pow(max(0.f, dot(reflectedRay, data.m_viewVector)), shininess) * dot(data.m_pixelNormal, data.m_pixelToLight));
}

//-------------------------------------------------------------------------------------------------------------------------------------
float3 CalculateSpecular_MicroFacet(BrdfData data)
{
    float D = ComputeGGXNDF(data);
    
    float alpha = GetLinearRoughness(data.m_roughness);
    float alphaSquared = alpha * alpha;
    
    float NdotL = saturate(dot(data.m_pixelNormal, data.m_pixelToLight));
    float NdotV = saturate(dot(data.m_pixelNormal, data.m_viewVector));
    
    float G2 = SmithG2_GGX_HeightCorrelated_Frostbite(alphaSquared, NdotL, NdotV);
    
    float3 F0 = ComputeSpecularBaseReflectivity(data.m_baseColor, data.m_metalness);
    
    float3 F = ComputeFresnelSchlick(F0, ShadowedF90(F0), saturate(dot(data.m_viewVector, data.m_halfVector)));
    
    return F * (G2 * D * NdotL);
}

// Sampling
float3 CosineHemisphereSample(float2 randFloat)
{
    float r = sqrt(randFloat.x);
    float theta = 2.0f * PI * randFloat.y;
    float3 result = float3(r * cos(theta), r * sin(theta), sqrt(1.0f - randFloat.x));
    
    return result;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float3 SampleGGXVNDF(float3 viewVector, float roughness, float2 uniformRandom)
{
    float alpha = GetLinearRoughness(roughness);

    float3 viewInHemisphere = normalize(float3(alpha * viewVector.x, alpha * viewVector.y, viewVector.z));
    float vhSquaredLength = viewInHemisphere.x * viewInHemisphere.x + viewInHemisphere.y * viewInHemisphere.y;
    
    float3 T1 = vhSquaredLength > 0 ? normalize(float3(-viewInHemisphere.y, viewInHemisphere.x, 0)) : float3(1, 0, 0);
    float3 T2 = cross(viewInHemisphere, T1);
    
    float r = sqrt(uniformRandom.x);
    float phi = 2.0f * PI * uniformRandom.y;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi);
    float s = 0.5f * (1.0f + viewInHemisphere.z);
    t2 = lerp(sqrt(max(0.0f, 1.0f - t1 * t1)), t2, s);
    
    float3 Nh = t1 * T1 + t2 * T2 + sqrt(max(0.0f, 1.0f - t1 * t1 - t2 * t2)) * viewInHemisphere;
    
    return normalize(float3(alpha * Nh.x, alpha * Nh.y, max(0.0f, Nh.z)));
}

//-------------------------------------------------------------------------------------------------------------------------------------
float3 SampleSpecularMicrofacet(float3 localViewVector, BrdfData data, float2 uniformRandom, out float3 weight)
{
    float3 halfVectorLocal;
    float alpha = GetLinearRoughness(data.m_roughness);
    
    if(alpha == 0.f)
    {
        halfVectorLocal = float3(0.f, 0.f, 1.f);
    }
    else
    {
        halfVectorLocal = SampleGGXVNDF(localViewVector, data.m_roughness, uniformRandom);
    }
    
    float3 lightVectorLocal = reflect(-localViewVector, halfVectorLocal);
    
    float HdotL = max(0.00001f, min(1.f, dot(halfVectorLocal, lightVectorLocal)));
    float3 nLocal = float3(0.f, 0.f, 1.f);
    float NdotL = max(0.00001f, min(1.f, dot(nLocal, lightVectorLocal)));
    float NdotV = max(0.00001f, min(1.f, dot(nLocal, localViewVector)));
    float NdotH = max(0.00001f, min(1.f, dot(nLocal, halfVectorLocal)));
    float3 F0 = ComputeSpecularBaseReflectivity(data.m_baseColor, data.m_metalness);
    float3 F = ComputeFresnelSchlick(F0, ShadowedF90(F0), HdotL);
    
    weight = F * Smith_G2_Over_G1_HeightCorrelated(alpha, NdotL, NdotV);
    return lightVectorLocal;
}

//-------------------------------------------------------------------------------------------------------------------------------------
bool EvaluateIndirectBRDF(float2 uniformRandFloats, BrdfData data, int brdfType, out float3 rayDirection, out float3 sampleWeight)
{
    if (dot(data.m_pixelNormal, data.m_viewVector) <= 0.f)
    {
        return false;
    }
    
    float4 rotationToNormal = GetRotationToZAxis(data.m_pixelNormal);
    float3 vLocal = rotatePoint(rotationToNormal, data.m_viewVector);
    float3 nLocal = float3(0.f, 0.f, 1.f);
    float3 rayDirectionLocal = float3(0.f, 0.f, 0.f);
    
    if(brdfType == BRDF_DIFFUSE)
    {
        rayDirectionLocal = CosineHemisphereSample(uniformRandFloats);
        sampleWeight = data.m_diffuseReflectance;      
        
        float3 halfVector = SampleGGXVNDF(vLocal, data.m_roughness, uniformRandFloats);
        
        float vDotH = max(0.00001f, min(1.0f, dot(vLocal, halfVector)));
        sampleWeight *= (float3(1.f, 1.f, 1.f) - ComputeFresnelSchlick(data.m_F0, ShadowedF90(data.m_F0), vDotH));
    }
    else if(brdfType == BRDF_SPECULAR)
    {
        rayDirectionLocal = SampleSpecularMicrofacet(vLocal, data, uniformRandFloats, sampleWeight);
    }
    
    if ((Luminance(sampleWeight) <= 0.f) || !IsFiniteFloat3(sampleWeight))
    {
        return false;
    }
    
    rayDirection = rotatePoint(invertRotation(rotationToNormal), rayDirectionLocal);
    
    if(dot(rayDirection, data.m_surfaceNormal) <= 0.f)
    {
        return false;
    }

    return true;  
}

float GetBRDFProbability(BrdfData data)
{
    float specF0 = Luminance(ComputeSpecularBaseReflectivity(data.m_baseColor, data.m_metalness));
    float reflectance = Luminance(ComputeDiffuseReflectance(data.m_baseColor, data.m_metalness));
    
    float fresnel = saturate(Luminance(ComputeFresnelSchlick(specF0, ShadowedF90(specF0), max(0.f, dot(data.m_viewVector, data.m_pixelNormal)))));

    float specular = fresnel;
    float diffuse = reflectance * (1.0f - fresnel); //< If diffuse term is weighted by Fresnel, apply it here as well

	// Return probability of selecting specular BRDF over diffuse BRDF
    float p = (specular / max(0.0001f, (specular + diffuse)));

	// Clamp probability to avoid undersampling of less prominent BRDF
    return clamp(p, 0.1f, 0.9f);
}
