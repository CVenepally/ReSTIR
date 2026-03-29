#pragma once
#include <vector>
#include "Engine/Renderer/RayTracingUtils.hpp"

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
class TopLevelAS;
class BottomLevelAS;
class VertexBuffer;
class IndexBuffer;
class StructuredBuffer;

struct MeshInfo;

typedef StructuredBuffer MeshInfoBuffer;

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
class Scene
{
public:
	Scene();
	virtual ~Scene();

	virtual void InitSceneGeometry()	= 0;
	virtual void Update()				= 0;
	virtual void Render()				= 0;

public:
	
	TopLevelAS*					m_tlas					= nullptr;
	BottomLevelAS*				m_staticGeometryBlas	= nullptr;

	std::vector<VertexBuffer*>	m_staticGeoVBOs;
	std::vector<IndexBuffer*>	m_staticGeoIBOs;
	std::vector<MeshInfo>		m_sceneMeshInfo;

	MeshInfoBuffer*				m_meshInfoBuffer		= nullptr;

	DebugInfo					m_debugInfo;

};