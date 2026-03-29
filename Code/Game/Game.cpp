#include "Game/Game.hpp"
#include "Game/Scene.hpp"
#include "Game/TestScene.hpp"
#include "Game/PBRTests.hpp"
#include "Game/Sponza.hpp"

#include "Engine/Core/NamedStrings.hpp"

#include "ThirdParty/imgui/imgui.h"
#include "ThirdParty/imgui/implot.h"

#include <cstdint>

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
Game::Game()
{

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
Game::~Game()
{

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Game::Startup()
{
	StartClockAndTimers();
	InitializeCameras();

	PrintControlsOnDevConsole();
	
	SwitchScene(SCENE_SPONZA);

	m_enableAccum	= g_gameConfigBlackboard.GetValue("enableFrameAccumulation", true);
	m_enableJitter	= g_gameConfigBlackboard.GetValue("enableJitter", true);
	m_minBounces	= g_gameConfigBlackboard.GetValue("minBounces", 0);
// 	m_maxBounces	= g_gameConfigBlackboard.GetValue("maxBounces", 0);
	m_spp			= g_gameConfigBlackboard.GetValue("spp", 32);
	m_enableIndirect = g_gameConfigBlackboard.GetValue("enableIndirect", true);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Game::Shutdown()
{
	delete m_currentScene;
	m_currentScene = nullptr;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Game::Update()
{
	UpdateMainDebugWindow();

	KeyboardControls();

	UpdateCameras();
	m_currentScene->Update();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Game::UpdateCameras()
{
	m_camera.m_mode = Camera::eMode_Perspective;

	Mat44 cameraToRenderMatrix;
	cameraToRenderMatrix.SetIJKT3D(Vec3(0.f, 0.f, 1.f), Vec3(-1.f, 0.f, 0.f), Vec3(0.f, 1.f, 0.f), Vec3(0.f, 0.f, 0.f));
	m_camera.SetCameraToRenderTransform(cameraToRenderMatrix);
	m_camera.SetPerspectiveView(g_theWindow->GetConfig().m_aspectRatio, 60.f, 0.1f, 100.f);

	m_screenCamera.m_mode = Camera::eMode_Orthographic;
	m_screenCamera.SetOrthographicView(m_screenCamera.m_viewportBounds);
}
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Game::PrintControlsOnDevConsole()
{
	g_devConsole->AddLine(DevConsole::INTRO_TEXT, "Thesis Artifact");
	g_devConsole->AddLine(DevConsole::INTRO_TEXT, "================================");
	g_devConsole->AddLine(DevConsole::INTRO_TEXT, "Controls");
	g_devConsole->AddLine(DevConsole::INTRO_SUBTEXT, "--------------------------------");
	g_devConsole->AddLine(DevConsole::INTRO_SUBTEXT, "W - Move Forward");
	g_devConsole->AddLine(DevConsole::INTRO_SUBTEXT, "S - Move Backward");
	g_devConsole->AddLine(DevConsole::INTRO_SUBTEXT, "A - Move Left");
	g_devConsole->AddLine(DevConsole::INTRO_SUBTEXT, "D - Move Right");
	g_devConsole->AddLine(DevConsole::INTRO_SUBTEXT, "Q - Move Up");
	g_devConsole->AddLine(DevConsole::INTRO_SUBTEXT, "I/J/K/L - Adjust Sun Direction (when available)");
	g_devConsole->AddLine(DevConsole::INTRO_SUBTEXT, "Up / Down Arrow - Adjust Sun Intensity");
	g_devConsole->AddLine(DevConsole::INTRO_SUBTEXT, "1 - Debug View: Positions (Position GBuffer)");
	g_devConsole->AddLine(DevConsole::INTRO_SUBTEXT, "2 - Debug View: Pixel Normals (Normals GBuffer)");
	g_devConsole->AddLine(DevConsole::INTRO_SUBTEXT, "3 - Debug View: BaseColor/Albedo (Albedo GBuffer)");
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Game::Render()
{
	g_renderer->BeginRTCamera(m_camera);
	m_currentScene->Render();
	g_renderer->EndCamera(m_camera);

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Game::KeyboardControls()
{
	float moveSpeed = 1.f;

	m_camera.m_orientation.m_yawDegrees += -(g_inputSystem->GetCursorClientDelta().x * 0.125f);
	m_camera.m_orientation.m_pitchDegrees += g_inputSystem->GetCursorClientDelta().y * 0.125f;

	m_camera.m_orientation.m_pitchDegrees = GetClamped(m_camera.m_orientation.m_pitchDegrees, -89.9f, 89.9f);

	Vec3 fwdVector;
	Vec3 upVector;
	Vec3 leftVector;

	m_camera.m_orientation.GetAsVectors_IFwd_JLeft_KUp(fwdVector, leftVector, upVector);

	if(g_inputSystem->IsKeyDown(KEYCODE_LSHIFT))
	{
		moveSpeed *= 10.f;
	}

	if(g_inputSystem->IsKeyDown('W'))
	{
		m_camera.m_position += fwdVector * moveSpeed * m_gameClock->GetDeltaSeconds();
	}

	if(g_inputSystem->IsKeyDown('S'))
	{
		m_camera.m_position -= fwdVector * moveSpeed * m_gameClock->GetDeltaSeconds();
	}

	if(g_inputSystem->IsKeyDown('A'))
	{
		m_camera.m_position += leftVector * moveSpeed * m_gameClock->GetDeltaSeconds();
	}

	if(g_inputSystem->IsKeyDown('D'))
	{
		m_camera.m_position -= leftVector * moveSpeed * m_gameClock->GetDeltaSeconds();
	}

	if(g_inputSystem->IsKeyDown('Q'))
	{
		m_camera.m_position += upVector * moveSpeed * m_gameClock->GetDeltaSeconds();
	}

	if(g_inputSystem->IsKeyDown('E'))
	{
		m_camera.m_position -= upVector * moveSpeed * m_gameClock->GetDeltaSeconds();
	}	
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Game::StartClockAndTimers()
{
	m_gameClock = new Clock(Clock::GetSystemClock());
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Game::InitializeCameras()
{
	m_camera.m_viewportBounds.m_mins = Vec2::ZERO;
	m_camera.m_viewportBounds.m_maxs = Vec2(g_theWindow->GetClientDimensions());

	m_screenCamera.m_viewportBounds.m_mins = Vec2::ZERO;
	m_screenCamera.m_viewportBounds.m_maxs = Vec2(g_theWindow->GetClientDimensions());

	m_camera.m_position = Vec3(-4.f, 0.5f, 3.f);
	m_camera.m_orientation = EulerAngles(0.f, 30.f, 0.f);

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Game::UpdateMainDebugWindow()
{
	ImGui::Begin("App Settings");
	
// 	const char* sceneNames[] = {"TEST SCENE", "PBR", "SPONZA"};
// 
// 	int prevIndex = m_currentSceneIndex;
// 
// 	ImGui::Combo("Scenes", &m_currentSceneIndex, sceneNames, IM_ARRAYSIZE(sceneNames));
// 
// 	if(prevIndex != m_currentSceneIndex)
// 	{
// 		SwitchScene(static_cast<Scenes>(m_currentSceneIndex));
// 	}

	// Frame Rate
	{
		float deltaSeconds = m_gameClock->GetDeltaSeconds() * 1000.f;
		m_frameTimes[m_valuesOffset] = deltaSeconds;
		m_valuesOffset = (m_valuesOffset + 1) % 120;
		std::string frameTime = Stringf("Frame Time: %0.2f ms", deltaSeconds);
		ImGui::Text(frameTime.c_str());
	//	ImGui::PlotLines("Frame Time", m_frameTimes, IM_ARRAYSIZE(m_frameTimes), m_valuesOffset, nullptr, 0.0f, 40.0f, ImVec2(0, 80));
		if(ImPlot::BeginPlot("Frame Time", ImVec2(-1, 150)))
		{
			ImPlot::SetupAxes(nullptr, "ms", ImPlotAxisFlags_NoTickLabels, ImPlotAxisFlags_AutoFit);
			ImPlot::SetupAxisLimits(ImAxis_Y1, 0.0, 40.0, ImGuiCond_Always);

			// Reference lines
			float y_lines[] = {16.67f, 33.33f};

			ImPlot::SetNextLineStyle(ImVec4(0.3f, 0.9f, 0.4f, 0.5f), 1.0f);
			ImPlot::PlotInfLines("##16ms", y_lines, 1);

			ImPlot::SetNextLineStyle(ImVec4(1.0f, 0.8f, 0.3f, 0.5f), 1.0f);
			ImPlot::PlotInfLines("##33ms", y_lines + 1, 1);			// Build ordered data from ring buffer

			static float ordered[120];
			for(int i = 0; i < IM_ARRAYSIZE(m_frameTimes); ++i)
			{
				int idx = (m_valuesOffset + i) % IM_ARRAYSIZE(m_frameTimes);
				ordered[i] = m_frameTimes[idx];
			}

			// === Fill under curve ===
			ImPlot::PushStyleVar(ImPlotStyleVar_FillAlpha, 0.25f);
			ImPlot::SetNextFillStyle(ImVec4(0.2f, 0.6f, 1.0f, 1.0f));
			ImPlot::PlotShaded("Fill", ordered, IM_ARRAYSIZE(ordered), 0.0f);
			ImPlot::PopStyleVar();

			// === Colored segments ===
			for(int i = 0; i < IM_ARRAYSIZE(ordered) - 1; ++i)
			{
				float avg = 0.5f * (ordered[i] + ordered[i + 1]);

				ImVec4 col;
				if(avg <= 16.67f)      col = ImVec4(0.3f, 0.9f, 0.4f, 1.0f); // green
				else if(avg <= 33.33f) col = ImVec4(1.0f, 0.8f, 0.3f, 1.0f); // yellow
				else                    col = ImVec4(1.0f, 0.3f, 0.3f, 1.0f); // red

				ImPlot::SetNextLineStyle(col, 3.0f); // thicker line

				float xs[2] = {(float)i, (float)(i + 1)};
				float ys[2] = {ordered[i], ordered[i + 1]};

				ImPlot::PlotLine("##seg", xs, ys, 2);
			}

			ImPlot::EndPlot();
		}
	}

	std::string pos = Stringf("Position: (%0.2f, %0.2f, %0.2f)", m_camera.m_position.x, m_camera.m_position.y, m_camera.m_position.z);
	ImGui::Text(pos.c_str());

	ImGui::Checkbox("Enable Sub-Pixel Jitter", &m_enableJitter);
	g_renderer->EnableJitter(m_enableJitter);

	ImGui::Checkbox("Enable Frame Accumulation", &m_enableAccum);
	g_renderer->EnableFrameAccumulation(m_enableAccum);
// 
// 	ImGui::SliderInt("Max Bounces", &m_maxBounces, 0, 31);
// 	g_renderer->SetMaxLightRayBounces(m_maxBounces);

	ImGui::SliderInt("Min Bounces", &m_minBounces, 0, 31);
	g_renderer->SetMinLightRayBounces(m_minBounces);

	ImGui::Checkbox("Enable Direct Lighting", &m_enableDirect);
	g_renderer->ToggleDirectLighting(m_enableDirect);

	ImGui::Checkbox("Enable Indirect Lighting", &m_enableIndirect);
	g_renderer->ToggleIndirectLighting(m_enableIndirect);

	ImGui::Checkbox("Enable Temporal Reuse", &m_temporalReuse);
	g_renderer->ToggleTemporalReuse(m_temporalReuse);

	ImGui::Checkbox("Enable Spatial Reuse", &m_spatialReuse);
	g_renderer->ToggleSpatialReuse(m_spatialReuse);

	ImGui::Checkbox("Enable Denoiser", &m_enableDenoiser);
	g_renderer->ToggleDenoiser(m_enableDenoiser);

	ImGui::SliderInt("Num Denoise Passes", &m_denoisePasses, 1, 3);
	g_renderer->SetNumDenoisePasses(m_denoisePasses);

	ImGui::SliderInt("Denoise Radius", &m_denoiseRadius, 1, 3);
	g_renderer->SetDenoiseRadius(m_denoiseRadius);

	ImGui::SliderFloat("Denoise Sigma Spatial", &m_sigmaSpatial, 1.f, 10.f);
	g_renderer->SetDenoiseSigmaSpatial(m_sigmaSpatial);

	ImGui::SliderInt("Samples Per Pixel", &m_spp, 1, 64);
	g_renderer->SetSamplesPerPixel(m_spp);


	ImGui::SliderInt("Max Frames To Accumulate", &m_maxFramesToAccumulate, -1, 64);
	g_renderer->SetMaxFramesToAccumulate(m_maxFramesToAccumulate);

	ImGui::Text(Stringf("Accumulated Frame Count: %d", g_renderer->GetAccumulatedFrameCount()).c_str());

	ImGui::End();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Game::SwitchScene(Scenes newScene)
{
	if(m_currentScene)
	{
		delete m_currentScene;
		m_currentScene = nullptr;
	}

	switch(newScene)
	{
		case SCENE_TEST: 
		{
			m_camera.SetPosition(Vec3(-2.f, 0.f, 2.f));
			m_camera.SetOrientation(EulerAngles(0.f, 30.f, 0.f));
			m_currentScene = new TestScene();
			m_currentSceneIndex = SCENE_TEST;
			break;
		}
		case SCENE_PBR:
		{
			m_camera.SetPosition(Vec3(-2.f, 0.f, 2.f));
			m_camera.SetOrientation(EulerAngles(0.f, 30.f, 0.f));
			m_currentScene = new PBRTests();
			m_currentSceneIndex = SCENE_PBR;
			break;
		}

		case SCENE_SPONZA:
		{
			m_camera.SetPosition(Vec3(-6.f, 0.f, 1.5f));
			m_camera.SetOrientation(EulerAngles(0.f, 0.f, 0.f));
			m_currentScene = new Sponza();
			m_currentSceneIndex = SCENE_SPONZA;
			break;
		}

		default:
		{
			m_camera.SetPosition(Vec3(-2.f, 0.f, 2.f));
			m_camera.SetOrientation(EulerAngles(0.f, 30.f, 0.f));
			m_currentScene = new TestScene();
			m_currentSceneIndex = SCENE_TEST;
			break;
		}
	}

	g_renderer->ResetFrameAccumulationCounter();

}

