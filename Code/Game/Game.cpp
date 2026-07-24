#include "Game/Game.hpp"
#include "Game/Scene.hpp"
#include "Game/TestScene.hpp"
#include "Game/PBRTests.hpp"
#include "Game/Sponza.hpp"

#include "Engine/Core/NamedProperties.hpp"

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
	m_maxBounces	= g_gameConfigBlackboard.GetValue("maxBounces", 10);
	m_spp			= g_gameConfigBlackboard.GetValue("spp", 32);
	m_enableIndirect = g_gameConfigBlackboard.GetValue("enableIndirect", true);

	g_renderer->SetNumDenoisePasses(m_denoisePasses);
	g_renderer->SetDenoiseRadius(m_denoiseRadius);
	g_renderer->SetDenoiseSigmaSpatial(m_sigmaSpatial);
	g_renderer->SetDenoiseSigmaPosition(m_sigmaPosition);
	g_renderer->SetDenoiseNormalPower(m_normalPower);

	g_renderer->SetSpatialReusePasses(m_spatialReusePasses);
	g_renderer->SetSpatialReusePixelRadius(m_spatialReuseRadius);
	g_renderer->SetSpatialReuseMaxSamplesPerIteration(m_spatialReuseSamples);
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
	if(m_showDebugWindow)
	{
		UpdateMainDebugWindow();
	}

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

	if(g_inputSystem->WasKeyJustPressed('G'))
	{
		m_showDebugWindow = !m_showDebugWindow;
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
	ImGui::Begin("Debug Info");

	if(ImGui::CollapsingHeader("General Info"))
	{
		std::string pos = Stringf("Current Position: (%0.2f, %0.2f, %0.2f)", m_camera.m_position.x, m_camera.m_position.y, m_camera.m_position.z);
		ImGui::Text(pos.c_str());

		float fps						= 1.f / m_gameClock->GetDeltaSeconds();
		float deltaSeconds				= m_gameClock->GetDeltaSeconds() * 1000.f;
		std::string fpsText		= Stringf("FPS: %0.2f (%0.2fms)", fps, deltaSeconds);
		ImGui::Text(fpsText.c_str());
	}

	if(ImGui::CollapsingHeader("Lighting"))
	{		
		ImGui::Text("Max Lights To Render");
		ImGui::SameLine();
		ImGui::SetNextItemWidth(120.f);
		Sponza* scene = dynamic_cast<Sponza*>(m_currentScene);
		if(ImGui::SliderInt("##lights", &scene->m_maxLightsToRender, 1, scene->m_maxLightsInScene))
		{
			g_renderer->ResetFrameAccumulationCounter();
		}

		ImGui::Indent();
		ImGui::Checkbox("Enable Direct Lighting", &m_enableDirect);
		g_renderer->ToggleDirectLighting(m_enableDirect);

		if(m_enableDirect)
		{
			if(ImGui::TreeNode("Direct Lighting Settings"))
			{
				const char* directLightingModes[] = {"ReSTIR"};
				static int directLightingMode = 0;
				ImGui::Text("Sampling Technique");
				ImGui::SameLine();
				ImGui::SetNextItemWidth(120.f);
				if(ImGui::BeginCombo("##sampling", directLightingModes[directLightingMode]))
				{
					for(int i = 0; i < IM_ARRAYSIZE(directLightingModes); ++i)
					{
						bool isSelected = (directLightingMode == i);

						if(ImGui::Selectable(directLightingModes[i], isSelected))
							directLightingMode = i;

						if(isSelected)
							ImGui::SetItemDefaultFocus();
					}
					ImGui::EndCombo();
				}

				if(directLightingMode == 0) // ReSTIR
				{
					ImGui::Indent();

					ImGui::Text("Reservoir Sampling Samples Per Pixel");
					ImGui::SameLine();
					ImGui::SetNextItemWidth(120.f);
					ImGui::SliderInt("##spp", &m_spp, 1, 64);
					g_renderer->SetSamplesPerPixel(m_spp);

					ImGui::Checkbox("Enable Temporal Reuse", &m_temporalReuse);
					g_renderer->ToggleTemporalReuse(m_temporalReuse);

					ImGui::Checkbox("Enable Spatial Reuse", &m_spatialReuse);
					g_renderer->ToggleSpatialReuse(m_spatialReuse);
					
					ImGui::Text("Spatial Reuse Passes");
					ImGui::SameLine();
					ImGui::SetNextItemWidth(120.f);
					ImGui::SliderInt("##spr", &m_spatialReusePasses, 1, 6);
					g_renderer->SetSpatialReusePasses(m_spatialReusePasses);

					ImGui::Text("Spatial Reuse Radius");
					ImGui::SameLine();
					ImGui::SetNextItemWidth(120.f);
					ImGui::SliderInt("##srpr", &m_spatialReuseRadius, 3, 64);
					g_renderer->SetSpatialReusePixelRadius(m_spatialReuseRadius);
					
					ImGui::Text("Spatial Reuse Samples");
					ImGui::SameLine();
					ImGui::SetNextItemWidth(120.f);
					ImGui::SliderInt("##srs", &m_spatialReuseSamples, 3, 10);
					g_renderer->SetSpatialReuseMaxSamplesPerIteration(m_spatialReuseSamples);

					ImGui::Unindent();
				}
				ImGui::TreePop();
			}
		}

		ImGui::Checkbox("Enable Indirect Lighting", &m_enableIndirect);
		g_renderer->ToggleIndirectLighting(m_enableIndirect);
		if(m_enableIndirect)
		{
			if(ImGui::TreeNode("Indirect Lighting Settings"))
			{
				ImGui::Text("Max Bounces");
				ImGui::SameLine();
				ImGui::SliderInt("##bounces", &m_maxBounces, 0, 31);
				g_renderer->SetMaxLightRayBounces(m_maxBounces);
				ImGui::TreePop();
			}			
		}
		ImGui::Unindent();
	}

	if(ImGui::CollapsingHeader("Denoiser Settings"))
	{
		ImGui::Checkbox("Enable Frame Accumulation", &m_enableAccum);
		g_renderer->EnableFrameAccumulation(m_enableAccum);

		ImGui::Checkbox("Enable Denoiser", &m_enableDenoiser);
		g_renderer->ToggleDenoiser(m_enableDenoiser);

		ImGui::SliderInt("Num Denoise Passes", &m_denoisePasses, 1, 3);
		g_renderer->SetNumDenoisePasses(m_denoisePasses);

		ImGui::SliderInt("Denoise Radius", &m_denoiseRadius, 1, 3);
		g_renderer->SetDenoiseRadius(m_denoiseRadius);

		ImGui::SliderFloat("Denoise Sigma Spatial", &m_sigmaSpatial, 0.f, 10.f);
		g_renderer->SetDenoiseSigmaSpatial(m_sigmaSpatial);

		ImGui::SliderFloat("Denoise Sigma Position", &m_sigmaPosition, 0.f, 10.f);
		g_renderer->SetDenoiseSigmaPosition(m_sigmaPosition);
		
		ImGui::SliderFloat("Denoise Normal Power", &m_normalPower, 0.f, 64.f);
		g_renderer->SetDenoiseNormalPower(m_normalPower);

		ImGui::SliderInt("Max Frames To Accumulate", &m_maxFramesToAccumulate, -1, 64);
		g_renderer->SetMaxFramesToAccumulate(m_maxFramesToAccumulate);

		ImGui::Text(Stringf("Accumulated Frame Count: %d", g_renderer->GetAccumulatedFrameCount()).c_str());
	}
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

