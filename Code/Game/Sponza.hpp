#pragma once
#include "Game/Scene.hpp"
#include "Engine/Renderer/Light.hpp"
#include "Engine/Core/ModelLoader.hpp"

class StaticMesh;
class StructuredBuffer;

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
struct SceneObject
{
	std::string				m_name;
	StaticMesh*				m_mesh = nullptr;

	Mat44					m_transform;
};
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
class Sponza : public Scene
{
public:
	Sponza();
	virtual ~Sponza();

	virtual void	InitSceneGeometry() override;
	virtual void	Update() override;
	virtual void	Render() override;

	void			SetDebugValues();

	void			AdjustSunDirection();

	void			LoadGLTFSceneContents(std::string const& gltfFilePath, std::string const& texturePath);
	void			LoadGLTFNode(tinygltf::Node const& node, tinygltf::Model& model, Mat44 const& parentGlobalTransform, std::string const& texturePath);

	void			InitLights();

	Light			m_sunLight;
	float			m_ambientIntensity = 0.4f;
					
	float			m_sunPitch = 0.f;
	float			m_sunYaw = 0.f;

	bool			m_firstFrame = true;
	bool			m_useAmbient = false;
	bool			m_renderLights = true;

	float			m_minPointLightIntensity = 0.f;
	float			m_maxPointLightIntensity = 3.f;

	std::vector<SceneObject> m_sceneObjects;
	std::vector<Light> m_allLights;
	std::vector<Light> m_sceneLights;

// 	StructuredBuffer* m_lightsBuffer;
};