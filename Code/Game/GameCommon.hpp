#pragma once

//Engine Systems includes-------------------------------------------------------------------------------------------------------------------------------------------
#include "Engine/Input/InputSystem.hpp"
#include "Engine/Audio/AudioSystem.hpp"
#include "Engine/Window/Window.hpp"

#include "Engine/Renderer/DX12Renderer.hpp"
#include "Engine/Renderer/VertexBuffer.hpp"
#include "Engine/Renderer/IndexBuffer.hpp"
#include "Engine/Renderer/PipelineStateObject.hpp"
#include "Engine/Renderer/Texture.hpp"
#include "Engine/Renderer/Shader.hpp"
#include "Engine/Renderer/BottomLevelAS.hpp"
#include "Engine/Renderer/TopLevelAS.hpp"
#include "Engine/Renderer/MeshInfo.hpp"
#include "Engine/Renderer/MaterialInfo.hpp"
#include "Engine/Renderer/StructuredBuffer.hpp"

#include "Engine/Math/AABB2.hpp"
#include "Engine/Math/AABB3.hpp"
#include "Engine/Math/Sphere.hpp"
#include "Engine/Math/Vec2.hpp"
#include "Engine/Math/Vec3.hpp"
#include "Engine/Math/Mat44.hpp"
#include "Engine/Math/EulerAngles.hpp"
#include "Engine/Math/MathUtils.hpp"
#include "Engine/Math/IntRange.hpp"
#include "Engine/Math/FloatRange.hpp"

#include "Engine/Core/Vertex_PCU.hpp"
#include "Engine/Core/Vertex_PCUTBN.hpp"
#include "Engine/Core/VertexUtils.hpp"
#include "Engine/Core/Clock.hpp"
#include "Engine/Core/DebugRender.hpp"
#include "Engine/Core/StaticMesh.hpp"
#include "Engine/Core/EngineCommon.hpp"
#include "Engine/Core/DevConsole.hpp"
#include "Engine/Core/ModelLoader.hpp"

class App;

extern App*				g_theApp;
extern InputSystem*		g_inputSystem;
extern AudioSystem*		g_theAudioSystem;
extern Window*			g_theWindow;
extern DX12Renderer*	g_renderer;
extern ModelLoader*		g_modelLoader;


enum Scenes
{
	SCENE_TEST,
	SCENE_PBR,
	SCENE_SPONZA,

	SCENE_COUNT
};