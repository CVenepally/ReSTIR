//#pragma once
//#include "RTDataStructures.hlsli"
//#include "Reservoir.hlsli"

////-------------------------------------------------------------------------------------------------------------------------------------
//typedef BuiltInTriangleIntersectionAttributes MyAttributes;

////-------------------------------------------------------------------------------------------------------------------------------------
//// Resources
////-------------------------------------------------------------------------------------------------------------------------------------
//// SRVs-------------------------------------
//RaytracingAccelerationStructure g_tlas                      : register(t0, space0);
//StructuredBuffer<Vertex_PCUTBN> g_vertices[]                : register(t0, space1);
//StructuredBuffer<uint>          g_indices[]                 : register(t0, space2);
//Texture2D                       g_textures[]                : register(t0, space3);
//StructuredBuffer<MeshInfo>      g_sceneMeshInfoBuffer[]     : register(t0, space4);

//// Render Textures--------------------------------------
//RWTexture2D<float4> g_renderTarget                          : register(u0, space0);
//RWTexture2D<float4> g_noisyRenderTarget                     : register(u0, space1);

//// GBuffers---------------------------------------------
//RWTexture2D<float4> g_positionGBuffer                       : register(u1,  space0);
//RWTexture2D<float4> g_baseColorGBuffer                      : register(u1,  space1);
//RWTexture2D<float4> g_shadingNormalGBuffer                  : register(u1,  space2);
//RWTexture2D<float4> g_surfaceNormalGBuffer                  : register(u1,  space3);
//RWTexture2D<float4> g_roughnessMetalnessGBuffer             : register(u1,  space4);
//RWTexture2D<float4> g_depthGBuffer                          : register(u1,  space5);
//RWTexture2D<float4> g_motionVectorGBuffer                   : register(u1,  space6);
//RWTexture2D<float4> g_historyLengthGBuffer                  : register(u1,  space7);
//RWTexture2D<float4> g_prevShadingNormalsGBuffer             : register(u1,  space8);
//RWTexture2D<float4> g_prevDepthGBuffer                      : register(u1,  space9);
//RWTexture2D<float4> g_partialDerivativesGBuffer             : register(u1, space10);

//// Reservoirs---------------------------------
//RWStructuredBuffer<Reservoir> g_finalReservoirBuffer        : register(u2, space0);
//RWStructuredBuffer<Reservoir> g_prevReservoirBuffer         : register(u2, space1);
//RWStructuredBuffer<Reservoir> g_temporalReservoirBuffer     : register(u2, space2);

//// ConstantBuffers--------------------------
//ConstantBuffer<DebugConstants>  g_debugConsts               : register(b0, space0);
//ConstantBuffer<AppSettings>     g_appSettings               : register(b1, space0);
//ConstantBuffer<CameraConstants> g_cameraConsts              : register(b2, space0);
//ConstantBuffer<SceneConstants>  g_sceneConsts               : register(b3, space0);
//ConstantBuffer<LightConstants>  g_lightConsts               : register(b4, space0);

//// Samplers---------------------------------
//SamplerState g_samplerPointClamp                            : register(s0, space0);
//SamplerState g_samplerBilinearWrap                          : register(s1, space0);
//SamplerState g_samplerBilinearComparisionBorder             : register(s2, space0);
//SamplerState g_samplerPointWrap                             : register(s3, space0);
//SamplerState g_samplerPointMirror                           : register(s4, space0);
//SamplerState g_samplerBilinearClamp                         : register(s5, space0);
//SamplerState g_samplerBilinearMirror                        : register(s6, space0);
//SamplerState g_samplerTrilinearWrap                         : register(s7, space0);
//SamplerState g_samplerTrilinearClamp                        : register(s8, space0);
//SamplerState g_samplerTrilinearMirror                       : register(s9, space0);

#pragma once
#include "RTDataStructures.hlsli"
#include "Reservoir.hlsli"

//-------------------------------------------------------------------------------------------------------------------------------------
typedef BuiltInTriangleIntersectionAttributes MyAttributes;

//-------------------------------------------------------------------------------------------------------------------------------------
// Resources
//-------------------------------------------------------------------------------------------------------------------------------------
// SRVs-------------------------------------
RaytracingAccelerationStructure g_tlas                  : register(t0, space0);
StructuredBuffer<Vertex_PCUTBN> g_vertices[]            : register(t0, space1);
StructuredBuffer<uint>          g_indices[]             : register(t0, space2);
Texture2D                       g_textures[]            : register(t0, space3);
StructuredBuffer<MeshInfo>      g_sceneMeshInfoBuffer[] : register(t0, space4);
StructuredBuffer<Light>         g_sceneLightsBuffer[]   : register(t0, space5);

// Render Textures--------------------------------------
RWTexture2D<float4> g_denoisedRenderOutput      : register(u0, space0);
RWTexture2D<float4> g_noisyRenderOutput         : register(u0, space1);

// GBuffers
RWTexture2D<float4> g_positionGBuffer           : register(u1, space0);
RWTexture2D<float4> g_normalsGBuffer            : register(u1, space1);
RWTexture2D<float4> g_surfaceNormalGBuffer      : register(u1, space2);
RWTexture2D<float4> g_depthBuffer               : register(u1, space3);
RWTexture2D<float4> g_velocityGBuffer           : register(u1, space4);
RWTexture2D<float4> g_albedoGBuffer             : register(u1, space5);
RWTexture2D<float4> g_rmGBuffer                 : register(u1, space6);
RWTexture2D<float4> g_prevNormalGBuffer         : register(u1, space7);
RWTexture2D<float4> g_prevDepthGBuffer          : register(u1, space8);

// Reservoirs---------------------------------
RWStructuredBuffer<Reservoir> g_finalReservoirBuffer    : register(u2, space0);
RWStructuredBuffer<Reservoir> g_prevReservoirBuffer     : register(u2, space1);
RWStructuredBuffer<Reservoir> g_temporalReservoirBuffer : register(u2, space2);

// ConstantBuffers--------------------------
ConstantBuffer<DebugConstants>  g_debugConsts       : register(b0, space0);
ConstantBuffer<AppSettings>     g_appSettings       : register(b1, space0);
ConstantBuffer<CameraConstants> g_cameraConsts      : register(b2, space0);
ConstantBuffer<SceneConstants>  g_sceneConsts       : register(b3, space0);
ConstantBuffer<LightConstants>  g_lightConsts       : register(b4, space0);

// Samplers---------------------------------
SamplerState g_samplerPointClamp                : register(s0, space0);
SamplerState g_samplerBilinearWrap              : register(s1, space0);
SamplerState g_samplerBilinearComparisionBorder : register(s2, space0);
SamplerState g_samplerPointWrap                 : register(s3, space0);
SamplerState g_samplerPointMirror               : register(s4, space0);
SamplerState g_samplerBilinearClamp             : register(s5, space0);
SamplerState g_samplerBilinearMirror            : register(s6, space0);
SamplerState g_samplerTrilinearWrap             : register(s7, space0);
SamplerState g_samplerTrilinearClamp            : register(s8, space0);
SamplerState g_samplerTrilinearMirror           : register(s9, space0);

