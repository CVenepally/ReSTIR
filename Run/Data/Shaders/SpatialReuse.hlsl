//---------------------------------------------------------------------------------------------------------------------------------------------
// PASS 3 of ?: Spatial Reuse
//---------------------------------------------------------------------------------------------------------------------------------------------
#include "Includes/Reservoir.hlsli"
#include "Includes/RTDataStructures.hlsli"
#include "Includes/RNG.hlsli"
#include "Includes/Resources.hlsli"

//-------------------------------------------------------------------------------------------------------------------------------------
bool CombineReservoir(inout Reservoir currentFrameReservoir, Reservoir otherReservoir, float rand, float3 hitPosition)
{
    otherReservoir.m_numProcessedLights = min(otherReservoir.m_numProcessedLights, 20 * currentFrameReservoir.m_numProcessedLights);
    uint numProcessedLightsByBothReservoirs = otherReservoir.m_numProcessedLights + currentFrameReservoir.m_numProcessedLights;
    
    LightEval otherReservoirLightEval = EvalLightAtPoint(g_lightConsts.cb_allLights[otherReservoir.m_importantLightIndex], hitPosition);
    float otherReservoirLightTargetPDF = Luminance(otherReservoirLightEval.m_incomingRadiance);
    
    float otherWeight = otherReservoir.m_weightOfImportantLight * otherReservoir.m_numProcessedLights * otherReservoirLightTargetPDF;
    currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights += otherWeight;
    
    if (rand < otherWeight / currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights)
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
    uint reservoirIndex = (g_cameraConsts.cb_screenDims.x * pixelCoords.y) + pixelCoords.x;
       
    Reservoir currentReservoir = g_temporalReservoirBuffer[reservoirIndex];
    float3 hitPosition = g_positionGBuffer[pixelCoords].xyz;
    
    uint seed = GetSeedForRNG(pixelCoords.x, pixelCoords.y);
    seed = GetSeedForRNG(seed, g_appSettings.cb_frameCount);
    
    int samplingRadius  = g_appSettings.cb_spatialReuseSamplingRadius;
    int numCandidates   = g_appSettings.cb_spatialReuseSamplesPerIteration;
    
    for (int i = 0; i < numCandidates; i++)
    {
        int2 offset;
        offset.x = (int) (RollRandomFloatZeroToOneAndUpdateSeed(seed) * (2 * samplingRadius + 1)) - samplingRadius;
        offset.y = (int) (RollRandomFloatZeroToOneAndUpdateSeed(seed) * (2 * samplingRadius + 1)) - samplingRadius;

        uint2 neighborPixel = pixelCoords + offset;
        
        uint neighborIndex = g_cameraConsts.cb_screenDims.x * neighborPixel.y + neighborPixel.x;
        Reservoir neighborReservoir = g_temporalReservoirBuffer[neighborIndex];

        if (!IsReservoirValid(neighborReservoir))
        {
            continue;
        }

        if (neighborReservoir.m_importantLightIndex >= g_lightConsts.cb_numLights)
        {
            continue;
        }

        float rand = RollRandomFloatZeroToOneAndUpdateSeed(seed);
        CombineReservoir(currentReservoir, neighborReservoir, rand, hitPosition);
    }

    g_finalReservoirBuffer[reservoirIndex] = currentReservoir;
    
}