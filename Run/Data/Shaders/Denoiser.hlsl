#include "Includes/Resources.hlsli"


float SpatialWeight(int x, int y, float sigma)
{
    float r2 = float(x * x + y * y);
    return exp(-r2 / (2.0 * sigma * sigma));
}

[numthreads(8, 8, 1)]
void ComputeMain(uint3 threadID : SV_DispatchThreadID)
{
    uint2 pixel = threadID.xy;
    
    float2 screenDims = g_cameraConsts.cb_screenDims;
    
    if (pixel.x >= screenDims.x || pixel.y >= screenDims.y)
        return;

    float3 centerColor  = g_noisyRenderTarget[pixel].rgb;
    float3 centerPos    = g_positionGBuffer[pixel].xyz;
    float3 centerN      = DecodeRGBtoXYZ(g_normalsGBuffer[pixel].xyz);

    float3  accum   = 0.0.xxx;
    float   wsum    = 0.0;
    
    float radius        = g_appSettings.cb_denoiseRadius;
    float sigmaSpatial  = g_appSettings.cb_denoiseSigmaSpatial;
    float sigmaPosition = g_appSettings.cb_denoiseSigmaPosition;
    float normalPower   = g_appSettings.cb_denoiseNormalPower;
    
    for (int y = -radius; y <= radius; ++y)
    {
        for (int x = -radius; x <= radius; ++x)
        {
            int2 q = int2(pixel) + int2(x, y);
            q.x = clamp(q.x, 0, (int) screenDims.x - 1);
            q.y = clamp(q.y, 0, (int) screenDims.y - 1);

            float3 sampleColor = g_noisyRenderTarget[q].rgb;
            float3 samplePos = g_positionGBuffer[q].xyz;
            float3 sampleN = DecodeRGBtoXYZ(g_normalsGBuffer[q].xyz);

            float spatialW = SpatialWeight(x, y, sigmaSpatial);
            float dist = length(samplePos - centerPos);
            float posW = exp(-(dist * dist) / (2.0 * sigmaPosition * sigmaPosition));
            float normalW = pow(saturate(dot(centerN, sampleN)), normalPower);
            
            float w = spatialW * posW * normalW;

            accum += w * sampleColor;
            wsum += w;
        }
    }

    g_renderTarget[pixel] = float4(accum / max(wsum, 1e-5), 1.0);
}