#pragma once
#include "Engine/Renderer/Camera.hpp"
#include "Engine/Core/Timer.hpp"
#include "Engine/Renderer/Light.hpp"
#include "Game/GameCommon.hpp"
#include "Engine/Renderer/RayTracingUtils.hpp"

#include <vector>

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
class Clock;
class Scene;

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
class Game
{
public:
	Game();
	~Game();

	void Startup();
	void Shutdown();
	void Update();
	void Render();

private:
	void KeyboardControls();
	void StartClockAndTimers();
	void InitializeCameras();
	
	void UpdateMainDebugWindow();

	void SwitchScene(Scenes newScene = SCENE_TEST);

	void UpdateCameras();
	void PrintControlsOnDevConsole();

public:
	Camera					m_camera;
	Camera					m_screenCamera;
	
	bool					m_enableJitter	= true;
	bool					m_enableAccum	= true;
	int						m_minBounces	= 0;
// 	int						m_maxBounces	= 0;
	int						m_spp			= 32;
	int						m_denoisePasses	= 3;
	int						m_denoiseRadius	= 3;
	float					m_sigmaSpatial	= 2.f;
	int						m_maxFramesToAccumulate = -1;

	Clock*					m_gameClock		= nullptr;
	Scene*					m_currentScene	= nullptr;
	int						m_currentSceneIndex = SCENE_TEST;
	bool					m_firstFrame		= true;
	bool 					m_enableIndirect	= true;
	bool 					m_enableDirect		= true;
	bool 					m_temporalReuse		= true;
	bool 					m_spatialReuse		= true;
	bool					m_enableDenoiser	= false;

	float					m_frameTimes[120] = {};
	int					m_valuesOffset = 0;

};