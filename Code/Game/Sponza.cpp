#include "Game/Sponza.hpp"
#include "Game/GameCommon.hpp"
#include "ThirdParty/imgui/imgui.h"

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
Sponza::Sponza()
	: Scene()
{
	InitSceneGeometry();

	m_sunYaw = -30.f;
	m_sunPitch = 40.f;

	Vec3 direction = Vec3::MakeFromPolarDegrees(m_sunPitch, m_sunYaw);

	m_sunLight = Light::CreateDirectionalLight(direction, 3.7f, Rgba8(255, 255, 255, 255));

	InitLights();

 	m_lightsBuffer = g_renderer->CreateStructuredBuffer(static_cast<int>(m_allLights.size()), sizeof(Light), m_allLights.data());
	m_debugInfo.m_diffuseModel = 1;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
Sponza::~Sponza()
{
	m_staticGeoVBOs.clear();
	m_staticGeoIBOs.clear();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Sponza::InitSceneGeometry()
{	
	// Accel Structs
	LoadGLTFSceneContents("Data/Meshes/Sponza/Sponza.gltf", "Data/Images/Textures/Sponza/");

	m_staticGeometryBlas = g_renderer->CreateBLAS(m_staticGeoVBOs, m_staticGeoIBOs);

	std::vector<BottomLevelAS*> blas;
	blas.push_back(m_staticGeometryBlas);

	m_tlas = g_renderer->CreateTLAS(blas);

	g_renderer->BuildShaderBindingTables(1, 1, static_cast<int>(m_staticGeoVBOs.size()));

	m_meshInfoBuffer = g_renderer->CreateStructuredBuffer(static_cast<unsigned int>(m_sceneMeshInfo.size()), sizeof(MeshInfo), m_sceneMeshInfo.data());
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Sponza::Update()
{
	if(g_inputSystem->WasKeyJustPressed('1'))
	{
		m_debugInfo.m_debugView = 1;
		if(g_inputSystem->IsKeyDown(KEYCODE_LSHIFT))
		{
			m_debugInfo.m_debugView = 11;
		}
		g_renderer->ResetFrameAccumulationCounter();
	}

	if(g_inputSystem->WasKeyJustPressed('2'))
	{
		m_debugInfo.m_debugView = 2;
		if(g_inputSystem->IsKeyDown(KEYCODE_LSHIFT))
		{
			m_debugInfo.m_debugView = 12;
		}
		g_renderer->ResetFrameAccumulationCounter();

	}
	if(g_inputSystem->WasKeyJustPressed('3'))
	{
		m_debugInfo.m_debugView = 3;
		if(g_inputSystem->IsKeyDown(KEYCODE_LSHIFT))
		{
			m_debugInfo.m_debugView = 13;
		}
		g_renderer->ResetFrameAccumulationCounter();

	}
	if(g_inputSystem->WasKeyJustPressed('4'))
	{
		m_debugInfo.m_debugView = 4;
		if(g_inputSystem->IsKeyDown(KEYCODE_LSHIFT))
		{
			m_debugInfo.m_debugView = 14;
		}
		g_renderer->ResetFrameAccumulationCounter();

	}
	if(g_inputSystem->WasKeyJustPressed('5'))
	{
		m_debugInfo.m_debugView = 5;
		if(g_inputSystem->IsKeyDown(KEYCODE_LSHIFT))
		{
			m_debugInfo.m_debugView = 15;
		}
		g_renderer->ResetFrameAccumulationCounter();

	}
	if(g_inputSystem->WasKeyJustPressed('6'))
	{
		m_debugInfo.m_debugView = 6;
		if(g_inputSystem->IsKeyDown(KEYCODE_LSHIFT))
		{
			m_debugInfo.m_debugView = 16;
		}
		g_renderer->ResetFrameAccumulationCounter();

	}
	if(g_inputSystem->WasKeyJustPressed('7'))
	{
		m_debugInfo.m_debugView = 7;
		if(g_inputSystem->IsKeyDown(KEYCODE_LSHIFT))
		{
			m_debugInfo.m_debugView = 17;
		}
		g_renderer->ResetFrameAccumulationCounter();

	}
	if(g_inputSystem->WasKeyJustPressed('8'))
	{
		m_debugInfo.m_debugView = 8;
		if(g_inputSystem->IsKeyDown(KEYCODE_LSHIFT))
		{
			m_debugInfo.m_debugView = 18;
		}
		g_renderer->ResetFrameAccumulationCounter();

	}
	if(g_inputSystem->WasKeyJustPressed('9'))
	{
		m_debugInfo.m_debugView = 9;
		if(g_inputSystem->IsKeyDown(KEYCODE_LSHIFT))
		{
			m_debugInfo.m_debugView = 19;
		}
		g_renderer->ResetFrameAccumulationCounter();

	}

	if(g_inputSystem->WasKeyJustPressed('0'))
	{
		m_debugInfo.m_debugView = 0;

		if(g_inputSystem->IsKeyDown(KEYCODE_LSHIFT))
		{
			m_debugInfo.m_debugView = 10;
		}
		g_renderer->ResetFrameAccumulationCounter();

	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Sponza::Render()
{
	g_renderer->SetDebugConstants(m_debugInfo);

	g_renderer->SetSceneConstants(m_meshInfoBuffer->GetBindlessIndex(), static_cast<unsigned int>(m_staticGeoVBOs.size()), m_maxLightsToRender, m_lightsBuffer->GetBindlessIndex());
	g_renderer->DispatchRays(m_tlas);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Sponza::AdjustSunDirection()
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
void Sponza::LoadGLTFSceneContents(std::string const& gltfFilePath, std::string const& texturePath)
{
	tinygltf::Model		model;
	tinygltf::TinyGLTF	glTFLoader;
	std::string			err;
	std::string			warn;

	bool result = glTFLoader.LoadASCIIFromFile(&model, &err, &warn, gltfFilePath);

	if(!warn.empty())
	{
		DebuggerPrintf(Stringf("GLTF Warning: %s\n", warn.c_str()).c_str());
	}

	if(!err.empty())
	{
		DebuggerPrintf(Stringf("GLTF Error: %s\n", err.c_str()).c_str());
	}

	if(!result)
	{
		ERROR_RECOVERABLE(Stringf("Failed to load glTF: %s\nTinyGLTF Warning: %s\nTinyGLTF Error: %s", gltfFilePath.c_str(), warn.c_str(), err.c_str()).c_str())
			return;
	}

	tinygltf::Scene& scene = model.scenes[model.defaultScene];

	for(int nodeIndex = 0; nodeIndex < static_cast<int>(scene.nodes.size()); ++nodeIndex)
	{
		tinygltf::Node& node = model.nodes[scene.nodes[nodeIndex]];
		LoadGLTFNode(node, model, Mat44(), texturePath);
	}

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Sponza::LoadGLTFNode(tinygltf::Node const& currentNode, tinygltf::Model& model, Mat44 const& parentGlobalTransform, std::string const& texturePath)
{
	Mat44 currentNodeLocalTransform;
	if(currentNode.matrix.size() != 0)
	{
		currentNodeLocalTransform = Mat44(currentNode.matrix.data());
	}
	else
	{
		Vec3 translation = Vec3::ZERO;
		if(currentNode.translation.size() == 3)
		{
			translation = Vec3(currentNode.translation);
		}

		std::vector<double> quaternion = {0., 0., 0., 1.};
		if(currentNode.rotation.size() == 4)
		{
			quaternion = currentNode.rotation;
		}

		Vec3 scale = Vec3(1.f, 1.f, 1.f);
		if(currentNode.scale.size() == 3)
		{
			scale = Vec3(currentNode.scale);
		}

		currentNodeLocalTransform = Mat44::MakeTranslation3D(translation);
		currentNodeLocalTransform.Append(Mat44::MakeFromQuaternion(static_cast<float>(quaternion[0]), static_cast<float>(quaternion[1]), static_cast<float>(quaternion[2]), static_cast<float>(quaternion[3])));
		currentNodeLocalTransform.AppendScaleNonUniform3D(scale);
	}

	Mat44 currentNodeGlobalTransform = parentGlobalTransform;
	currentNodeGlobalTransform.Append(currentNodeLocalTransform);

	// Load children first
	for(int childNodeIndex : currentNode.children)
	{
		tinygltf::Node& childNode = model.nodes[childNodeIndex];
		LoadGLTFNode(childNode, model, currentNodeGlobalTransform, texturePath);
	}

	// Load Mesh/Primitive into SceneObject
	if(currentNode.mesh >= 0)
	{
		tinygltf::Mesh& mesh = model.meshes[currentNode.mesh];

		for(tinygltf::Primitive const& primitive : mesh.primitives)
		{
			SceneObject sceneObject;
			sceneObject.m_name = Stringf("GLTF_Node_%d_Mesh_%d_Primitive_%d", currentNode.mesh, &primitive - &mesh.primitives[0]);
			sceneObject.m_transform = currentNodeGlobalTransform;

			// #NOTE: This is hard-coded. Might have to load this from an XML file or passed in as a parameter. Also, I have 0 idea why this works for duck.
			Mat44 engineRotation = Mat44();
			Vec3 iBasis = Vec3::MakeFromWord("Forward");
			Vec3 jBasis = Vec3::MakeFromWord("Up");
			Vec3 kBasis = Vec3::MakeFromWord("Right");
			engineRotation.SetIJK3D(iBasis, jBasis, kBasis);

			Mat44 correctedTransform = currentNodeGlobalTransform;
			correctedTransform.Append(engineRotation);

			sceneObject.m_mesh = g_modelLoader->CreateStaticMeshFromGLTFPrimitive(primitive, model, correctedTransform, sceneObject.m_name, texturePath);
			//	sceneObject.m_mesh = g_modelLoader->CreateStaticMeshFromGLTFPrimitive(primitive, model, Mat44(), sceneObject.m_name);

			m_sceneObjects.push_back(sceneObject);

			int albedoIndex = sceneObject.m_mesh->m_albedoTexture ? sceneObject.m_mesh->m_albedoTexture->GetBindlessIndex() : -1;
			int normalIndex = sceneObject.m_mesh->m_normalTexture ? sceneObject.m_mesh->m_normalTexture->GetBindlessIndex() : -1;
			int rmIndex = sceneObject.m_mesh->m_rmTexture ? sceneObject.m_mesh->m_rmTexture->GetBindlessIndex() : -1;

			//Material Info
			MaterialInfo matInfo;
			matInfo.SetAlbedoTextureIndex(albedoIndex);
			matInfo.SetAlbedoSamplerIndex(static_cast<int>(sceneObject.m_mesh->m_diffuseSampler));

			matInfo.SetNormalTextureIndex(normalIndex);
			matInfo.SetNormalSamplerIndex(static_cast<int>(sceneObject.m_mesh->m_normalSampler));

			matInfo.SetRMTextureIndex(rmIndex);
			matInfo.SetRMSamplerIndex(static_cast<int>(sceneObject.m_mesh->m_rmSampler));

			// Mesh Info
			MeshInfo meshInfo;
			meshInfo.m_vbIndex = sceneObject.m_mesh->m_vbo->GetBindlessIndex();
			meshInfo.m_ibIndex = sceneObject.m_mesh->m_ibo->GetBindlessIndex();
			meshInfo.m_isStatic = 1;
			meshInfo.m_materialInfo = matInfo;

			m_staticGeoVBOs.push_back(sceneObject.m_mesh->m_vbo);
			m_staticGeoIBOs.push_back(sceneObject.m_mesh->m_ibo);
			m_sceneMeshInfo.push_back(meshInfo);

		}
	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Sponza::InitLights()
{
	Rgba8 lightColors[6] = {Rgba8::WHITE, Rgba8(240, 40, 0), Rgba8(50, 200, 90), Rgba8(0, 170, 255), Rgba8(255, 145, 0), Rgba8(255, 221, 3)};
	IntRange indexRange = IntRange(0, 5);
	FloatRange intensityRange = FloatRange(m_minPointLightIntensity, m_maxPointLightIntensity);

	FloatRange xRange = FloatRange(-10.f, 10.f);
	FloatRange yRange = FloatRange(-4.f, 4.f);
	FloatRange zRange = FloatRange(1.f, 15.f);
	for(int i = 0; i < m_maxLightsInScene; i++)
	{
		Vec3 lightPos;
		lightPos.x = xRange.GetRandomFloat();
		lightPos.z = zRange.GetRandomFloat();

		if(lightPos.z >= 2.7f && lightPos.z <= 3.f)
		{
			lightPos.z = (FloatRange(0.f, 1.f).GetRandomFloat() < 0.5f) ? 2.1f : 2.3f;
		}
		else if(lightPos.z >= 6.7f && lightPos.z <= 7.f)
		{
			lightPos.z = (FloatRange(0.f, 1.f).GetRandomFloat() < 0.5f) ? 6.0f : 6.2f;
		}

		if(lightPos.z > 7.f)
		{
			lightPos.y = FloatRange(-2.2f, 2.9f).GetRandomFloat();
		}
		else
		{
			lightPos.y = yRange.GetRandomFloat();
		}

		float intensity = intensityRange.GetRandomFloat();
		int colorIndex = indexRange.GetRandomInt();
		Light light = Light::CreatePointLight(lightPos, 1.f, 1.f, intensity, lightColors[colorIndex]);
		m_allLights.push_back(light);
	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
void Sponza::SetDebugValues()
{
	if(m_firstFrame)
	{
		ImGui::SetNextWindowPos(ImVec2(1320.f, 20.f));
		ImGui::SetNextWindowSize(ImVec2(350.f, 700.f));
		m_firstFrame = false;
	}

	ImGui::Begin("Debug Info");

	if(ImGui::BeginTabBar("Test Tab Bar"))
	{
		if(ImGui::BeginTabItem("Sampling Settings"))
		{

			const char* sceneNames[] = {"CDF", "ReSTIR"};


			if(ImGui::Combo("Scenes", &m_debugInfo.m_lightSamplingMethod, sceneNames, IM_ARRAYSIZE(sceneNames)))
			{
				g_renderer->ResetFrameAccumulationCounter();
			}


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

			ImGui::EndTabItem();
		}

		if(ImGui::BeginTabItem("Light Settings"))
		{
			bool envLighting = m_debugInfo.m_envLighting == 1;

			if(ImGui::Checkbox("Env Lighting", &envLighting))
			{
				m_debugInfo.m_envLighting = envLighting ? 1 : 0;
				g_renderer->ResetFrameAccumulationCounter();
			}

			if(envLighting)
			{
				if(ImGui::ColorEdit3("Env Light Color", &m_debugInfo.m_envLightingColor.x))
				{
					g_renderer->ResetFrameAccumulationCounter();
				}
			}

			if(ImGui::Checkbox("Use Point Lights for Rendering", &m_renderLights))
			{
				g_renderer->ResetFrameAccumulationCounter();
			}
			
			ImGui::PushItemWidth(80.0f);

			ImGui::PopItemWidth();

			if(ImGui::CollapsingHeader("Scene Lights"))
			{
				
				int count = 0;
				for(Light& light : m_allLights)
				{					
					if(light.GetLightType() == LightType::DIRECTIONAL)
					{
						if(ImGui::TreeNode("Sun Light"))
						{
							ImGui::SliderFloat("Sun Yaw", &m_sunYaw, -180.0f, 180.0f);
							ImGui::SliderFloat("Sun Pitch", &m_sunPitch, -180.0f, 180.0f);

							Vec3 direction = Vec3::MakeFromPolarDegrees(m_sunPitch, m_sunYaw);

							if(direction != light.GetDirection())
							{
								g_renderer->ResetFrameAccumulationCounter();
								light.SetDirection(direction.GetNormalized());
							}

							ImGui::SeparatorText("Adjust Sun Light Intensity");
							float sunIntensity = light.GetIntesity();
							ImGui::SliderFloat("Sun Intensity", &sunIntensity, 0.0f, 50.0f);

							if(sunIntensity != light.GetIntesity())
							{
								g_renderer->ResetFrameAccumulationCounter();
								light.SetIntensity(sunIntensity);
							}

							ImGui::TreePop();
						}
						continue;
					}

					count += 1;

					if(ImGui::TreeNode(Stringf("Point Light %d", count).c_str()))
					{
						ImGui::Text("Position");

						Vec3 position = light.m_position;
						ImGui::PushItemWidth(80.0f);

						ImGui::Text("X"); 
						ImGui::SameLine();
						ImGui::SliderFloat("##X", &position.x, -10.f, 10.f);

						ImGui::SameLine();

						ImGui::Text("Y"); 
						ImGui::SameLine();
						ImGui::SliderFloat("##Y", &position.y, -10.f, 10.f);

						ImGui::SameLine();

						ImGui::Text("Z"); 
						ImGui::SameLine();
						ImGui::SliderFloat("##Z", &position.z, -10.f, 10.f);

						ImGui::PopItemWidth();

						if(position != light.m_position)
						{
							light.SetPosition(position);
							g_renderer->ResetFrameAccumulationCounter();
						}

						
						float intensity = light.GetIntesity();
						ImGui::Text("Intensity");
						ImGui::SameLine();
						ImGui::SliderFloat("##I", &intensity, 0.f, 10.f);

						if(intensity != light.GetIntesity())
						{
							light.SetIntensity(intensity);
							g_renderer->ResetFrameAccumulationCounter();
						}

						Vec4 color = light.GetColor();

						ImGui::Text("Color");
						ImGui::ColorEdit3("##C", &color.x);

						if(color != light.GetColor())
						{
							light.SetColor(color.x, color.y, color.z);
							g_renderer->ResetFrameAccumulationCounter();
						}


						ImGui::TreePop();
					}

				}
			}
			
			ImGui::EndTabItem();
		}
		ImGui::EndTabBar();
	}

//	ImGui::TextWrapped("Controls:\nWSAD - Move\nQ/E - Up/Down\nSpacebar - Toggle Mouse Pointer");


	//static const char* debugViewStrings[] =
	//{
	//	"Default Output View",				// 0
	//	"Position GBuffer View",			// 1
	//	"Albedo GBuffer View",				// 2
	//	"Vertex Color GBuffer View",		// 3
	//	"Normals GBuffer View",				// 4
	//	"Velocity GBuffer View",			// 5
	//	"Surface Normal GBuffer View",		// 6
	//	"Surface Tangent GBuffer View",		// 7
	//	"Surface Bitangent GBuffer View",	// 8
	//	"Roughness GBuffer View",			// 9
	//	"Metalness GBuffer View",			// 10
	//	"Reservoir Debug View",				// 11
	//	"Reservoir Debug: Pixels with 0 lights sampled",						// 12
	//	"Undefined",						// 13
	//	"Undefined",						// 14
	//	"Undefined",						// 15
	//	"Undefined",						// 16
	//	"Undefined",						// 17
	//	"Undefined",						// 18
	//	"Undefined"							// 19
	//};

	//ImGui::Text(Stringf("Current Debug View: %s", debugViewStrings[m_debugInfo.m_debugView]).c_str());
	//ImGui::End();

}
