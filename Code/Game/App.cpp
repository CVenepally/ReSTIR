#include "Game/App.hpp"
#include "Game/EngineBuildPreferences.hpp"

#include "Engine/Core/Time.hpp"
#include "Engine/Core/Clock.hpp"
#include "Engine/Core/ErrorWarningAssert.hpp"
#include "Engine/Core/EngineCommon.hpp"
#include "Engine/Core/Vertex_PCU.hpp"
#include "Engine/Core/XMLUtils.hpp"
#include "Engine/Core/NamedStrings.hpp"
#include "Engine/Core/DevConsole.hpp"
#include "Engine/Core/EventSystem.hpp"
#include "Engine/Core/DebugRender.hpp"
#include "Engine/Core/ModelLoader.hpp"

#include "Engine/Input/InputSystem.hpp"
#include "Engine/Audio/AudioSystem.hpp"
#include "Engine/Window/Window.hpp"
#include "Engine/Renderer/DX12Renderer.hpp"
#include "Engine/Renderer/VertexBuffer.hpp"
#include "Game/Game.hpp"

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
App*			g_theApp = nullptr;
AudioSystem*	g_theAudioSystem = nullptr;
DX12Renderer*	g_renderer = nullptr;
ModelLoader*	g_modelLoader = nullptr;

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
App::App()
{

}


//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
App::~App()
{

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void App::Startup()
{
	LoadConfigFile("Data/GameConfig.xml");

	InputConfig inputConfig;
	g_inputSystem = new InputSystem(inputConfig);

	WindowConfig windowConfig;
	windowConfig.m_aspectRatio = g_gameConfigBlackboard.GetValue("windowAspect", 1.f);
	windowConfig.m_theInputSystem = g_inputSystem;
	windowConfig.m_windowTitle = g_gameConfigBlackboard.GetValue("windowTitle", "Thesis");
	windowConfig.m_isFullscreen = g_gameConfigBlackboard.GetValue("isFullscreen", false);
	g_theWindow = new Window(windowConfig);

	EventSystemConfig eventSystemConfig;
	g_eventSystem = new EventSystem(eventSystemConfig);

	DX12RendererConfig renderConfig;
	renderConfig.m_window					= g_theWindow;
	renderConfig.m_enableRayTracing			= g_gameConfigBlackboard.GetValue("enableRaytrace", true);
	renderConfig.m_enableFrameAccumulation	= g_gameConfigBlackboard.GetValue("enableFrameAccumulation", true);
	renderConfig.m_enableJitter				= g_gameConfigBlackboard.GetValue("enableJitter", true);
	renderConfig.m_minRayBounces			=  g_gameConfigBlackboard.GetValue("minBounces", 0);
	renderConfig.m_maxRayBounces			=  g_gameConfigBlackboard.GetValue("maxBounces", 0);

	g_renderer = new DX12Renderer(renderConfig);

	DevConsoleConfig devConsoleConfig;
	devConsoleConfig.m_fontSize = 18.f;
	devConsoleConfig.m_fontAspect = 0.7f;
	devConsoleConfig.m_fontFileNamePath = "Data/Fonts/ButlerFont";
	devConsoleConfig.m_renderer = g_renderer;
	g_devConsole = new DevConsole(devConsoleConfig);

	AudioConfig audioConfig;
	g_theAudioSystem = new AudioSystem(audioConfig);

	DegbugRenderConfig debugConfig;
	debugConfig.m_renderer = g_renderer;
	debugConfig.m_fontName = "ButlerFont";

 	g_devConsole->Startup();
	g_inputSystem->Startup();
	g_theWindow->Startup();
	g_renderer->BeginStartup();
	g_theAudioSystem->Startup();
	DebugRenderSystemStartup(debugConfig);

	g_modelLoader = new ModelLoader(g_renderer);
	m_game = new Game();
	m_game->Startup();
	
	g_renderer->EndStartup();

 	g_devConsole->AddLine(DevConsole::INFO_MAJOR, "Type 'Help' to get a list of registered events");

	SubscribeEventCallbackFunction("Quit", RequestQuitEvent);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void App::Shutdown()
{
	UnsubscribeEventCallbackFunction("Quit", RequestQuitEvent);

	g_renderer->WaitForRendererToFinish();

	m_game->Shutdown();
	delete m_game;
	m_game = nullptr;

	delete g_modelLoader;
	g_modelLoader = nullptr;

	g_theAudioSystem->Shutdown();
	g_theAudioSystem = nullptr;

 	g_renderer->Shutdown();
	g_renderer = nullptr;

	g_theWindow->Shutdown();
	g_theWindow = nullptr;

	g_inputSystem->Shutdown();
	g_inputSystem = nullptr;

	g_devConsole->Shutdown();
	g_devConsole = nullptr;

	g_eventSystem->Shutdown();
	g_eventSystem = nullptr;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void App::BeginFrame()
{
	Clock::TickSystemClock();
	g_renderer->UpdateFrameCount();
	g_inputSystem->BeginFrame();
	g_theWindow->BeginFrame();
	g_renderer->BeginFrame();
	g_theAudioSystem->BeginFrame();
 	g_devConsole->BeginFrame();
	DebugRenderBeginFrame();

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void App::EndFrame()
{
	DebugRenderEndFrame();

	g_theAudioSystem->EndFrame();
	g_theWindow->EndFrame();
	g_renderer->EndFrame();
	g_inputSystem->EndFrame();

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void App::RunMainFrame()
{
	while(!g_theApp->isQuitting())
	{
		g_theApp->RunFrame();
	}
}


//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void App::RunFrame()
{
	
	BeginFrame();
	Update();
	Render();
	EndFrame();

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void App::Update()
{
	SetCursorVisibility();

	if(g_inputSystem->WasKeyJustPressed(KEYCODE_F11))
	{
		LoadConfigFile("Data/GameConfig.xml");
	}

	if(g_inputSystem->WasKeyJustPressed(KEYCODE_TILDE))
	{
		g_devConsole->ToggleMode(OPEN_FULL);
	}

	if(g_renderer->GetCurrentFrameNumber() > 5)
	{
		m_game->Update();
	}

	if(g_inputSystem->WasKeyJustPressed(KEYCODE_ESC))
	{
		RequestQuit();
	}

	if(g_inputSystem->WasKeyJustPressed(' '))
	{
		m_isCursorVisible = !m_isCursorVisible;
	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void App::Render() const
{
	g_renderer->ClearScreen(Rgba8(0, 0, 0, 0));

	m_game->Render();

	AABB2 screenBounds = {};
	screenBounds.m_mins = Vec2::ZERO;
	screenBounds.m_maxs = Vec2(g_theWindow->GetClientDimensions());
	g_devConsole->Render(screenBounds, g_renderer);
}

//------------------------------------------------------------------------------------------------------------------
void App::LoadConfigFile(char const* configFilePath)
{

	XmlDocument configFile;

	XmlResult result = configFile.LoadFile(configFilePath);

	if(result == tinyxml2::XML_SUCCESS)
	{
		XmlElement* configRootElement = configFile.RootElement();

		if(configRootElement)
		{
			g_gameConfigBlackboard.PopulateFromXMLElementAttributes(*configRootElement);
		}
		else
		{
			DebuggerPrintf("Config from \"%s\" could not be found. Config root missing or invalid\n", configFilePath);
		}
	}
	else
	{
		DebuggerPrintf("Config File from \"%s\" could not be loaded\n", configFilePath);
	}

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
bool App::isQuitting() const
{

	return m_isQuitting;

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void App::SetCursorVisibility()
{
	if(!g_theWindow->IsWindowActive() || g_devConsole->IsOpen() || m_isCursorVisible)
	{
		g_inputSystem->SetCursorMode(CursorMode::POINTER);
	}
	else
	{
		g_inputSystem->SetCursorMode(CursorMode::FPS);
	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void App::RequestQuit()
{

	m_isQuitting = true;

}


//------------------------------------------------------------------------------------------------------------------
bool App::RequestQuitEvent(EventArgs& args)
{

	UNUSED(args);

	g_theApp->RequestQuit();

	return false;

}