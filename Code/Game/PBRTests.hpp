#pragma once
#include "Game/Scene.hpp"
#include "Engine/Renderer/Light.hpp"

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
struct Light;

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
class PBRTests : public Scene
{
public:
	PBRTests();
	virtual ~PBRTests();

	virtual void	InitSceneGeometry() override;
	virtual void	Update() override;
	virtual void	Render() override;

	void			CreatePBRSphere(Vec3 const& position, std::string const& textureName);
	void			SetDebugValues();

	void			AdjustSunDirection();

	Light			m_sunLight;
	float			m_ambientIntensity = 0.4f;
					
	float			m_sunPitch = 0.f;
	float			m_sunYaw = 0.f;

	bool			m_firstFrame = true;
	bool			m_useAmbient = false;

	std::vector<Light> m_lights;

};