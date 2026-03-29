#pragma once
//-------------------------------------------------------------------------------------------------------------------------------------
//  GLOBAL CONSTANTS
//-------------------------------------------------------------------------------------------------------------------------------------
static const float FP32Max = 3.402823466e+38f;

//-------------------------------------------------------------------------------------------------------------------------------------
//  DATA STRUCTURES
//-------------------------------------------------------------------------------------------------------------------------------------
struct MaterialInfo
{
    int m_albedoIndex;
    int m_normalIndex;
    int m_aoIndex;
    int m_rmIndex;
    
    int m_albedoSamplerIndex;
    int m_normalSamplerIndex;
    int m_rmSamplerIndex;
    int padding0;
};

//-------------------------------------------------------------------------------------------------------------------------------------
struct MeshInfo
{
    int m_vbIndex;
    int m_ibIndex;
    int m_isStatic; // 1 is true 0 is false
    int padding;
    
    MaterialInfo m_materialInfo;
};

//-------------------------------------------------------------------------------------------------------------------------------------
struct Vertex_PCUTBN
{
    float3  v_position;
    uint    v_color;

    float2 v_uvCoords;
    float2 padding0;

    float3 v_tangent;
    float padding1;

    float3 v_bitangent;
    float padding2;

    float3 v_normal;
    float padding3;
};

//-------------------------------------------------------------------------------------------------------------------------------------
struct DebugConstants
{
    uint cb_debugView;
    uint cb_diffuseModel;
    uint cb_specularModel;
    uint cb_lightSamplingMethod;
    
    uint cb_envLighting;
    float3 cb_envLightingColor;
    
}; // b0

//-------------------------------------------------------------------------------------------------------------------------------------
struct AppSettings
{
    uint    cb_enableAA;
    uint    cb_enableFrameAccumulation;
    uint    cb_frameCount;
    uint    cb_accumCount;
    
    int     cb_maxSamples;
    uint    cb_minBounces;
    uint    cb_doDirect;
    uint    cb_doIndirect;
    
    int     cb_enableTemporalReuse;
    int     cb_enableSpatialReuse;
    int     cb_maxFramesToAccumulate;
    int     cb_spatialReuseSamplingRadius;
    
    int     cb_spatialReuseIterations;
    int     cb_spatialReuseSamplesPerIteration;
    int     cb_doDenoise;
    int     cb_denoiseRadius;
    
    float   cb_denoiseSigmaSpatial;
    float   cb_denoiseSigmaPosition;
    float   cb_denoiseNormalPower;
    int     cb_denoisePasses;
}; // b1


//-------------------------------------------------------------------------------------------------------------------------------------
struct CameraConstants 
{
    float4x4    cb_cameraToWorld;   
    float4x4    cb_prevView;        
    float4x4    cb_renderToCamera;
    float4x4    cb_clipToRender;    
    float4      cb_cameraPosition;  
    float4x4    cb_currentFrameWorldToCamera;
    float4x4    cb_prevFrameWorldToCamera;
    float4x4    cb_cameraToRender;
    float4x4    cb_renderToClip;
    float2      cb_screenDims;
    float2      padding;
}; // b2

//-------------------------------------------------------------------------------------------------------------------------------------
// Scene Constants ConstantBuffer is a scene specific buffer that holds Heap indexes to scene specific geometry buffer and scene specific material buffer
// which reside in the global GeometryBuffer (Buffer that holds multiple geometry infos) and global MaterialBuffer (buffer that holds multiple material infos)
struct SceneConstants 
{
    uint cb_sceneMeshInfoBufferIndex;
    uint cb_numStaticGeometry;

    float2 padding0;
}; // b3

//-------------------------------------------------------------------------------------------------------------------------------------
struct ShadowRayPayload
{
    bool srp_isShadowed;
};

//-------------------------------------------------------------------------------------------------------------------------------------
struct RayPayload
{
    bool    m_didHit;
    float3  m_worldPosition;
    float3  m_worldTangent;
    float3  m_worldBitangent;
    float3  m_worldRayDirection;
    float3  m_pixelNormal;
    float3  m_surfaceNormal;

    float2  m_uv;

    float3  m_albedo;
    float   m_metalness;
    float   m_roughness;

    bool    m_hasNormalMap;
};

//-------------------------------------------------------------------------------------------------------------------------------------
struct Light
{
    int l_lightType;
    float3 l_position;

    float3 l_direction;
    float padding0;

    float4 l_color; // alpha is intensity

    float l_innerRadius;
    float l_outerRadius;
    float l_innerDot;
    float l_outerDot;
};

//-------------------------------------------------------------------------------------------------------------------------------------
struct LightConstants
{
    Light cb_directionalLight;

    Light cb_allLights[256];

    int cb_numLights;
    float cb_ambientIntensity;
    float2 padding1;
}; // b4

//-------------------------------------------------------------------------------------------------------------------------------------
enum RayType
{
    RAY_PRIMARY = 0,
    RAY_SHADOW = 1,
    RAY_COUNT
};
