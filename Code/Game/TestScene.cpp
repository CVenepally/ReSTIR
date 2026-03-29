#include "Game/TestScene.hpp"
#include "Game/GameCommon.hpp"
#include "ThirdParty/imgui/imgui.h"
#include "PBRTests.hpp"

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
TestScene::TestScene()
	: Scene()
{
	InitSceneGeometry();

	m_sunYaw = -45.f;
	m_sunPitch = -60.f;

	Vec3 direction = Vec3::MakeFromPolarDegrees(m_sunPitch, m_sunYaw);

	m_sunLight = Light::CreateDirectionalLight(direction, 0.7f, Rgba8(255, 255, 255, 255));


}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
TestScene::~TestScene()
{}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void TestScene::InitSceneGeometry()
{
	// Init Box
	{
		AABB3 box = AABB3(Vec3(0.f, 0.f, 0.8f), Vec3(1.f, 1.f, 1.8f));
		std::vector<Vertex_PCUTBN> boxVerts;
		std::vector<unsigned int> boxInds;
		AddVertsForAABB3D(boxVerts, boxInds, box, Rgba8::RED);

		VertexBuffer*	boxVBO = g_renderer->CreateVertexBuffer(static_cast<unsigned int>(boxVerts.size()), boxVerts.data(), InputLayoutType::VERTEX_PCUTBN, true);
		IndexBuffer*	boxIBO = g_renderer->CreateIndexBuffer(static_cast<unsigned int>(boxInds.size()), boxInds.data(), true);

		Texture* cubeAlbedo = g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/DullMetal_a.png");
		Texture* cubeNormal = g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/DullMetal_n.png");
		Texture* cubeMetal	= g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/DullMetal_m.png");
// 		Texture* cubeRough	= g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/DullMetal_r.png");

		// Create Material Info
		MaterialInfo matInfo;
		matInfo.SetAlbedoTextureIndex(cubeAlbedo->GetBindlessIndex());
		matInfo.SetNormalTextureIndex(cubeNormal->GetBindlessIndex());
		matInfo.SetRMTextureIndex(cubeMetal->GetBindlessIndex());
//		matInfo.SetRoughnessTextureIndex(cubeRough->GetBindlessIndex());

		MeshInfo meshInfo;
		meshInfo.m_vbIndex = boxVBO->GetBindlessIndex();
		meshInfo.m_ibIndex = boxIBO->GetBindlessIndex();
		meshInfo.m_materialInfo = matInfo;

		m_staticGeoVBOs.push_back(boxVBO);
		m_staticGeoIBOs.push_back(boxIBO);
		m_sceneMeshInfo.push_back(meshInfo);
	}

	// Init Plane
	{
		AABB3 plane = AABB3(Vec3(-5.f, -5.f, -0.5f), Vec3(5.f, 5.f, 0.5f));

		std::vector<Vertex_PCUTBN> planeVerts;
		std::vector<unsigned int> planeInds;

		AddVertsForAABB3D(planeVerts, planeInds, plane, Rgba8::WHITE);

		VertexBuffer* planeVBO = g_renderer->CreateVertexBuffer(static_cast<unsigned int>(planeVerts.size()), planeVerts.data(), InputLayoutType::VERTEX_PCUTBN, true);
		IndexBuffer* planeIBO = g_renderer->CreateIndexBuffer(static_cast<unsigned int>(planeInds.size()), planeInds.data(), true);

		Texture* planeAlbedo	= g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/OldPlastic_a.png");
		Texture* planeNormal	= g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/OldPlastic_n.png");
 		Texture* planeMetal		= g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/OldPlastic_m.png");
//  		Texture* planeRough		= g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/OldPlastic_r.png");

		MaterialInfo matInfo;
		matInfo.SetAlbedoTextureIndex(planeAlbedo->GetBindlessIndex());
		matInfo.SetNormalTextureIndex(planeNormal->GetBindlessIndex());
 		matInfo.SetRMTextureIndex(planeMetal->GetBindlessIndex());
// 		matInfo.SetRoughnessTextureIndex(planeRough->GetBindlessIndex());

		MeshInfo meshInfo;
		meshInfo.m_vbIndex = planeVBO->GetBindlessIndex();
		meshInfo.m_ibIndex = planeIBO->GetBindlessIndex();
		meshInfo.m_materialInfo = matInfo;

		m_staticGeoVBOs.push_back(planeVBO);
		m_staticGeoIBOs.push_back(planeIBO);
		m_sceneMeshInfo.push_back(meshInfo);
	}

	// Sphere
	{
		Sphere sphere = Sphere(Vec3(4.f, 3.f, 1.f), 0.5f);

		std::vector<Vertex_PCUTBN> sphereVerts;
		std::vector<unsigned int> sphereInds;

		AddVertsForIndexedSphere3D(sphereVerts, sphereInds, sphere, Rgba8::WHITE, AABB2::ZERO_TO_ONE, 128, 64);

		VertexBuffer* sphereVBO = g_renderer->CreateVertexBuffer(static_cast<unsigned int>(sphereVerts.size()), sphereVerts.data(), InputLayoutType::VERTEX_PCUTBN, true);
		IndexBuffer*  sphereIBO = g_renderer->CreateIndexBuffer(static_cast<unsigned int>(sphereInds.size()), sphereInds.data(), true);
		Texture* sphereAlbedo = g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/Metal_a.png");
		Texture* sphereNormal = g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/Metal_n.png");
		Texture* sphereMetal =	g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/Metal_m.png");
// 		Texture* sphereRough =	g_renderer->CreateOrGetBindlessTexture("Data/Images/Textures/PBR/Metal_r.png");

		MaterialInfo matInfo;
		matInfo.SetAlbedoTextureIndex(sphereAlbedo->GetBindlessIndex());
		matInfo.SetNormalTextureIndex(sphereNormal->GetBindlessIndex());
		matInfo.SetRMTextureIndex(sphereMetal->GetBindlessIndex());
//		matInfo.SetRoughnessTextureIndex(sphereRough->GetBindlessIndex());

		MeshInfo meshInfo;
		meshInfo.m_vbIndex = sphereVBO->GetBindlessIndex();
		meshInfo.m_ibIndex = sphereIBO->GetBindlessIndex();
		meshInfo.m_materialInfo = matInfo;

		m_staticGeoVBOs.push_back(sphereVBO);
		m_staticGeoIBOs.push_back(sphereIBO);
		m_sceneMeshInfo.push_back(meshInfo);
	}

	// Accel Structs
	m_staticGeometryBlas = g_renderer->CreateBLAS(m_staticGeoVBOs, m_staticGeoIBOs);

	std::vector<BottomLevelAS*> blas;
	blas.push_back(m_staticGeometryBlas);

	m_tlas = g_renderer->CreateTLAS(blas);

	g_renderer->BuildShaderBindingTables(1, 1, static_cast<int>(m_staticGeoVBOs.size()));

	m_meshInfoBuffer = g_renderer->CreateStructuredBuffer(static_cast<unsigned int>(m_sceneMeshInfo.size()), sizeof(MeshInfo), m_sceneMeshInfo.data());
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void TestScene::Update()
{
	SetDebugValues();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void TestScene::Render()
{
	std::vector<Light> lights;
	g_renderer->SetDebugConstants(m_debugInfo);
	g_renderer->SetLightConstants(m_sunLight, lights, m_ambientIntensity, RootSignatureType::RAY_TRACED);
	g_renderer->SetSceneConstants(m_meshInfoBuffer->GetBindlessIndex(), static_cast<unsigned int>(m_staticGeoVBOs.size()));
	g_renderer->DispatchRays(m_tlas);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void TestScene::AdjustSunDirection()
{
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void TestScene::SetDebugValues()
{
	if(m_firstFrame)
	{
		ImGui::SetNextWindowPos(ImVec2(1320.f, 20.f));
		ImGui::SetNextWindowSize(ImVec2(350.f, 700.f));
		m_firstFrame = false;
	}

	ImGui::Begin("Debug Info");

	std::string text = Stringf("Test Scene 1");

	ImGui::TextWrapped("%s\n\nControls:\nWSAD - Move\nSpacebar - Toggle Mouse Pointer", text.c_str());

	//if(ImGui::CollapsingHeader("Debug Views"))
	//{
	//	ImGui::RadioButton("Default View", &m_debugInfo.m_debugView, 0);
	//	ImGui::RadioButton("Position Buffer", &m_debugInfo.m_debugView, 1);
	//	ImGui::RadioButton("Normals Buffer", &m_debugInfo.m_debugView, 2);
	//	ImGui::RadioButton("Base Color / Albedo", &m_debugInfo.m_debugView, 3);
	//	ImGui::RadioButton("Metalness", &m_debugInfo.m_debugView, 4);
	//	ImGui::RadioButton("Roughness", &m_debugInfo.m_debugView, 5);
	//}

	if(ImGui::CollapsingHeader("BRDFs"))
	{
		ImGui::SeparatorText("Diffuse BRDFs");
		if(ImGui::RadioButton("Oren-Nayar Diffuse", &m_debugInfo.m_diffuseModel, 0))
		{
			g_renderer->ResetFrameAccumulationCounter();
		}

		ImGui::SameLine();

		if(ImGui::RadioButton("Lambertian Diffuse", &m_debugInfo.m_diffuseModel, 1))
		{
			g_renderer->ResetFrameAccumulationCounter();
		}

		ImGui::SeparatorText("Specular BRDFs");

		if(ImGui::RadioButton("Mirofacet Specular Model", &m_debugInfo.m_specularModel, 0))
		{
			g_renderer->ResetFrameAccumulationCounter();
		}

		ImGui::SameLine();

		if(ImGui::RadioButton("Phong Specular Lighting", &m_debugInfo.m_specularModel, 1))
		{
			g_renderer->ResetFrameAccumulationCounter();
		}
	}

	if(ImGui::CollapsingHeader("Light Debug"))
	{
		// 		ImGui::Checkbox("Should Use Fake Ambient", &m_useAmbient);
		// 
		// 		if(m_useAmbient)
		// 		{
		// 			m_debugInfo.m_shouldUseFakeAmbience = 1;
		// 			ImGui::SliderFloat("Ambient Intensity", &m_ambientIntensity, 0.f, 1.f);
		// 		}
		// 		else
		// 		{
		// 			m_debugInfo.m_shouldUseFakeAmbience = 0;
		// 		}


		ImGui::SeparatorText("Adjust Sun Light Direction");
		ImGui::SliderFloat("Sun Yaw", &m_sunYaw, -180.0f, 180.0f);
		ImGui::SliderFloat("Sun Pitch", &m_sunPitch, -180.0f, 180.0f);

		Vec3 direction = Vec3::MakeFromPolarDegrees(m_sunPitch, m_sunYaw);

		if(direction != m_sunLight.GetDirection())
		{
			g_renderer->ResetFrameAccumulationCounter();
		}

		m_sunLight.SetDirection(direction.GetNormalized());

		ImGui::SeparatorText("Adjust Sun Light Intensity");
		float sunIntensity = m_sunLight.GetIntesity();
		ImGui::SliderFloat("Sun Intensity", &sunIntensity, 0.0f, 50.0f);

		if(sunIntensity != m_sunLight.GetIntesity())
		{
			g_renderer->ResetFrameAccumulationCounter();
		}

		m_sunLight.SetIntensity(sunIntensity);

		if(ImGui::TreeNode("Sun Color"))
		{
			ImGui::SeparatorText("Adjust Sun Light Color");

			Vec4 sunColor = m_sunLight.GetColor();
			float color[3] = {sunColor.x, sunColor.y, sunColor.z};

			ImGui::ColorPicker3("Sun Color Picker", color, ImGuiColorEditFlags_DisplayRGB);
			m_sunLight.SetColor(color[0], color[1], color[2]);

			ImGui::TreePop();
		}
	}

	ImGui::End();

	if(g_inputSystem->WasKeyJustPressed('1'))
	{
		m_debugInfo.m_debugView = 1;
	}

	if(g_inputSystem->WasKeyJustPressed('2'))
	{
		m_debugInfo.m_debugView = 2;
	}

	if(g_inputSystem->WasKeyJustPressed('0'))
	{
		m_debugInfo.m_debugView = 0;
	}


}

