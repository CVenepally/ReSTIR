//-------------------------------------------------------------------------------------------------------------------------------------
//PASS 1 of ?: GBUFFER PASS
// This is where all the geometry and material data for points where the primary ray hits
// This is also where Reservoirs are initialized and created for initial hits.
// Pass 2 is Temporal Reuse
//-------------------------------------------------------------------------------------------------------------------------------------


//-------------------------------------------------------------------------------------------------------------------------------------
// Util Structs
//-------------------------------------------------------------------------------------------------------------------------------------
#include "Includes/RTUtils.hlsli"
#include "Includes/RTDataStructures.hlsli"
#include "Includes/RNG.hlsli"
#include "Includes/Reservoir.hlsli"
#include "Includes/Sampling.hlsli"
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
float2 ConvertWorldPositionToScreenPosition(float3 worldPosition, float4x4 worldToCameraTransform)
{
    float4 worldPosition4 = float4(worldPosition, 1);

    float4 currentCameraSpacePosition = mul(g_cameraConsts.cb_currentFrameWorldToCamera, worldPosition4);
    float4 currentRenderSpacePosition = mul(g_cameraConsts.cb_cameraToRender, currentCameraSpacePosition);
    float4 currentClipSpacePosition = mul(g_cameraConsts.cb_renderToClip, currentRenderSpacePosition);
    currentClipSpacePosition.xyz /= currentClipSpacePosition.w;
//    currentClipSpacePosition.y *= -1;
    
    float2 currentScreenSpacePosition = (currentClipSpacePosition.xy + 1.f) * 0.5f;
    
    return currentScreenSpacePosition;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float4 CalculateMotionVector(float3 worldPosition)
{
    float4 worldPosition4 = float4(worldPosition, 1);

    float4 currentCameraSpacePosition   = mul(g_cameraConsts.cb_currentFrameWorldToCamera, worldPosition4);
    float4 currentRenderSpacePosition   = mul(g_cameraConsts.cb_cameraToRender, currentCameraSpacePosition);
    float4 currentClipSpacePosition     = mul(g_cameraConsts.cb_renderToClip, currentRenderSpacePosition);
    currentClipSpacePosition.xyz /= currentClipSpacePosition.w;
//    currentClipSpacePosition.y *= -1;
    
    float2 currentScreenSpacePosition = (currentClipSpacePosition.xy + 1.f) * 0.5f;

    float4 prevCameraSpacePosition  = mul(g_cameraConsts.cb_prevFrameWorldToCamera, worldPosition4);
    float4 prevRenderSpacePosition = mul(g_cameraConsts.cb_cameraToRender, prevCameraSpacePosition);
    float4 prevClipSpacePosition = mul(g_cameraConsts.cb_renderToClip, prevRenderSpacePosition);
    prevClipSpacePosition.xyz /= prevClipSpacePosition.w;
 //   prevClipSpacePosition.y *= -1;
    
    float2 prevScreenSpacePosition = (prevClipSpacePosition.xy + 1.f) * 0.5f;
    
    float2 motionVec = prevScreenSpacePosition - currentScreenSpacePosition;
    
    return prevClipSpacePosition.w < EPS ? float4(0.f.xx, 0.f, 1.f) : float4(motionVec, 0.f, 1.f);
}

//-------------------------------------------------------------------------------------------------------------------------------------
Reservoir CreatePixelReservoirCurrentFrame()
{
    Reservoir currentFrameReservoir;
    InitReservoir(currentFrameReservoir);
    
    uint randSeed = GetSeedForRNG(DispatchRaysIndex().x, DispatchRaysIndex().y);
    randSeed = GetSeedForRNG(randSeed, g_appSettings.cb_frameCount);
    
    float pdf = 1.f / g_lightConsts.cb_numLights;
    float p_hat = 0.f;
    int M = g_appSettings.cb_maxSamples;
    
    for (uint i = 0; i < M; i++)
    {
        uint lightIndex = min((uint) (RollRandomFloatZeroToOneAndUpdateSeed(randSeed) * g_lightConsts.cb_numLights), g_lightConsts.cb_numLights - 1);
        
        float3 hitPosition = g_positionGBuffer[DispatchRaysIndex().xy].xyz;
        
        LightEval eval = EvalLightAtPoint(g_lightConsts.cb_allLights[lightIndex], hitPosition);
                
        p_hat = Luminance(eval.m_incomingRadiance);
                
        if (!IsFiniteFloat(p_hat) || p_hat <= 0)
            continue;
                
        float weightOfLight = p_hat / pdf;
                
        if (!IsFiniteFloat(weightOfLight) || weightOfLight <= 0)
            continue;
  
        UpdateReservoir(currentFrameReservoir, lightIndex, weightOfLight, randSeed);
    }

    uint lightIndex = currentFrameReservoir.m_importantLightIndex;
    
    if(lightIndex > g_lightConsts.cb_numLights)
    {
        return currentFrameReservoir;
    }
    
    float3 hitPosition = g_positionGBuffer[DispatchRaysIndex().xy].xyz;
    float3 surfaceNormal = DecodeRGBtoXYZ(g_surfaceNormalGBuffer[DispatchRaysIndex().xy].xyz);
    Light light = g_lightConsts.cb_allLights[lightIndex];
    LightEval eval = EvalLightAtPoint(light, hitPosition);
                                
    //bool shadowed = IsPixelShadowedFromLight(hitPosition, eval.m_pointToLightDirection, surfaceNormal, eval.m_maxDist);
    
    //if (shadowed)
    //{
    //    return currentFrameReservoir;    
    //}
                    
    p_hat = Luminance(eval.m_incomingRadiance);
    currentFrameReservoir.m_weightOfImportantLight = p_hat > 0.f ? (currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights / p_hat) / currentFrameReservoir.m_numProcessedLights : 0.f;    
    return currentFrameReservoir;
}

//-------------------------------------------------------------------------------------------------------------------------------------
[shader("raygeneration")]
void RayGenShader()
{
    float2 pixel = (float2) DispatchRaysIndex();
    
    uint randSeed = GetSeedForRNG(pixel.x, pixel.y);
    randSeed = GetSeedForRNG(randSeed, g_appSettings.cb_frameCount);

    if (g_appSettings.cb_enableAA == 1)
    {
        float2 offset = float2(RollRandomFloatZeroToOneAndUpdateSeed(randSeed), RollRandomFloatZeroToOneAndUpdateSeed(randSeed));
    
        pixel += lerp(-0.5f.xx, 0.5f.xx, offset);
    }
    else
    {
        pixel += 0.5f;
    }
    
    float2 dims = (float2) DispatchRaysDimensions();

    // Convert to NDC[-1, 1]
    float2 screenPosition = pixel / dims;
    screenPosition = screenPosition * 2.f - 1.f;
    
    screenPosition.y *= -1.f;
    
    float4 renderPosition = mul(g_cameraConsts.cb_clipToRender, float4(screenPosition, 1, 1));
    renderPosition.xyz /= renderPosition.w;
    
    float4 cameraPosition = mul(g_cameraConsts.cb_renderToCamera, renderPosition);
    float4 worldPosition = mul(g_cameraConsts.cb_cameraToWorld, cameraPosition);
    float3 rayDirection = normalize(worldPosition.xyz - g_cameraConsts.cb_cameraPosition.xyz);
     
    uint2 index = (uint2) DispatchRaysIndex().xy;
    uint reservoirIndex = (DispatchRaysDimensions().x * index.y) + index.x;
    
    // Change temporal to be the reservoir buffer
 //   g_prevReservoirBuffer[reservoirIndex]   = g_finalReservoirBuffer[reservoirIndex];
    g_positionGBuffer[index].xyz            = float3(0.f, 0.f, 0.f);
    g_normalsGBuffer[index].xyz             = float3(0.f, 0.f, 0.f);
    g_albedoGBuffer[index]                  = float4(0.f, 0.f, 0.f, 0.f);
    g_rmGBuffer[index].xyz                  = float3(0.f, 1.f, 0.f);
    g_vertColorGBuffer[index]               = float4(0.f, 0.f, 0.f, 0.f);
    g_surfaceTangentGBuffer[index].xyz      = float3(0.f, 0.f, 0.f);
    g_surfaceBitangentGBuffer[index].xyz    = float3(0.f, 0.f, 0.f);
    g_surfaceNormalGBuffer[index].xyz       = float3(0.f, 0.f, 0.f);
    g_velocityGBuffer[index].xyz            = float3(0.f, 0.f, 0.f);
    g_depthBuffer[index]                    = 1.f.xxxx;
    
        
    // Ray desc
    RayDesc ray;
    ray.Origin = g_cameraConsts.cb_cameraPosition.xyz;
    ray.Direction = rayDirection.xyz;
    ray.TMin = 0.001f;
    ray.TMax = 10000.0f;

    RayPayload payload;
    payload.m_didHit = false;
    
    TraceRay(g_tlas, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0xFFFFFFFF, RAY_PRIMARY, RAY_COUNT, RAY_PRIMARY, ray, payload);
}

//-------------------------------------------------------------------------------------------------------------------------------------
// #ToDo: Clean this up. Add functions to get hit data. Make a HitData datastruct that stores World Space Hit Location, UVs, tangents, bitangets, normals at the hit location and any other required info. 
[shader("closesthit")]
void ClosestHitShader(inout RayPayload payload, in MyAttributes attribs)
{   
    uint2 pixel = DispatchRaysIndex().xy;
    // Position Buffer
    float3 hitLocation = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
    g_positionGBuffer[DispatchRaysIndex().xy].xyz = hitLocation;
    
    // Albedo and Normal Texel
    int geoIndex    = GeometryIndex(); // HLSL Intrisic to access the Hit Geometry's Index in a BLAS.
    int instIndex   = InstanceIndex(); // HLSL Intrisic to access the Hit Geometry's BLAS Instance in a TLAS.
    uint primIndex  = PrimitiveIndex(); // Hit Primitive Index of the hit geometry.

    int meshInfoIndex;
    
    if (instIndex == 0)
    {
        meshInfoIndex = geoIndex;
    }
    else
    {
        meshInfoIndex = geoIndex + instIndex;
    }

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
    
    float3 bary = float3(1.0f - attribs.barycentrics.x - attribs.barycentrics.y,
                         attribs.barycentrics.x,
                         attribs.barycentrics.y);
        
    float2 interpolatedUVs = v0.v_uvCoords * bary.x + v1.v_uvCoords * bary.y + v2.v_uvCoords * bary.z;
    interpolatedUVs.y = 1.f - interpolatedUVs.y;
    
    float4 v0Color = UnpackColors(v0.v_color);
    float4 v1Color = UnpackColors(v1.v_color);
    float4 v2Color = UnpackColors(v2.v_color);
    float4 interpolatedColor = v0Color * bary.x + v1Color * bary.y + v2Color * bary.z;
    g_vertColorGBuffer[pixel] = interpolatedColor;
    
    float3 interpolatedNormal      = v0.v_normal * bary.x + v1.v_normal * bary.y + v2.v_normal * bary.z;
    float3 interpolatedTangent     = v0.v_tangent * bary.x + v1.v_tangent * bary.y + v2.v_tangent * bary.z;
    float3 interpolatedBitangent   = v0.v_bitangent * bary.x + v1.v_bitangent * bary.y + v2.v_bitangent * bary.z;
    
    interpolatedNormal      = SafeNormalize(interpolatedNormal);
    interpolatedTangent     = SafeNormalize(interpolatedTangent);
    interpolatedBitangent   = SafeNormalize(interpolatedBitangent);
    
    g_surfaceTangentGBuffer[pixel].xyz = EncodeXYZtoRGB(interpolatedTangent);
    g_surfaceBitangentGBuffer[pixel].xyz = EncodeXYZtoRGB(interpolatedBitangent);
    g_surfaceNormalGBuffer[pixel].xyz = EncodeXYZtoRGB(interpolatedNormal);
    
    // Albedo
    if (meshInfo.m_materialInfo.m_albedoIndex != -1)
    {
        Texture2D albedoTex = g_textures[meshInfo.m_materialInfo.m_albedoIndex];
        
        float4 albedoSample = SampleTexture(albedoTex, interpolatedUVs, meshInfo.m_materialInfo.m_albedoSamplerIndex);
        g_albedoGBuffer[pixel] = albedoSample;
    }
    
    // Normal
    if (meshInfo.m_materialInfo.m_normalIndex != -1)
    {
        Texture2D normalTex = g_textures[meshInfo.m_materialInfo.m_normalIndex];
        float4 normalSample = SampleTexture(normalTex, interpolatedUVs, meshInfo.m_materialInfo.m_normalSamplerIndex);

        float3 normalTS     = normalize(DecodeRGBtoXYZ(normalSample.rgb));
        float3x3 TBN        = float3x3(interpolatedTangent, interpolatedBitangent, interpolatedNormal);
        g_normalsGBuffer[pixel].xyz = EncodeXYZtoRGB(normalize(mul(normalTS, TBN)));
    }
    else
    {
        g_normalsGBuffer[pixel].xyz = interpolatedNormal;
    }

    // Roughness and Metalness
    if (meshInfo.m_materialInfo.m_rmIndex != -1)
    {
        Texture2D metalTex      = g_textures[meshInfo.m_materialInfo.m_rmIndex];
        float4 metalSample      = SampleTexture(metalTex, interpolatedUVs, meshInfo.m_materialInfo.m_rmSamplerIndex);
        g_rmGBuffer[pixel].g    = saturate(metalSample.g); // roughness
        g_rmGBuffer[pixel].b    = saturate(metalSample.b); // metalness
    }
    
    // Velocity
    g_velocityGBuffer[pixel] = CalculateMotionVector(hitLocation);

    // CLEANUP - Current Pixel Reservoir    
    uint reservoirIndex = (DispatchRaysDimensions().x * pixel.y) + pixel.x;
    g_temporalReservoirBuffer[reservoirIndex] = CreatePixelReservoirCurrentFrame();
    g_finalReservoirBuffer[reservoirIndex] = g_temporalReservoirBuffer[reservoirIndex];
    
    // Dpeth Buffer
    g_depthBuffer[pixel].xyz = length(hitLocation - g_cameraConsts.cb_cameraPosition.xyz).xxx / 20.f;
}

//-------------------------------------------------------------------------------------------------------------------------------------
[shader("miss")]
void MissShader(inout RayPayload payload)
{
    uint2 pixel = DispatchRaysIndex().xy;

    g_positionGBuffer[pixel].xyz            = float3(0.f, 0.f, 0.f);
    g_normalsGBuffer[pixel].xyz             = float3(0.f, 0.f, 0.f);
    g_albedoGBuffer[pixel]                  = float4(0.f, 0.f, 0.f, 0.f);
    g_rmGBuffer[pixel].xyz                  = float3(0.f, 1.f, 0.f);
    g_vertColorGBuffer[pixel]               = float4(0.f, 0.f, 0.f, 0.f);
    g_surfaceTangentGBuffer[pixel].xyz      = float3(0.f, 0.f, 0.f);
    g_surfaceBitangentGBuffer[pixel].xyz    = float3(0.f, 0.f, 0.f);
    g_surfaceNormalGBuffer[pixel].xyz       = float3(0.f, 0.f, 0.f);
    g_depthBuffer[pixel]                    = 1.f.xxxx;
    
    uint reservoirIndex = (DispatchRaysDimensions().x * pixel.y) + pixel.x;
    InitReservoir(g_temporalReservoirBuffer[reservoirIndex]);
    InitReservoir(g_finalReservoirBuffer[reservoirIndex]);
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
