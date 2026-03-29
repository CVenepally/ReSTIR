//-------------------------------------------------------------------------------------------------------------------------------------
// Shader Includes
//-------------------------------------------------------------------------------------------------------------------------------------
#include "Includes/RTUtils.hlsli"
#include "Includes/RTDataStructures.hlsli"
#include "Includes/BRDF.hlsli"
#include "Includes/RNG.hlsli"
#include "Includes/Sampling.hlsli"
#include "Includes/Reservoir.hlsli"
#include "Includes/Resources.hlsli"

//UTILS ---------------------------------------------------------------------------------------------------------------------------------
float4 SampleTexture(Texture2D tex, float2 uv, uint samplerIndex)
{
    switch (samplerIndex)
    {
        case 0:
            return tex.SampleLevel(g_samplerPointClamp, uv, 0);
        case 1:
            return tex.SampleLevel(g_samplerBilinearWrap, uv, 0);
        case 2:
            return tex.SampleLevel(g_samplerBilinearComparisionBorder, uv, 0);
        case 3:
            return tex.SampleLevel(g_samplerPointWrap, uv, 0);
        case 4:
            return tex.SampleLevel(g_samplerPointMirror, uv, 0);
        case 5:
            return tex.SampleLevel(g_samplerBilinearClamp, uv, 0);
        case 6:
            return tex.SampleLevel(g_samplerBilinearMirror, uv, 0);
        case 7:
            return tex.SampleLevel(g_samplerTrilinearWrap, uv, 0);
        case 8:
            return tex.SampleLevel(g_samplerTrilinearClamp, uv, 0);
        case 9:
            return tex.SampleLevel(g_samplerTrilinearMirror, uv, 0);
        default:
            return tex.SampleLevel(g_samplerBilinearWrap, uv, 0);
    }
} 

//-------------------------------------------------------------------------------------------------------------------------------------
BrdfData GetBrdfData(RayPayload payload, float3 pixelToLight)
{
    BrdfData data;
    data.m_baseColor            = payload.m_albedo.rgb;
    data.m_metalness            = payload.m_metalness;
    data.m_roughness            = payload.m_roughness;
    data.m_pixelNormal          = payload.m_pixelNormal;
    data.m_surfaceNormal        = payload.m_surfaceNormal;
    data.m_surfaceTangent       = payload.m_worldTangent;
    data.m_surfaceBitangent     = payload.m_worldBitangent;
    data.m_rayDirection         = payload.m_worldRayDirection;
    data.m_viewVector           = -payload.m_worldRayDirection;
    data.m_pixelToLight         = pixelToLight;
    data.m_lightToPixel         = -pixelToLight;
    data.m_halfVector           = SafeNormalize(pixelToLight + data.m_viewVector);
    data.m_diffuseReflectance   = ComputeDiffuseReflectance(data.m_baseColor, data.m_metalness);
    data.m_F0                   = ComputeSpecularBaseReflectivity(data.m_baseColor, data.m_metalness);  
    data.m_F                    = ComputeFresnelSchlick(data.m_F0, ShadowedF90(data.m_F0), saturate(dot(data.m_viewVector, data.m_halfVector)));
  
    return data;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float3 OffsetRay(const float3 p, const float3 n)
{
    static const float origin = 1.0f / 32.0f;
    static const float float_scale = 1.0f / 65536.0f;
    static const float int_scale = 256.0f;

    int3 of_i = int3(int_scale * n.x, int_scale * n.y, int_scale * n.z);

    float3 p_i = float3(
		asfloat(asint(p.x) + ((p.x < 0) ? -of_i.x : of_i.x)),
		asfloat(asint(p.y) + ((p.y < 0) ? -of_i.y : of_i.y)),
		asfloat(asint(p.z) + ((p.z < 0) ? -of_i.z : of_i.z)));

    return float3(abs(p.x) < origin ? p.x + float_scale * n.x : p_i.x,
		abs(p.y) < origin ? p.y + float_scale * n.y : p_i.y,
		abs(p.z) < origin ? p.z + float_scale * n.z : p_i.z);
}


//-------------------------------------------------------------------------------------------------------------------------------------
bool IsPixelShadowedFromLight(float3 hitPosition, float3 directionToLight, float3 surfaceNormal, float maxDist = FP32Max)
{
    RayDesc shadowRayDesc;
    shadowRayDesc.Origin = OffsetRay(hitPosition, surfaceNormal);
    shadowRayDesc.Direction = directionToLight;
    shadowRayDesc.TMin = 0.0f;
    shadowRayDesc.TMax = maxDist;
        
    ShadowRayPayload shadowPayload = { 1.f };
    TraceRay(g_tlas, RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH, 0xFFFFFFFF, RAY_SHADOW, RAY_COUNT, RAY_SHADOW, shadowRayDesc, shadowPayload);

    return shadowPayload.srp_isShadowed;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float SampleLight(float rand, float3 hitPos, BrdfData data, out float out_pickedWeight, out float out_totalWeight)
{
    out_totalWeight = 0.f;
    
    for (int i = 0; i < g_lightConsts.cb_numLights; i++)
    {
        Light light = g_lightConsts.cb_allLights[i];
        LightEval evalResult = EvalLightAtPoint(light, hitPos);
        float lightWeight = ComputeLightWeight(data, evalResult);
        out_totalWeight += lightWeight;
    }
    
    if(out_totalWeight <= 0.f)
    {
        out_pickedWeight = 0.f;
        return -1;
    }

    float value = rand * out_totalWeight;
    float c = 0.f;
   
    
    for (int j = 0; j < g_lightConsts.cb_numLights; j++)
    {
        Light light = g_lightConsts.cb_allLights[j];
        LightEval evalResult = EvalLightAtPoint(light, hitPos);
        float lightWeight = ComputeLightWeight(data, evalResult);
        c += lightWeight;
        
        if(value <= c)
        {
            out_pickedWeight = max(lightWeight, 1e-8);
            return j;
        }
    }

    out_pickedWeight = 1e-8;
    return g_lightConsts.cb_numLights - 1;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float4 DebugViews()
{
    uint2 pixel = DispatchRaysIndex().xy;
    
    if(g_debugConsts.cb_debugView == 1)
    {
        return float4(EncodeXYZtoRGB(g_positionGBuffer[pixel].xyz), 1.f);
    }
    if (g_debugConsts.cb_debugView == 2)
    {
        return g_albedoGBuffer[pixel];
    }
    if(g_debugConsts.cb_debugView == 3)
    {
        return g_vertColorGBuffer[pixel];
    }
    if(g_debugConsts.cb_debugView == 4)
    {
        return g_normalsGBuffer[pixel];
    }
    if(g_debugConsts.cb_debugView == 5)
    {
        float4 motionVector = g_velocityGBuffer[pixel] * 10.f;
        if(motionVector.x < 0)
        {
            motionVector.x *= -1.f;
        }

        if (motionVector.y < 0)
        {
            motionVector.y *= -1.f;
        }   
        return motionVector;
    }
    if(g_debugConsts.cb_debugView == 6)
    {
        return g_surfaceNormalGBuffer[pixel];
    }
    if(g_debugConsts.cb_debugView == 7)
    {
        return g_surfaceTangentGBuffer[pixel];
    }
    if(g_debugConsts.cb_debugView == 8)
    {
        return g_surfaceBitangentGBuffer[pixel];
    }
    if(g_debugConsts.cb_debugView == 9)
    {
        return g_rmGBuffer[pixel].gggg;
    }
    if(g_debugConsts.cb_debugView == 10)
    {
        return g_rmGBuffer[pixel].bbbb;
    }
    if (g_debugConsts.cb_debugView == 11)
    {
        uint pixelIndex = (DispatchRaysDimensions().x * pixel.y) + pixel.x;
        Reservoir reservoir = g_temporalReservoirBuffer[pixelIndex];
        
        if (IsReservoirValid(reservoir))
        {
            return (float) reservoir.m_importantLightIndex.xxxx / (float) g_lightConsts.cb_numLights;
        }
        return 0.f.xxxx;
    }
    if (g_debugConsts.cb_debugView == 12)
    {
        uint pixelIndex = (DispatchRaysDimensions().x * pixel.y) + pixel.x;
        Reservoir reservoir = g_prevReservoirBuffer[pixelIndex];
        
        if (IsReservoirValid(reservoir))
        {
            return (float) reservoir.m_importantLightIndex.xxxx / (float) g_lightConsts.cb_numLights;
        }
        return 0.f.xxxx;
    }
    if (g_debugConsts.cb_debugView == 13)
    {
        if (g_depthBuffer[pixel].x <= 0.2)
        {
            return g_depthBuffer[pixel];
        }
        else
        {
            return 1.f.xxxx;
        }
    }
    
    return 0.f.xxxx;
}

// Utils End---------------------------------------------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------------------------------------------------------
//float4 PathTrace(uint randSeed, RayDesc ray)
//{
//    float4 finalColor = float4(0.f, 0.f, 0.f, 1.f);
//    float3 throughput = float3(1.f, 1.f, 1.f);
//    float bounce = 0;
    
//    RayPayload payload;
//    payload.m_didHit = false;
    
//    while(true)
//    {
//        if (IsFloat3Zero(throughput))
//        {
//            break;
//        }
        
//        bounce += 1;
        
//        TraceRay(g_tlas, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0xFFFFFFFF, RAY_PRIMARY, RAY_COUNT, RAY_PRIMARY, ray, payload);
        
//        if(!payload.m_didHit)
//        {
//            //if (g_debugConsts.cb_envLighting)
//            //{
//            //    float3 dir = SafeNormalize(payload.m_worldRayDirection);
//            //    float t = 0.5f * (dir.z + 1.0f);
//            //    float3 sky = lerp(float3(0.3f, 0.4f, 0.7f), float3(0.7f, 0.9f, 1.0f), t);
    
//            //    finalColor.xyz += throughput * sky;
            
//            //    if (g_debugConsts.cb_debugView != 0)
//            //    {
//            //        finalColor = float4(0.f, 0.f, 0.f, 1.f);
//            //    }
//            //}
//            //else
//            //{
//            //    finalColor = float4(1.f, 1.f, 1.f, 1.f);
//            //    break;
//            //}
        
            
//            finalColor = float4(0.f.xxx, 1.f);
//        }
                
        
//        float3 hitPosition          = payload.m_worldPosition;
//        float3 pixelNormal          = payload.m_pixelNormal;
//        float3 surfaceNormal        = payload.m_surfaceNormal;
//        float3 worldRayDirection    = payload.m_worldRayDirection;
//        float4 baseColor            = float4(payload.m_albedo, 1.0f);
//        float metalness             = payload.m_metalness;
//        float roughness             = payload.m_roughness;

//        if(g_appSettings.cb_doDirect == 1)
//        {
//            BrdfData temp = GetBrdfData(payload, float3(0.f, 0.f, 1.f));

//            if(g_debugConsts.cb_lightSamplingMethod == 0) //CDF
//            {
//                float totalWeightSum;
//                float chosenWeight;
            
//                float rand = RollRandomFloatZeroToOneAndUpdateSeed(randSeed);
//                int lightIndex = SampleLight(rand, hitPosition, temp, chosenWeight, totalWeightSum);
            
//                if (lightIndex >= 0)
//                {
//                    Light light = g_lightConsts.cb_allLights[lightIndex];
//                    LightEval eval = EvalLightAtPoint(light, hitPosition);
                
//                    BrdfData data = GetBrdfData(payload, eval.m_pointToLightDirection);
                
//                    bool shadowed = IsPixelShadowedFromLight(hitPosition, eval.m_pointToLightDirection, data.m_surfaceNormal, eval.m_maxDist);
                
//                    if (!shadowed)
//                    {
//                        float3 lightDiffuse = (g_debugConsts.cb_diffuseModel == 0) ? CalculateDiffuse_OrenNayar(data) : CalculateDiffuse_Lambert(data);
//                        float3 lightSpecular = (g_debugConsts.cb_specularModel == 0) ? CalculateSpecular_MicroFacet(data) : CalculateSpecular_Phong(data);
                    
//                        float3 f = (1.0.xxx - data.m_F) * lightDiffuse + lightSpecular;
//                        float invPDF = totalWeightSum / max(chosenWeight, 1e-8);
//                        float3 color = throughput * f * eval.m_incomingRadiance * invPDF;
                    
//                        if (!IsFiniteFloat3(color))
//                            color = 0;
//                        color = ClampRadiance(color, 50.f);
                    
//                        finalColor.xyz += color;
//                    }
//                }
//            }
//            else if (g_debugConsts.cb_lightSamplingMethod == 1)
//            {
//                float pdf = 1.f / g_lightConsts.cb_numLights;
//                float p_hat = 0.f;
//                int M = g_appSettings.cb_maxSamples;
            
//                uint2 index = (uint2) DispatchRaysIndex().xy;
//                uint reservoirIndex = (DispatchRaysDimensions().x * index.y) + index.x;

//                Reservoir currentFrameReservoir = g_temporalReservoirBuffer[reservoirIndex];
                       
//                for (uint i = 0; i < M; i++)
//                {
//                    uint lightIndex = min((uint) (RollRandomFloatZeroToOneAndUpdateSeed(randSeed) * g_lightConsts.cb_numLights), g_lightConsts.cb_numLights - 1);
                                
//                    LightEval eval = EvalLightAtPoint(g_lightConsts.cb_allLights[lightIndex], hitPosition);
                
//                    p_hat = length(eval.m_incomingRadiance);
                
//                    if (!IsFiniteFloat(p_hat) || p_hat <= 0)
//                        continue;
                
//                    float weightOfLight = p_hat / pdf;
                
//                    if (!IsFiniteFloat(weightOfLight) || weightOfLight <= 0)
//                        continue;
  
//                    UpdateReservoir(currentFrameReservoir, lightIndex, weightOfLight, randSeed);
//                }
                                
//                uint lightIndex = currentFrameReservoir.m_importantLightIndex;
            
//            //float v = ((float) res.m_importantLightIndex) / (float) g_lightConsts.cb_numLights;
//            //return v.xxxx;
            
//                if (lightIndex < 0 || lightIndex >= g_lightConsts.cb_numLights)
//                {
//                    continue;
//                }
            
//                Light light = g_lightConsts.cb_allLights[lightIndex];
//                LightEval eval = EvalLightAtPoint(light, hitPosition);
                
//                BrdfData data = GetBrdfData(payload, eval.m_pointToLightDirection);
                
//                bool shadowed = IsPixelShadowedFromLight(hitPosition, eval.m_pointToLightDirection, data.m_surfaceNormal, eval.m_maxDist);
                
//                if (!shadowed)
//                {
            
//                    float3 lightDiffuse = (g_debugConsts.cb_diffuseModel == 0) ? CalculateDiffuse_OrenNayar(data) : CalculateDiffuse_Lambert(data);
//                    float3 lightSpecular = (g_debugConsts.cb_specularModel == 0) ? CalculateSpecular_MicroFacet(data) : CalculateSpecular_Phong(data);
                    
//                    float3 f = (1.0.xxx - data.m_F) * lightDiffuse + lightSpecular;
//                    p_hat = length(eval.m_incomingRadiance);
//                    currentFrameReservoir.m_weightOfImportantLight = p_hat > 0.f ? (currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights / p_hat) / currentFrameReservoir.m_numProcessedLights : 0.f;
//                    float3 color = throughput * f * eval.m_incomingRadiance * currentFrameReservoir.m_weightOfImportantLight;
                    
//                    if (!IsFiniteFloat3(color))
//                        color = 0;
//                    color = ClampRadiance(color, 50.f);
                    
//                    finalColor.xyz += color;
//                }

//            }
//        }
        
//        if(bounce > g_appSettings.cb_minBounces)
//        {
//            if (!IsFiniteFloat3(throughput))
//                break;
           
//            float rrProb = saturate(Luminance(throughput));
//            rrProb = clamp(rrProb, 0.05f, 0.95f);
            
//            if(rrProb < RollRandomFloatZeroToOneAndUpdateSeed(randSeed))
//            {
//                break;
//            }
            
//            throughput /= rrProb;
//        }
        
//        BrdfData bsdfData = GetBrdfData(payload, float3(0.f, 0.f, 1.f));

//        if (g_appSettings.cb_doIndirect == 1)
//        {
//            float3 brdfWeight;
//            float2 u = float2(RollRandomFloatZeroToOneAndUpdateSeed(randSeed), RollRandomFloatZeroToOneAndUpdateSeed(randSeed));

//            int brdfType;

//            if (metalness == 1.f && roughness == 0.f)
//            {
//                brdfType = BRDF_SPECULAR;
//            }
//            else
//            {
//                float prob = max(0.001f, GetBRDFProbability(bsdfData));

//                if (RollRandomFloatZeroToOneAndUpdateSeed(randSeed) < prob)
//                {
//                    brdfType = BRDF_SPECULAR;
//                    throughput /= prob;
//                }
//                else
//                {
//                    brdfType = BRDF_DIFFUSE;
//                    throughput /= (1.f - prob);
//                }
//            }

//            float3 nextDir;
//            if (!EvaluateIndirectBRDF(u, bsdfData, brdfType, nextDir, brdfWeight))
//            {
//                break;
//            }

//            throughput *= brdfWeight;

//            if (!IsFiniteFloat3(throughput))
//                break;
            
//            throughput = min(throughput, 1e4.xxx);
            
//            ray.Origin = OffsetRay(hitPosition, surfaceNormal);
//            ray.Direction = nextDir;
//        }
//        else
//        {
//            break;
//        }
//    }
        
//    return finalColor;
//}



[shader("raygeneration")]
void RayGenShader()
{
    uint2 pixel = DispatchRaysIndex().xy;
    uint reservoirIndex = (DispatchRaysDimensions().x * pixel.y) + pixel.x;

    Reservoir reservoir = g_finalReservoirBuffer[reservoirIndex];
//    Reservoir reservoir = g_temporalReservoirBuffer[reservoirIndex];

    float3 hitPosition = g_positionGBuffer[pixel].xyz;
    float3 pixelNormal = DecodeRGBtoXYZ(g_normalsGBuffer[pixel].xyz);
    float3 surfaceNormal = DecodeRGBtoXYZ(g_surfaceNormalGBuffer[pixel].xyz);
    float4 baseColor = g_albedoGBuffer[pixel];
    float roughness = g_rmGBuffer[pixel].g;
    float metalness = g_rmGBuffer[pixel].b;
    g_prevNormalGBuffer[pixel].xyz = g_normalsGBuffer[pixel].xyz;
    g_prevDepthGBuffer[pixel].xyz = g_depthBuffer[pixel].xyz;
    
    if(g_debugConsts.cb_debugView != 0)
    {
        g_renderTarget[pixel] = DebugViews();
        InitReservoir(g_prevReservoirBuffer[reservoirIndex]);
        g_prevReservoirBuffer[reservoirIndex] = reservoir;
        return;
    }
            
    if(reservoir.m_importantLightIndex >= g_lightConsts.cb_numLights)
    {
        g_renderTarget[pixel] = float4(0.f, 0.f, 0.f, 1.f);
        InitReservoir(g_prevReservoirBuffer[reservoirIndex]);
        g_prevReservoirBuffer[reservoirIndex] = reservoir;
        return;
    }
    
    Light light = g_lightConsts.cb_allLights[reservoir.m_importantLightIndex];
    LightEval eval = EvalLightAtPoint(light, hitPosition);
    
    bool shadowed = IsPixelShadowedFromLight(hitPosition, eval.m_pointToLightDirection, surfaceNormal);
    
    if(shadowed)
    {
        if (reservoir.m_importantLightIndex >= g_lightConsts.cb_numLights)
        {
            g_renderTarget[pixel] = float4(0.f, 0.f, 0.f, 1.f);
            g_prevReservoirBuffer[reservoirIndex] = reservoir;
            return;
        }
    }
    
    RayPayload payload;
    payload.m_didHit            = true;
    payload.m_albedo            = g_albedoGBuffer[pixel].rgb;
    payload.m_pixelNormal       = DecodeRGBtoXYZ(g_normalsGBuffer[pixel].xyz);
    payload.m_roughness         = g_rmGBuffer[pixel].g;
    payload.m_metalness         = g_rmGBuffer[pixel].b;
    payload.m_surfaceNormal     = DecodeRGBtoXYZ(g_surfaceNormalGBuffer[pixel].xyz);
    payload.m_worldTangent      = DecodeRGBtoXYZ(g_surfaceTangentGBuffer[pixel].xyz);
    payload.m_worldBitangent    = DecodeRGBtoXYZ(g_surfaceBitangentGBuffer[pixel].xyz);
    payload.m_worldRayDirection = normalize(hitPosition - g_cameraConsts.cb_cameraPosition.xyz);
    payload.m_worldPosition     = g_positionGBuffer[pixel].xyz;
    
    BrdfData data           = GetBrdfData(payload, eval.m_pointToLightDirection);
    float3 lightDiffuse     = (g_debugConsts.cb_diffuseModel == 0) ? CalculateDiffuse_OrenNayar(data) : CalculateDiffuse_Lambert(data);
    float3 lightSpecular    = (g_debugConsts.cb_specularModel == 0) ? CalculateSpecular_MicroFacet(data) : CalculateSpecular_Phong(data);                    
    float3 f = (1.0.xxx - data.m_F) * lightDiffuse + lightSpecular;
    float3 color = f * eval.m_incomingRadiance * reservoir.m_weightOfImportantLight;
                    
    if (!IsFiniteFloat3(color))
        color = 0;

    color = ClampRadiance(color, 50.f);
    
    float3 finalLighting = color;

// ---------------- INDIRECT ----------------
    if (g_appSettings.cb_doIndirect == 1)
    {
        uint randSeed = (pixel.x + pixel.y * DispatchRaysDimensions().x) * (g_appSettings.cb_frameCount + 1);

        float3 throughput = float3(1.f, 1.f, 1.f);
        float3 indirectAccum = 0.f.xxx;

        RayDesc ray;
        ray.Origin = OffsetRay(hitPosition, surfaceNormal);
        ray.Direction = normalize(reflect(-payload.m_worldRayDirection, surfaceNormal));
        ray.TMin = 0.0f;
        ray.TMax = FP32Max;

        for (int bounce = 0; bounce < 3; bounce++)
        {
            RayPayload bouncePayload;
            bouncePayload.m_didHit = false;

            TraceRay(g_tlas, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0xFFFFFFFF,
                 RAY_PRIMARY, RAY_COUNT, RAY_PRIMARY,
                 ray, bouncePayload);

            if (!bouncePayload.m_didHit)
            {
                break;
            }

            float3 hitPos = bouncePayload.m_worldPosition;
            float3 surfN = bouncePayload.m_surfaceNormal;

            BrdfData bsdfData = GetBrdfData(bouncePayload, float3(0.f, 0.f, 1.f));

            float3 brdfWeight;
            float2 u = float2(
            RollRandomFloatZeroToOneAndUpdateSeed(randSeed),
            RollRandomFloatZeroToOneAndUpdateSeed(randSeed)
        );

            int brdfType;

            if (bouncePayload.m_metalness == 1.f && bouncePayload.m_roughness == 0.f)
            {
                brdfType = BRDF_SPECULAR;
            }
            else
            {
                float prob = max(0.001f, GetBRDFProbability(bsdfData));

                if (RollRandomFloatZeroToOneAndUpdateSeed(randSeed) < prob)
                {
                    brdfType = BRDF_SPECULAR;
                    throughput /= prob;
                }
                else
                {
                    brdfType = BRDF_DIFFUSE;
                    throughput /= (1.f - prob);
                }
            }

            float3 nextDir;
            if (!EvaluateIndirectBRDF(u, bsdfData, brdfType, nextDir, brdfWeight))
            {
                break;
            }

            throughput *= brdfWeight;

            if (!IsFiniteFloat3(throughput))
                break;

            throughput = min(throughput, 1e4.xxx);

        // ---- Direct lighting at bounce ----
            float rand = RollRandomFloatZeroToOneAndUpdateSeed(randSeed);
            float chosenWeight;
            float totalWeight;

            int lightIndex = SampleLight(rand, hitPos, bsdfData, chosenWeight, totalWeight);

            if (lightIndex >= 0)
            {
                Light light = g_lightConsts.cb_allLights[lightIndex];
                LightEval eval = EvalLightAtPoint(light, hitPos);

                bool shadowed = IsPixelShadowedFromLight(hitPos, eval.m_pointToLightDirection, surfN, eval.m_maxDist);

                if (!shadowed)
                {
                    BrdfData data = GetBrdfData(bouncePayload, eval.m_pointToLightDirection);

                    float3 lightDiffuse = (g_debugConsts.cb_diffuseModel == 0) ? CalculateDiffuse_OrenNayar(data) : CalculateDiffuse_Lambert(data);
                    float3 lightSpecular = (g_debugConsts.cb_specularModel == 0) ? CalculateSpecular_MicroFacet(data) : CalculateSpecular_Phong(data);

                    float3 f = (1.0.xxx - data.m_F) * lightDiffuse + lightSpecular;
                    float invPDF = totalWeight / max(chosenWeight, 1e-8);

                    float3 bounceColor = throughput * f * eval.m_incomingRadiance * invPDF;

                    if (!IsFiniteFloat3(bounceColor))
                        bounceColor = 0;

                    bounceColor = ClampRadiance(bounceColor, 50.f);

                    indirectAccum += bounceColor;
                }
            }

        // ---- Russian roulette ----
            if (bounce > g_appSettings.cb_minBounces)
            {
                float rrProb = saturate(Luminance(throughput));
                rrProb = clamp(rrProb, 0.05f, 0.95f);

                if (rrProb < RollRandomFloatZeroToOneAndUpdateSeed(randSeed))
                    break;

                throughput /= rrProb;
            }

            ray.Origin = OffsetRay(hitPos, surfN);
            ray.Direction = nextDir;
        }

        finalLighting += indirectAccum;
    }
    
    float4 lastFramePixelColor = g_renderTarget[pixel];
    float4 lerpFactor = g_appSettings.cb_accumCount / (g_appSettings.cb_accumCount + 1.0f);

    float3 blended = lerp(finalLighting, lastFramePixelColor.xyz, lerpFactor.xxx);

    g_renderTarget[pixel] = float4(blended, 1.0f);
    g_noisyRenderTarget[pixel] = float4(blended, 1.0f);

    g_prevReservoirBuffer[reservoirIndex] = reservoir; 
    
    //g_renderTarget[DispatchRaysIndex().xy].xyz      = color;
    //g_noisyRenderTarget[DispatchRaysIndex().xy].xyz = color;
}

[shader("closesthit")]
void ClosestHitShader(inout RayPayload payload, in MyAttributes attribs)
{
    payload.m_didHit = true;

    float3 hitLocation = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();

    int geoIndex = GeometryIndex();
    int instIndex = InstanceIndex();
    uint primIndex = PrimitiveIndex();

    int meshInfoIndex = (instIndex == 0) ? geoIndex : geoIndex + instIndex;

    StructuredBuffer<MeshInfo> sceneMeshInfoBuffer = g_sceneMeshInfoBuffer[g_sceneConsts.cb_sceneMeshInfoBufferIndex];
    MeshInfo meshInfo = sceneMeshInfoBuffer[meshInfoIndex];

    StructuredBuffer<Vertex_PCUTBN> verts = g_vertices[meshInfo.m_vbIndex];
    StructuredBuffer<uint> inds = g_indices[meshInfo.m_ibIndex];

    uint i0 = inds[primIndex * 3 + 0];
    uint i1 = inds[primIndex * 3 + 1];
    uint i2 = inds[primIndex * 3 + 2];

    Vertex_PCUTBN v0 = verts[i0];
    Vertex_PCUTBN v1 = verts[i1];
    Vertex_PCUTBN v2 = verts[i2];

    float3 bary = float3(
        1.0f - attribs.barycentrics.x - attribs.barycentrics.y,
        attribs.barycentrics.x,
        attribs.barycentrics.y
    );

    float2 uv = v0.v_uvCoords * bary.x +
                v1.v_uvCoords * bary.y +
                v2.v_uvCoords * bary.z;

    uv.y = 1.f - uv.y;

    float3 normal =
        v0.v_normal * bary.x +
        v1.v_normal * bary.y +
        v2.v_normal * bary.z;

    float3 tangent =
        v0.v_tangent * bary.x +
        v1.v_tangent * bary.y +
        v2.v_tangent * bary.z;

    float3 bitangent =
        v0.v_bitangent * bary.x +
        v1.v_bitangent * bary.y +
        v2.v_bitangent * bary.z;

    normal = SafeNormalize(normal);
    tangent = SafeNormalize(tangent);
    bitangent = SafeNormalize(bitangent);

    float3 pixelNormal = normal;

    // Normal map
    if (meshInfo.m_materialInfo.m_normalIndex != -1)
    {
        Texture2D normalTex = g_textures[meshInfo.m_materialInfo.m_normalIndex];
        float3 normalTS = DecodeRGBtoXYZ(SampleTexture(normalTex, uv, meshInfo.m_materialInfo.m_normalSamplerIndex).rgb);

        float3x3 TBN = float3x3(tangent, bitangent, normal);
        pixelNormal = normalize(mul(normalTS, TBN));
    }

    float3 albedo = 1.f.xxx;
    if (meshInfo.m_materialInfo.m_albedoIndex != -1)
    {
        Texture2D albedoTex = g_textures[meshInfo.m_materialInfo.m_albedoIndex];
        albedo = SampleTexture(albedoTex, uv, meshInfo.m_materialInfo.m_albedoSamplerIndex).rgb;
    }

    float roughness = 0.5f;
    float metalness = 0.0f;

    if (meshInfo.m_materialInfo.m_rmIndex != -1)
    {
        Texture2D rmTex = g_textures[meshInfo.m_materialInfo.m_rmIndex];
        float4 rmSample = SampleTexture(rmTex, uv, meshInfo.m_materialInfo.m_rmSamplerIndex);

        roughness = saturate(rmSample.g);
        metalness = saturate(rmSample.b);
    }

    payload.m_worldPosition = hitLocation;
    payload.m_worldRayDirection = WorldRayDirection();

    payload.m_surfaceNormal = normal;
    payload.m_pixelNormal = pixelNormal;
    payload.m_worldTangent = tangent;
    payload.m_worldBitangent = bitangent;

    payload.m_albedo = albedo;
    payload.m_roughness = roughness;
    payload.m_metalness = metalness;
} 

//-------------------------------------------------------------------------------------------------------------------------------------
[shader("miss")]
void MissShader(inout RayPayload payload)
{
    payload.m_didHit = false;
}

//-------------------------------------------------------------------------------------------------------------------------------------
[shader("closesthit")]
void ShadowClosestHitShader(inout ShadowRayPayload payload, in MyAttributes attribs)
{
    payload.srp_isShadowed = true;
}

//-------------------------------------------------------------------------------------------------------------------------------------
[shader("miss")]
void ShadowMissShader(inout ShadowRayPayload payload)
{
    payload.srp_isShadowed = false;
}
