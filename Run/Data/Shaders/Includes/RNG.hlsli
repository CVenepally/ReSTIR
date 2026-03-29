#pragma once

uint GetSeedForRNG(uint val0, uint val1, uint backoff = 16)
{    
    uint s0 = 0;
    
    [unroll]
    for (uint n = 0; n < backoff; ++n)
    {
        s0 += 0x9e3779b9;
        val0 += ((val1 << 4) + 0xa341316c) ^ (val1 + s0) ^ ((val1 >> 5) + 0xc8013ea4);
        val1 += ((val0 << 4) + 0xad90777d) ^ (val0 + s0) ^ ((val0 >> 5) + 0x7e95761e);
    }

    return val0;
}

//-------------------------------------------------------------------------------------------------------------------------------------
float RollRandomFloatZeroToOneAndUpdateSeed(inout uint seed)
{
    seed = (1664525u * seed + 1013904223u);
    return float(seed & 0x00FFFFFF) / float(0x01000000);
}