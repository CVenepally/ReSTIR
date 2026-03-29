#pragma once
#include "RTDataStructures.hlsli"
#include "RTUtils.hlsli"
#include "BRDF.hlsli"
//-------------------------------------------------------------------------------------------------------------------------------------
struct LightEval
{
    float3 m_pointToLightDirection;
    float3 m_incomingRadiance;
    
    float m_maxDist;
};

//-------------------------------------------------------------------------------------------------------------------------------------
LightEval EvalLightAtPoint(Light light, float3 hitPosition)
{
    LightEval evalResult;
    evalResult.m_pointToLightDirection = float3(0.f, 0.f, 1.f);
    evalResult.m_incomingRadiance = float3(0.f, 0.f, 0.f);
    
    evalResult.m_maxDist = FP32Max;
    
    if (light.l_lightType == 0)
    {
        float3 lightToPixel = normalize(light.l_direction);
        evalResult.m_pointToLightDirection = -lightToPixel;
        evalResult.m_incomingRadiance = light.l_color.rgb * light.l_color.a;
        evalResult.m_maxDist = FP32Max;
    }
    else if (light.l_lightType == 1)
    {
        float3 pointToLight = light.l_position - hitPosition;
        
        float squaredDistance = dot(pointToLight, pointToLight);
        float distance = sqrt(max(squaredDistance, 1e-8));
        
        evalResult.m_pointToLightDirection = SafeNormalize(pointToLight) / distance;
        
    //    float minDist = 1e-6;
        
        float minDist = (0.00001f * 0.00001f);
        
        float sqDistanceInverse = 1 / max(squaredDistance, minDist);
        evalResult.m_incomingRadiance = light.l_color.rgb * light.l_color.a * sqDistanceInverse;
        evalResult.m_incomingRadiance = ClampRadiance(evalResult.m_incomingRadiance, 50.f);
        evalResult.m_maxDist = distance;
    }
    
    return evalResult;    
}

//-------------------------------------------------------------------------------------------------------------------------------------
float ComputeLightWeight(BrdfData data, LightEval eval)
{
    float nDotL = saturate(dot(data.m_pixelNormal, eval.m_pointToLightDirection));
    if((nDotL) <= 0.f)
        return 0.f;
    
    float radianceLum = Luminance(eval.m_incomingRadiance);
    
    return max(radianceLum * nDotL, 1e-4f);
}

