#include "Game/Scene.hpp"
#include "Game/GameCommon.hpp"

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
Scene::Scene()
{}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
Scene::~Scene()
{
// 	for(VertexBuffer* vbo : m_staticGeoVBOs)
// 	{
// 		if(vbo)
// 		{
// 			delete vbo;
// 			vbo = nullptr;
// 		}
// 	}
// 
// 	for(IndexBuffer* ibo : m_staticGeoIBOs)
// 	{
// 		if(ibo)
// 		{
// 			delete ibo;
// 			ibo = nullptr;
// 		}
// 	}

	if(m_meshInfoBuffer)
	{
		delete m_meshInfoBuffer;
		m_meshInfoBuffer = nullptr;
	}

	if(m_tlas)
	{
		delete m_tlas;
		m_tlas = nullptr;
	}

	if(m_staticGeometryBlas)
	{
		delete m_staticGeometryBlas;
		m_staticGeometryBlas = nullptr;
	}
}

