#pragma once
#include "Game/Scene.hpp"
#include "Engine/Renderer/Light.hpp"

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
class TestScene : public Scene
{
public:
	TestScene();
	virtual ~TestScene();

	virtual void InitSceneGeometry() override;
	virtual void Update() override;
	virtual void Render() override;

	void		AdjustSunDirection();
	void		SetDebugValues();

	Light					m_sunLight;
	float					m_ambientIntensity = 0.4f;

	float					m_sunPitch = 0.f;
	float					m_sunYaw = 0.f;

	bool					m_firstFrame = true;
	bool					m_useAmbient = false;
};