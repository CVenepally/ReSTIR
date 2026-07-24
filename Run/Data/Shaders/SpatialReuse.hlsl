//---------------------------------------------------------------------------------------------------------------------------------------------
// PASS 3 of ?: Spatial Reuse
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
    
    if (rand < otherWeight / currentFrameReservoir.m_sumOfWeightsOfAllProcessedLights)
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
    uint reservoirIndex = (g_cameraConsts.cb_screenDims.x * pixelCoords.y) + pixelCoords.x;
       
    Reservoir currentReservoir = g_temporalReservoirBuffer[reservoirIndex];
    float3 hitPosition = g_positionGBuffer[pixelCoords].xyz;
    
    uint seed = GetSeedForRNG(pixelCoords.x, pixelCoords.y);
    seed = GetSeedForRNG(seed, g_appSettings.cb_frameCount);
    
    int samplingRadius  = g_appSettings.cb_spatialReuseSamplingRadius;
    int numCandidates   = g_appSettings.cb_spatialReuseSamplesPerIteration;
    
    float3 currentNormal = DecodeRGBtoXYZ(g_normalsGBuffer[pixelCoords].xyz);
    float currentDepth = g_depthBuffer[pixelCoords].r;
    
    for (int i = 0; i < numCandidates; i++)
    {
        int2 offset;
        offset.x = (int) (RollRandomFloatZeroToOneAndUpdateSeed(seed) * (2 * samplingRadius + 1)) - samplingRadius;
        offset.y = (int) (RollRandomFloatZeroToOneAndUpdateSeed(seed) * (2 * samplingRadius + 1)) - samplingRadius;

        uint2 neighborPixel = pixelCoords + offset;
        
        uint neighborIndex = g_cameraConsts.cb_screenDims.x * neighborPixel.y + neighborPixel.x;
        Reservoir neighborReservoir = g_temporalReservoirBuffer[neighborIndex];

        if (!IsReservoirValid(neighborReservoir, g_sceneConsts.cb_numLights))
        {
            continue;
        }

        if (neighborReservoir.m_importantLightIndex >= g_sceneConsts.cb_numLights)
        {
            continue;
        }

        float3 neighborNormal   = DecodeRGBtoXYZ(g_normalsGBuffer[neighborPixel].xyz);
        float neighborDepth     = g_depthBuffer[neighborPixel].r;
        
        if(dot(currentNormal, neighborNormal) < 0.95f)
        {
            continue;
        }
        
        if(abs(currentDepth - neighborDepth) > 0.05f)
        {
            continue;
        }

        
        float rand = RollRandomFloatZeroToOneAndUpdateSeed(seed);
        CombineReservoir(currentReservoir, neighborReservoir, rand, hitPosition, currentNormal, g_albedoGBuffer[pixelCoords].xyz);
    }

    g_finalReservoirBuffer[reservoirIndex] = currentReservoir;
    
}