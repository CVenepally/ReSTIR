#pragma once

#define EPS 1e-4f 

//-------------------------------------------------------------------------------------------------------------------------------------
// Util Functions
//-------------------------------------------------------------------------------------------------------------------------------------
float4 UnpackColors(uint color)
{
    float4 unpackedColor;
    
    unpackedColor.r = ((color >> 0) & 0xFF) / 255.f;
    unpackedColor.g = ((color >> 8) & 0xFF) / 255.f;
    unpackedColor.b = ((color >> 16) & 0xFF) / 255.f;
    unpackedColor.a = ((color >> 32) & 0xFF) / 255.f;
    
    return unpackedColor;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float RangeMap(float inValue, float inStart, float inEnd, float outStart, float outEnd)
{    
    float denom = (inEnd - inStart);
    if (abs(denom) < 1e-20f)
        return outStart;
    float fraction = (inValue - inStart) / denom;

    float outValue = outStart + fraction * (outEnd - outStart);
    return outValue;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float3 EncodeXYZtoRGB(float3 xyzToEncode)
{
    return (xyzToEncode + 1.f) * 0.5f;
}

//------------------------------------------------------------------------------------------------
float3 DecodeRGBtoXYZ(float3 rgbToDecode)
{
    return (rgbToDecode * 2.f) - 1.f;
}

//------------------------------------------------------------------------------------------------
bool IsFloat3Zero(float3 float3ToCheck)
{
    return float3ToCheck.x == 0 && float3ToCheck.y == 0 && float3ToCheck.z == 0;
}

//------------------------------------------------------------------------------------------------
bool IsFiniteFloat(float x)
{
    return (x == x) && abs(x) < 3.0e38f;
} 

//------------------------------------------------------------------------------------------------
bool IsFiniteFloat3(float3 v)
{
    return IsFiniteFloat(v.x) && IsFiniteFloat(v.y) && IsFiniteFloat(v.z);
}

//------------------------------------------------------------------------------------------------
float3 SafeNormalize(float3 v)
{
    float len2 = dot(v, v);
    if (len2 <= 1e-20f)
        return float3(0, 0, 1);
    return v * rsqrt(len2);
}

//------------------------------------------------------------------------------------------------
float3 ClampRadiance(float3 c, float maxLum)
{
    if (!IsFiniteFloat3(c))
        return 0.0.xxx;
    float lum = dot(c, float3(0.2126f, 0.7152f, 0.0722f));
    if (lum <= maxLum)
        return c;
    return c * (maxLum / max(lum, 1e-8f));
}