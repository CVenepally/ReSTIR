#pragma once
#include "RNG.hlsli"
#include "Sampling.hlsli"

#define UINT32_MAX 0xffffffffu

//-------------------------------------------------------------------------------------------------------------------------------------
struct Reservoir
{
    uint    m_importantLightIndex;
    float   m_weightOfImportantLight;
    float   m_sumOfWeightsOfAllProcessedLights; // All processed Lights for this pixel's reservoir
    int     m_numProcessedLights;
};

//-------------------------------------------------------------------------------------------------------------------------------------
void InitReservoir(inout Reservoir res)
{
    res.m_importantLightIndex = UINT32_MAX;
    res.m_weightOfImportantLight = 0.f;
    res.m_sumOfWeightsOfAllProcessedLights = 0.f;
    res.m_numProcessedLights = 0;
}

//-------------------------------------------------------------------------------------------------------------------------------------
// Returns true if the old light index is replaced with the new light index
bool UpdateReservoir(inout Reservoir reservoirToUpdate, uint sampledLightIndex, float sampledLightWeight, inout uint randSeed)
{
    reservoirToUpdate.m_sumOfWeightsOfAllProcessedLights += sampledLightWeight;
    reservoirToUpdate.m_numProcessedLights += 1;
    
    // Roll a random float from 0 to 1. If the float is less than weight of light / totalReservoirWeight, the light index and lights weight are replaced.
    if (RollRandomFloatZeroToOneAndUpdateSeed(randSeed) * reservoirToUpdate.m_sumOfWeightsOfAllProcessedLights < sampledLightWeight)
    {
        reservoirToUpdate.m_importantLightIndex = sampledLightIndex;
        return true;
    }

    return false;    
}

//-------------------------------------------------------------------------------------------------------------------------------------
bool IsReservoirValid(Reservoir reservoirToCheck)
{
    return (reservoirToCheck.m_importantLightIndex < UINT32_MAX);
}

