//---------------------------------------------------------------------------------------------------------------------------------------------
// PASS 2 of ?: Temporal Reuse
// ToDo: Add Checks for prev depth and prev position
//---------------------------------------------------------------------------------------------------------------------------------------------
#include "Includes/Reservoir.hlsli"
#include "Includes/RTDataStructures.hlsli"
#include "Includes/RNG.hlsli"
#include "Includes/Resources.hlsli"

////---------------------------------------------------------------------------------------------------------------------------------------------
//RWTexture2D<float4> g_positionGBuffer                   : register(u1, space0);
//RWTexture2D<float4> g_normalsGBuffer                    : register(u1, space1);
//RWTexture2D<float4> g_velocityGBuffer                   : register(u1, space9);
//RWTexture2D<float4> g_previousNormalsGBuffer            : register(u1, space10); 

//RWStructuredBuffer<Reservoir> g_finalReservoirBuffer    : register(u2, space0);
//RWStructuredBuffer<Reservoir> g_prevReservoirBuffer     : register(u2, space1);
//RWStructuredBuffer<Reservoir> g_temporalReservoirBuffer : register(u2, space2);

//ConstantBuffer<AppSettings>     g_appSettings           : register(b1, space0);
//ConstantBuffer<CameraConstants> g_cameraConsts          : register(b2, space0);
//ConstantBuffer<LightConstants>  g_lightConsts            : register(b4, space0);

//-------------------------------------------------------------------------------------------------------------------------------------
bool CombineReservoir(inout Reservoir currentFrameReservoir, Reservoir otherReservoir, float rand, float3 hitPosition)
{
    otherReservoir.m_numProcessedLights = min(otherReservoir.m_numProcessedLights, 20 * currentFrameReservoir.m_numProcessedLights);
    uint numProcessedLightsByBothReservoirs = otherReservoir.m_numProcessedLights + currentFrameReservoir.m_numProcessedLights;
    
    LightEval otherReservoirLightEval = EvalLightAtPoint(g_lightConsts.cb_allLights[otherReservoir.m_importantLightIndex], hitPosition);
    float otherReservoirLightTargetPDF = Luminance(otherReservoirLightEval.m_incomingRadiance);
    
    float otherWeight = otherReservoir.m_weightOfImportantLight * otherReservoir.m_numProcessedLights * otherReservoirLightTargetPDF;
    currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights += otherWeight;
    
    if(rand < otherWeight/currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights)
    {
        currentFrameReservoir.m_importantLightIndex = otherReservoir.m_importantLightIndex;
    }
    
    currentFrameReservoir.m_numProcessedLights = numProcessedLightsByBothReservoirs;
    
    LightEval newLightEval = EvalLightAtPoint(g_lightConsts.cb_allLights[currentFrameReservoir.m_importantLightIndex], hitPosition);
    float newLightTargetPDF = Luminance(newLightEval.m_incomingRadiance);
    currentFrameReservoir.m_weightOfImportantLight = (newLightTargetPDF > 1e-6 && currentFrameReservoir.m_numProcessedLights > 0)
    ? currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights / (currentFrameReservoir.m_numProcessedLights * newLightTargetPDF)
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
        
    float3 currentNormal = DecodeRGBtoXYZ(g_normalsGBuffer[pixelCoords].xyz);
    float3 prevNormal = DecodeRGBtoXYZ(g_prevNormalGBuffer[prevPixelCoords].xyz);
       
    if (dot(currentNormal, prevNormal) < 0.99f)
    {
        return;
    }
    
    if (abs(g_prevDepthGBuffer[prevPixelCoords].x - g_depthBuffer[pixelCoords].x) > 0.01f)
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
    
    CombineReservoir(currentReservoir, prevReservoir, rand, g_positionGBuffer[pixelCoords].xyz);
    
    g_temporalReservoirBuffer[reservoirIndex]   = currentReservoir;
    g_finalReservoirBuffer[reservoirIndex]      = currentReservoir;    
}