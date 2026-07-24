//---------------------------------------------------------------------------------------------------------------------------------------------
// PASS 2 of ?: Temporal Reuse
// ToDo: Add Checks for prev depth and prev position
//---------------------------------------------------------------------------------------------------------------------------------------------
#include "Includes/Reservoir.hlsli"
#include "Includes/RTDataStructures.hlsli"
#include "Includes/RNG.hlsli"
#include "Includes/Resources.hlsli"

//-------------------------------------------------------------------------------------------------------------------------------------
bool CombineReservoir(inout Reservoir currentFrameReservoir, Reservoir otherReservoir, float rand, float3 hitPosition, float3 shadingNormal, float3 albedo)
{
    otherReservoir.m_numProcessedLights = min(otherReservoir.m_numProcessedLights, 20 * currentFrameReservoir.m_numProcessedLights);
    uint numProcessedLightsByBothReservoirs = otherReservoir.m_numProcessedLights + currentFrameReservoir.m_numProcessedLights;
    
    StructuredBuffer<Light> lightBuffer = g_sceneLightsBuffer[g_sceneConsts.cb_lightBufferIndex];
    Light light = lightBuffer[otherReservoir.m_importantLightIndex];
    
    LightEval otherReservoirLightEval = EvalLightAtPoint(light, hitPosition);
        
    float cosTheta = saturate(dot(shadingNormal, otherReservoirLightEval.m_pointToLightDirection));
    float3 brdf = albedo / PI; // assuming lambertian
    
    float otherReservoirLightTargetPDF = Luminance(brdf * otherReservoirLightEval.m_incomingRadiance * cosTheta);
    
    float otherWeight = otherReservoir.m_weightOfImportantLight * otherReservoir.m_numProcessedLights * otherReservoirLightTargetPDF;
    currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights += otherWeight;
    
    if(rand < otherWeight/currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights)
    {
        currentFrameReservoir.m_importantLightIndex = otherReservoir.m_importantLightIndex;
    }
    
    currentFrameReservoir.m_numProcessedLights = numProcessedLightsByBothReservoirs;
 
    Light newLight = lightBuffer[currentFrameReservoir.m_importantLightIndex];
    LightEval newLightEval = EvalLightAtPoint(newLight, hitPosition);
    cosTheta = saturate(dot(shadingNormal, newLightEval.m_pointToLightDirection));

    
    float newLightTargetPDF = Luminance(brdf * newLightEval.m_incomingRadiance * cosTheta);
    currentFrameReservoir.m_weightOfImportantLight = (newLightTargetPDF > 1e-6 && currentFrameReservoir.m_numProcessedLights > 0) ? 
                                                                currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights / (currentFrameReservoir.m_numProcessedLights * newLightTargetPDF) 
                                                              : 0.f;
    return true;
}
//---------------------------------------------------------------------------------------------------------------------------------------------
[numthreads(8, 8, 1)]
void ComputeMain(uint3 threadID: SV_DispatchThreadID)
{
    uint2 pixelCoords = threadID.xy;
    float2 pixelUVs = (pixelCoords + 0.5f) / g_cameraConsts.cb_screenDims;
    
    // Get reservoir index for this pixel for this frame
    uint reservoirIndex = (g_cameraConsts.cb_screenDims.x * pixelCoords.y) + pixelCoords.x;

    // get the coord of the pixel that was shading the point  
    float2 motionVector = g_velocityGBuffer[pixelCoords].xy;
    float2 prevPixelUVs = pixelUVs + motionVector;
    
    
    uint2 prevPixelCoords = uint2(prevPixelUVs * g_cameraConsts.cb_screenDims);
    
    if (prevPixelCoords.x >= g_cameraConsts.cb_screenDims.x || prevPixelCoords.y >= g_cameraConsts.cb_screenDims.y)
    {
        return;
    }
        
    float3 currentNormal    = DecodeRGBtoXYZ(g_normalsGBuffer[pixelCoords].xyz);
    float3 prevNormal       = DecodeRGBtoXYZ(g_prevNormalGBuffer[prevPixelCoords].xyz);
       
    if (dot(currentNormal, prevNormal) < 0.95f)
    {
        return;
    }
    
    if (abs(g_prevDepthGBuffer[prevPixelCoords].x - g_depthBuffer[pixelCoords].x) > 0.1f)
    {
        return;
    }
    
    // Get the reservoir index of the prev pixel for prev frame
    uint prevReservoirIndex = (g_cameraConsts.cb_screenDims.x * prevPixelCoords.y) + prevPixelCoords.x;
    
    Reservoir currentReservoir = g_temporalReservoirBuffer[reservoirIndex];
    Reservoir prevReservoir = g_prevReservoirBuffer[prevReservoirIndex];
    
    uint seed = GetSeedForRNG(pixelCoords.x, pixelCoords.y);
    seed = GetSeedForRNG(seed, g_appSettings.cb_frameCount);
    float rand = RollRandomFloatZeroToOneAndUpdateSeed(seed);
    
    CombineReservoir(currentReservoir, prevReservoir, rand, g_positionGBuffer[pixelCoords].xyz, currentNormal, g_albedoGBuffer[pixelCoords].xyz);
    
    g_temporalReservoirBuffer[reservoirIndex]   = currentReservoir;
    g_finalReservoirBuffer[reservoirIndex]      = currentReservoir;    
}