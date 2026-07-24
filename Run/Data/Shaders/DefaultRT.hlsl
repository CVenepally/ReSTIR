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
bool IsPointShadowedFromLight(float3 hitPosition, float3 directionToLight, float3 surfaceNormal, float maxDist = FP32Max)
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
//float SampleLight(float rand, float3 hitPos, BrdfData data, out float out_pickedWeight, out float out_totalWeight)
//{
//    out_totalWeight = 0.f;
    
//    for (int i = 0; i < g_sceneConsts.cb_numLights; i++)
//    {
//        Light light = g_lightConsts.cb_allLights[i];
//        LightEval evalResult = EvalLightAtPoint(light, hitPos);
//        float lightWeight = ComputeLightWeight(data, evalResult);
//        out_totalWeight += lightWeight;
//    }
    
//    if(out_totalWeight <= 0.f)
//    {
//        out_pickedWeight = 0.f;
//        return -1;
//    }

//    float value = rand * out_totalWeight;
//    float c = 0.f;
   
    
//    for (int j = 0; j < g_lightConsts.cb_numLights; j++)
//    {
//        Light light = g_lightConsts.cb_allLights[j];
//        LightEval evalResult = EvalLightAtPoint(light, hitPos);
//        float lightWeight = ComputeLightWeight(data, evalResult);
//        c += lightWeight;
        
//        if(value <= c)
//        {
//            out_pickedWeight = max(lightWeight, EPS);
//            return j;
//        }
//    }

//    Light lastLight = g_lightConsts.cb_allLights[g_lightConsts.cb_numLights - 1];
//    LightEval eval = EvalLightAtPoint(lastLight, hitPos);
//    float lastWeight = ComputeLightWeight(data, eval);
    
//    out_pickedWeight = max(lastWeight, EPS);
//    return g_lightConsts.cb_numLights - 1;
//}

//-------------------------------------------------------------------------------------------------------------------------------------
uint SampleLightWRS(float randSeed, float3 hitPos, inout float out_chosenWeight, inout float out_totalWeight)
{
    Reservoir currentFrameReservoir;
    InitReservoir(currentFrameReservoir);
        
    float pdf = 1.f / g_sceneConsts.cb_numLights;
    float p_hat = 0.f;
    int M = 32;
    
    uint2 pixel = DispatchRaysIndex().xy;
    float3 shadingNormal = DecodeRGBtoXYZ(g_normalsGBuffer[pixel].xyz);
    float3 albedo = g_albedoGBuffer[pixel].xyz;

    
    for (uint i = 0; i < M; i++)
    {
        uint lightIndex = min((uint) (RollRandomFloatZeroToOneAndUpdateSeed(randSeed) * g_sceneConsts.cb_numLights), g_sceneConsts.cb_numLights - 1);
        
        StructuredBuffer<Light> lightBuffer = g_sceneLightsBuffer[g_sceneConsts.cb_lightBufferIndex];
        Light light = lightBuffer[lightIndex];

        LightEval eval = EvalLightAtPoint(light, hitPos);
                
        float cosTheta = saturate(dot(shadingNormal, eval.m_pointToLightDirection));
        float3 brdf = albedo / PI; // assuming lambertian
        
        p_hat = Luminance(brdf * eval.m_incomingRadiance * cosTheta);
                
        if (!IsFiniteFloat(p_hat) || p_hat <= 0)
            continue;
                
        float weightOfLight = p_hat / pdf;
                
        if (!IsFiniteFloat(weightOfLight) || weightOfLight <= 0)
            continue;
  
        UpdateReservoir(currentFrameReservoir, lightIndex, weightOfLight, randSeed);
    }

    uint lightIndex = currentFrameReservoir.m_importantLightIndex;
    
    if (lightIndex > g_sceneConsts.cb_numLights)
    {
        return lightIndex;
    }
    
    StructuredBuffer<Light> lightBuffer = g_sceneLightsBuffer[g_sceneConsts.cb_lightBufferIndex];
    Light light = lightBuffer[lightIndex];
    
    LightEval eval = EvalLightAtPoint(light, hitPos);
                                                    
    float cosTheta = saturate(dot(shadingNormal, eval.m_pointToLightDirection));
    float3 brdf = albedo / PI; // assuming lambertian
        
    p_hat = Luminance(brdf * eval.m_incomingRadiance * cosTheta);
    
    p_hat = max(p_hat, 1e-4f);
    currentFrameReservoir.m_weightOfImportantLight = p_hat > 0.f ? (currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights / p_hat) / currentFrameReservoir.m_numProcessedLights : 0.f;
    
    out_chosenWeight = max(currentFrameReservoir.m_weightOfImportantLight, EPS);
    out_totalWeight = max(currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights, EPS);
    return lightIndex;

}

//-------------------------------------------------------------------------------------------------------------------------------------
float4 DebugViews()
{
    uint2 pixel = DispatchRaysIndex().xy;
    uint2 screenDims = DispatchRaysDimensions().xy;
    uint reservoirIndex = (screenDims.x * pixel.y) + pixel.x;
    Reservoir reservoir = g_finalReservoirBuffer[reservoirIndex];

    int lightCount = g_sceneConsts.cb_numLights;
    
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
        return g_normalsGBuffer[pixel];
    }
    if (g_debugConsts.cb_debugView == 4)
    {
        return g_surfaceNormalGBuffer[pixel];
    }
    if(g_debugConsts.cb_debugView == 5)
    {
        float4 motionVector = g_velocityGBuffer[pixel] * 100.f;
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
        return g_rmGBuffer[pixel].gggg;
    }
    if(g_debugConsts.cb_debugView == 7)
    {
        return g_rmGBuffer[pixel].bbbb;
    }
    if (g_debugConsts.cb_debugView == 8)
    {
        return g_depthBuffer[pixel];
    }
   
    return 0.f.xxxx;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float4 DoReSTIR(inout RayPayload payload)
{
    float4      color           = float4(0.f.xxx, 1.f);
    uint2       screenDims      = DispatchRaysDimensions().xy;
    uint2       pixel           = DispatchRaysIndex().xy;
    uint        reservoirIndex  = (screenDims.x * pixel.y) + pixel.x;
    Reservoir   reservoir       = g_finalReservoirBuffer[reservoirIndex];
    g_prevReservoirBuffer[reservoirIndex] = reservoir;

    if(!IsReservoirValid(reservoir, g_sceneConsts.cb_numLights))
        return color;
    
    StructuredBuffer<Light> lightBuffer = g_sceneLightsBuffer[g_sceneConsts.cb_lightBufferIndex];
    Light light = lightBuffer[reservoir.m_importantLightIndex];

    //Light light     = g_lightConsts.cb_allLights[reservoir.m_importantLightIndex];
    LightEval eval  = EvalLightAtPoint(light, payload.m_worldPosition);
    
    bool shadowed = IsPointShadowedFromLight(payload.m_worldPosition, eval.m_pointToLightDirection, payload.m_surfaceNormal, eval.m_maxDist);
     
    //if (shadowed)
    //{
    //    if(g_debugConsts.cb_debugView == 9)
    //    {
    //        return 1.f.xxxx;
    //    }
    //    return color;
    //}
    
    BrdfData data           = GetBrdfData(payload, eval.m_pointToLightDirection);
    float3 lightDiffuse     = CalculateDiffuse_Lambert(data);
    float3 lightSpecular    = CalculateSpecular_MicroFacet(data);
    float3 f                = (1.0.xxx - data.m_F) * lightDiffuse + lightSpecular;
    color.rgb               = f * eval.m_incomingRadiance * reservoir.m_weightOfImportantLight;
                    
    if (!IsFiniteFloat3(color.rgb))
        color.rgb = 0;

    color.rgb = ClampRadiance(color.rgb, MAX_RADIANCE);
    
    return color;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float4 DoDirectMIS(inout RayPayload payload)
{
    float4 color = float4(0.f.xxx, 1.f);
    return color;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float4 DoIndirectLighting(inout RayPayload initialPayload)
{
    float4 indirectColor    = float4(0.f, 0.f, 0.f, 1.f);
    uint2 pixel             = DispatchRaysIndex().xy;
    uint randSeed           = GetSeedForRNG(pixel.x, pixel.y);
    randSeed                = GetSeedForRNG(randSeed, g_appSettings.cb_frameCount);
    float3 throughput       = 1.f.xxx;
    
    BrdfData data           = GetBrdfData(initialPayload, float3(0.f, 0.f, 1.f));
       
    for (int bounce = 0; bounce < g_appSettings.cb_maxBounces; bounce++)
    {
        // Find the direction to shoot the ray in 
        int brdfType;    
        if (initialPayload.m_metalness == 1 && initialPayload.m_roughness == 0)
        {
            brdfType = BRDF_SPECULAR;
        }
        else
        {
            float brdfProb = max(0.01f, GetBRDFProbability(data));
            if (RollRandomFloatZeroToOneAndUpdateSeed(randSeed) < brdfProb)
            {
                brdfType = BRDF_SPECULAR;
                throughput /= brdfProb;
            }
            else
            {
                brdfType = BRDF_DIFFUSE;
                throughput /= (1 - brdfProb);
            }
        }
    
        float2 randFloats = float2(RollRandomFloatZeroToOneAndUpdateSeed(randSeed), RollRandomFloatZeroToOneAndUpdateSeed(randSeed));
        float3 newRayDir = 0.f.xxx;
        float3 sampleWeight = 0.f.xxx;
        if (!EvaluateIndirectBRDF(randFloats, data, brdfType, newRayDir, sampleWeight))
        {
            break;
        }
    
        throughput *= sampleWeight;
        
        if (!IsFiniteFloat3(throughput))
            break;
        throughput = min(throughput, 1e4.xxx);

        // Russian roulette
        if (bounce > 0)
        {
            float rrProb = clamp(Luminance(throughput), 0.05f, 0.95f);
            if (rrProb < RollRandomFloatZeroToOneAndUpdateSeed(randSeed))
                break;
            throughput /= rrProb;
        }
        
        RayDesc indirectRay;
        indirectRay.Direction = newRayDir;
        indirectRay.Origin = OffsetRay(initialPayload.m_worldPosition, initialPayload.m_surfaceNormal);
        indirectRay.TMin = 0.f;
        indirectRay.TMax = FP32Max;

        initialPayload.m_didHit = false;
        TraceRay(g_tlas, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0xFFFFFFFF, RAY_PRIMARY, RAY_COUNT, RAY_PRIMARY, indirectRay, initialPayload);
        
        if (!initialPayload.m_didHit)
        {
            break;
        }
        
        float3 hitPos = initialPayload.m_worldPosition;
        float3 surfaceNormal = initialPayload.m_surfaceNormal;
        float3 shadingNormal = initialPayload.m_pixelNormal;
        
        // Shade the hit point
        float rand = RollRandomFloatZeroToOneAndUpdateSeed(randSeed);
        data = GetBrdfData(initialPayload, float3(0.f, 0.f, 1.f));
        
        float chosenWeight = 0.f;
        float totalWeight = 0.f;
        
        int sampledLightIndex = SampleLightWRS(randSeed, hitPos, chosenWeight, totalWeight);
//        int sampledLightIndex = SampleLight(rand, hitPos, data, chosenWeight, totalWeight);
        
        if(sampledLightIndex >= 0 && sampledLightIndex < g_sceneConsts.cb_numLights)
        {
            StructuredBuffer<Light> lightBuffer = g_sceneLightsBuffer[g_sceneConsts.cb_lightBufferIndex];
            Light light = lightBuffer[sampledLightIndex];
            
            LightEval lightEval = EvalLightAtPoint(light, hitPos);
            
            bool isShadowed = IsPointShadowedFromLight(hitPos, lightEval.m_pointToLightDirection, surfaceNormal, lightEval.m_maxDist);
            
            if(!isShadowed)
            {
                BrdfData brdfData       = GetBrdfData(initialPayload, lightEval.m_pointToLightDirection);
                float3 lightDiffuse     = CalculateDiffuse_Lambert(brdfData);
                float3 lightSpecular    = CalculateSpecular_MicroFacet(brdfData);
                float3 f                = (1.0.xxx - brdfData.m_F) * lightDiffuse + lightSpecular;
                //float invPDF            = totalWeight / max(chosenWeight, EPS);
                //invPDF                  = min(invPDF, float(g_lightConsts.cb_numLights));
                //float3 color            = f * lightEval.m_incomingRadiance * invPDF * throughput;
                float3 color = f * lightEval.m_incomingRadiance * chosenWeight * throughput;
                
                if (!IsFiniteFloat3(color))
                    color = 0;

                float maxContrib        = 20.f / max(Luminance(throughput), 0.01f);

                color                   = ClampRadiance(color, maxContrib);
                
                indirectColor.rgb += color;
            }    
        }        
    }
    
    return indirectColor;
}

//-------------------------------------------------------------------------------------------------------------------------------------
[shader("raygeneration")]
void RayGenShader()
{
    uint2 pixel = DispatchRaysIndex().xy;
        
    float3 hitPosition              = g_positionGBuffer[pixel].xyz;
    float3 pixelNormal              = DecodeRGBtoXYZ(g_normalsGBuffer[pixel].xyz);
    float3 surfaceNormal            = DecodeRGBtoXYZ(g_surfaceNormalGBuffer[pixel].xyz);
    float4 baseColor                = g_albedoGBuffer[pixel];
    float roughness                 = g_rmGBuffer[pixel].g;
    float metalness                 = g_rmGBuffer[pixel].b;
    g_prevNormalGBuffer[pixel].xyz  = g_normalsGBuffer[pixel].xyz;
    g_prevDepthGBuffer[pixel].xyz   = g_depthBuffer[pixel].xyz;
    
    if (g_debugConsts.cb_debugView > 0 && g_debugConsts.cb_debugView != 9)
    {
        g_denoisedRenderOutput[pixel]   = DebugViews();
        g_noisyRenderOutput[pixel]      = DebugViews();
        return;
    }
                
    RayPayload payload;
    payload.m_didHit            = true;
    payload.m_albedo            = g_albedoGBuffer[pixel].rgb;
    payload.m_pixelNormal       = DecodeRGBtoXYZ(g_normalsGBuffer[pixel].xyz);
    payload.m_roughness         = g_rmGBuffer[pixel].g;
    payload.m_metalness         = g_rmGBuffer[pixel].b;
    payload.m_surfaceNormal     = DecodeRGBtoXYZ(g_surfaceNormalGBuffer[pixel].xyz);
    payload.m_worldRayDirection = normalize(hitPosition - g_cameraConsts.cb_cameraPosition.xyz);
    payload.m_worldPosition     = g_positionGBuffer[pixel].xyz;
    
    float4 finalLighting = float4(0.f.xxx, 1.f);
    
    if(g_appSettings.cb_doDirect == 1)
    {
        finalLighting = DoReSTIR(payload);
    }

    if (g_appSettings.cb_doIndirect == 1)
    {
        finalLighting += DoIndirectLighting(payload);
    } 
   
    float4 lastFramePixelColor  = g_noisyRenderOutput[pixel];
    float4 lerpFactor           = g_appSettings.cb_accumCount / (g_appSettings.cb_accumCount + 1.0f);
    float3 blended              = lerp(finalLighting.rgb, lastFramePixelColor.xyz, lerpFactor.xxx);

    g_denoisedRenderOutput[pixel]   = float4(blended, 1.0f);
    g_noisyRenderOutput[pixel]      = float4(blended, 1.0f);
}

//-------------------------------------------------------------------------------------------------------------------------------------
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

    float3 bary = float3(1.0f - attribs.barycentrics.x - attribs.barycentrics.y, attribs.barycentrics.x, attribs.barycentrics.y);

    float2 uv = v0.v_uvCoords * bary.x + v1.v_uvCoords * bary.y + v2.v_uvCoords * bary.z;

    uv.y = 1.f - uv.y;

    float3 normal = v0.v_normal * bary.x + v1.v_normal * bary.y + v2.v_normal * bary.z;

    float3 tangent = v0.v_tangent * bary.x + v1.v_tangent * bary.y + v2.v_tangent * bary.z;

    float3 bitangent = v0.v_bitangent * bary.x + v1.v_bitangent * bary.y + v2.v_bitangent * bary.z;

    normal      = SafeNormalize(normal);
    tangent     = SafeNormalize(tangent);
    bitangent   = SafeNormalize(bitangent);

    float3 pixelNormal = normal;

    // Normal map
    if (meshInfo.m_materialInfo.m_normalIndex != -1)
    {
        Texture2D normalTex = g_textures[meshInfo.m_materialInfo.m_normalIndex];
        float3 normalTS     = DecodeRGBtoXYZ(SampleTexture(normalTex, uv, meshInfo.m_materialInfo.m_normalSamplerIndex).rgb);

        float3x3 TBN    = float3x3(tangent, bitangent, normal);
        pixelNormal     = normalize(mul(normalTS, TBN));
    }

    float3 albedo = 1.f.xxx;
    if (meshInfo.m_materialInfo.m_albedoIndex != -1)
    {
        Texture2D albedoTex = g_textures[meshInfo.m_materialInfo.m_albedoIndex];
        albedo              = SampleTexture(albedoTex, uv, meshInfo.m_materialInfo.m_albedoSamplerIndex).rgb;
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

    payload.m_worldPosition     = hitLocation;
    payload.m_worldRayDirection = WorldRayDirection();

    payload.m_surfaceNormal     = normal;
    payload.m_pixelNormal       = pixelNormal;
    payload.m_worldTangent      = tangent;
    payload.m_worldBitangent    = bitangent;

    payload.m_albedo    = albedo;
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
