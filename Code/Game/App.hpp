#pragma once

#include "Engine/Math/Vec2.hpp"
#include "Engine/Renderer/Camera.hpp"

//------------------------------------------------------------------------------------------------------------------
class NamedStrings;
typedef NamedStrings EventArgs;
class VertexBuffer;
class Game;
//------------------------------------------------------------------------------------------------------------------
class App
{

public:

	App();
	~App();
	
	void Startup();
	void Shutdown();
	void RunFrame();

	void RunMainFrame();
	void RequestQuit();
	static bool RequestQuitEvent(EventArgs& args);
	
	void LoadConfigFile(char const* configFilePath);
	bool isQuitting() const;

	void SetCursorVisibility();


private:

	void BeginFrame();
	void Update();
	void Render() const;
	void EndFrame();

private:

	bool	m_isQuitting		= false;
	Game*	m_game				= nullptr;
	bool	m_isCursorVisible	= false;
};