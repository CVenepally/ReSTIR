Texture2D       rasterTexture       : register(t0, space0);
Texture2D       raytracedTexture    : register(t1, space0);
//Texture2D       depthTexture        : register(t2, space0);
SamplerState    diffuseSampler      : register(s0, space0);

///Constant Buffers--------------------------------------------------------------------------------------------------------------------------------------------------
cbuffer CameraConstants : register(b2, space0)
{
    float4x4 cb_worldToCameraTransform;
    float4x4 cb_cameraToRenderTransform;
    float4x4 cb_renderToClipTransform;
};

cbuffer ModelConstants : register(b3, space0)
{
    float4x4 modelTransform;
    float4 color;
};


struct VertexInput
{
    float3 v_position   : POSITION;
    float4 v_color      : COLOR;
    float2 v_texCoord   : TEXCOORD;
};

struct PixelInput
{
    float4 p_position   : SV_Position;
    float4 p_color      : COLOR;
    float2 p_texCoords  : TEXCOORDS;
};

PixelInput VertexMain(VertexInput vertexInput)
{
    
    float4 modelPosition    = float4(vertexInput.v_position, 1);
    float4 worldPosition    = mul(modelTransform, modelPosition);
    float4 cameraPosition   = mul(cb_worldToCameraTransform, worldPosition);
    float4 renderPosition   = mul(cb_cameraToRenderTransform, cameraPosition);
    float4 clipPosition     = mul(cb_renderToClipTransform, renderPosition);

    
    PixelInput pixelIn;
    pixelIn.p_position = clipPosition;
    pixelIn.p_color = vertexInput.v_color;
    pixelIn.p_texCoords = vertexInput.v_texCoord;
    return pixelIn;
}

float4 PixelMain(PixelInput input) : SV_Target0
{
    float2 uv = input.p_texCoords;
    uv.y = 1.0f - uv.y;
    
    float4 rasterColor  = rasterTexture.Sample(diffuseSampler, uv);
    float4 rtColor      = raytracedTexture.Sample(diffuseSampler, uv);

    float3 finalColor = rasterColor.rgb + rtColor.rgb * (1.f - rasterColor.a);
    
//    float4 finalColor = lerp(rtColor, rasterColor, 0.1f);
    return float4(finalColor, rtColor.a);
}
