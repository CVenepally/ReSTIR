#include "Game/PBRTests.hpp"
#include "Game/GameCommon.hpp"
#include "ThirdParty/imgui/imgui.h"

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
PBRTests::PBRTests()
	: Scene()
{
	InitSceneGeometry();

	m_sunYaw = -45.f;
	m_sunPitch = -60.f;

	Vec3 direction = Vec3::MakeFromPolarDegrees(m_sunPitch, m_sunYaw);

	m_sunLight = Light::CreateDirectionalLight(direction, 0.7f, Rgba8(255, 255, 255, 255));

	Light pointTest = Light::CreatePointLight(Vec3(0.f, 0.f, 4.f), 1.f, 1.5f, 4.f);
	m_lights.push_back(pointTest);

	m_debugInfo.m_diffuseModel = 1;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
PBRTests::~PBRTests()
{}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void PBRTests::InitSceneGeometry()
{
	CreatePBRSphere(Vec3(2.f, 4.f, 0.5f), "Metal");
	CreatePBRSphere(Vec3(2.f, 2.f, 0.5f), "CleanConcrete");
	CreatePBRSphere(Vec3(2.f, 0.f, 0.5f), "DullMetal");
	CreatePBRSphere(Vec3(2.f, -2.f, 0.5f), "OldPlastic");
	CreatePBRSphere(Vec3(2.f, -4.f, 0.5f), "Rubber");
	CreatePBRSphere(Vec3(2.f, -6.f, 0.5f), "RedMaterial");
	
	// Accel Structs
	m_staticGeometryBlas = g_renderer->CreateBLAS(m_staticGeoVBOs, m_staticGeoIBOs);

	std::vector<BottomLevelAS*> blas;
	blas.push_back(m_staticGeometryBlas);

	m_tlas = g_renderer->CreateTLAS(blas);

	g_renderer->BuildShaderBindingTables(1, 1, static_cast<int>(m_staticGeoVBOs.size()));

	m_meshInfoBuffer = g_renderer->CreateStructuredBuffer(static_cast<unsigned int>(m_sceneMeshInfo.size()), sizeof(MeshInfo), m_sceneMeshInfo.data());
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void PBRTests::Update()
{
	SetDebugValues();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void PBRTests::Render()
{
	g_renderer->SetDebugConstants(m_debugInfo);
	g_renderer->SetLightConstants(m_sunLight, m_lights, m_ambientIntensity, RootSignatureType::RAY_TRACED);
	g_renderer->SetSceneConstants(m_meshInfoBuffer->GetBindlessIndex(), static_cast<unsigned int>(m_staticGeoVBOs.size()));
	g_renderer->DispatchRays(m_tlas);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void PBRTests::CreatePBRSphere(Vec3 const& position, std::string const& textureName)
{
	Sphere sphere = Sphere(position, 0.5f);

	std::vector<Vertex_PCUTBN> sphereVerts;
	std::vector<unsigned int> sphereInds;

	AddVertsForIndexedSphere3D(sphereVerts, sphereInds, sphere, Rgba8::WHITE, AABB2::ZERO_TO_ONE, 64, 32);

	VertexBuffer* sphereVBO = g_renderer->CreateVertexBuffer(static_cast<unsigned int>(sphereVerts.size()), sphereVerts.data(), InputLayoutType::VERTEX_PCUTBN, true);
	IndexBuffer* sphereIBO = g_renderer->CreateIndexBuffer(static_cast<unsigned int>(sphereInds.size()), sphereInds.data(), true);
		
	std::string albedoTexturePath = Stringf("Data/Images/Textures/PBR/%s_a.png", textureName.c_str());
	std::string normalTexturePath = Stringf("Data/Images/Textures/PBR/%s_n.png", textureName.c_str());
	std::string metalTexturePath = Stringf("Data/Images/Textures/PBR/%s_m.png", textureName.c_str());
	std::string roughTexturePath = Stringf("Data/Images/Textures/PBR/%s_r.png", textureName.c_str());

	Texture* sphereAlbedo	= g_renderer->CreateOrGetBindlessTexture(albedoTexturePath);
	Texture* sphereNormal	= g_renderer->CreateOrGetBindlessTexture(normalTexturePath);
	Texture* sphereMetal	= g_renderer->CreateOrGetBindlessTexture(metalTexturePath);
//	Texture* sphereRough	= g_renderer->CreateOrGetBindlessTexture(roughTexturePath);

	MaterialInfo matInfo;
	matInfo.SetAlbedoTextureIndex(sphereAlbedo->GetBindlessIndex());
	matInfo.SetNormalTextureIndex(sphereNormal->GetBindlessIndex());
	matInfo.SetRMTextureIndex(sphereMetal->GetBindlessIndex());
//	matInfo.SetRoughnessTextureIndex(sphereRough->GetBindlessIndex());

	MeshInfo meshInfo;
	meshInfo.m_vbIndex = sphereVBO->GetBindlessIndex();
	meshInfo.m_ibIndex = sphereIBO->GetBindlessIndex();
	meshInfo.m_materialInfo = matInfo;

	m_staticGeoVBOs.push_back(sphereVBO);
	m_staticGeoIBOs.push_back(sphereIBO);
	m_sceneMeshInfo.push_back(meshInfo);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void PBRTests::AdjustSunDirection()
{
	ImGui::Begin("Light Debug", 0, ImGuiWindowFlags_AlwaysAutoResize);

	ImGui::SetWindowSize("Light Debug", ImVec2(300.f, 150.f));

	ImGui::SeparatorText("Adjust Sun Light Direction");
	ImGui::SliderFloat("Sun Yaw", &m_sunYaw, -180.0f, 180.f);
	ImGui::SliderFloat("Sun Pitch", &m_sunPitch, -180.0f, 180.f);
	Vec3 direction = Vec3::MakeFromPolarDegrees(m_sunPitch, m_sunYaw);
	m_sunLight.SetDirection(direction.GetNormalized());

	ImGui::SeparatorText("Adjust Sun Light Intensity");
	float sunIntensity = m_sunLight.GetIntesity();
	ImGui::SliderFloat("Sun Intensity", &sunIntensity, 0.f, 1.f);
	m_sunLight.SetIntensity(sunIntensity);

	if(ImGui::CollapsingHeader("Sun Color"))
	{
		ImGui::SeparatorText("Adjust Sun Light Color");
		Vec4 sunColor = m_sunLight.GetColor();
		float color[3] = {sunColor.x, sunColor.y, sunColor.z};
		ImGui::ColorPicker3("SunColor", color, ImGuiColorEditFlags_DisplayRGB);
		m_sunLight.SetColor(color[0], color[1], color[2]);
	}


	ImGui::End();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void PBRTests::SetDebugValues()
{
	if(m_firstFrame)
	{
		ImGui::SetNextWindowPos(ImVec2(1320.f, 20.f));
		ImGui::SetNextWindowSize(ImVec2(350.f, 700.f));
		m_firstFrame = false;
	}

	ImGui::Begin("Debug Info");

	std::string text = Stringf("Materials (Left To Right):\n%s\n%s\n%s\n%s\n%s\n%s", "Metal", "CleanConcrete", "DullMetal", "OldPlastic", "Rubber", "Red Synthetic Material");

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
