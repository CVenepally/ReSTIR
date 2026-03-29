#pragma once
#include "Engine/Renderer/Camera.hpp"
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
struct Vec3;
struct EulerAngles;

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------
class GameCamera
{
public:

	GameCamera(Vec3 const& position, EulerAngles const& orientation);
	~GameCamera();

	void Update();

	Vec3 GetCameraPosition()	const;
	Vec3 GetCameraOrientation() const;
	Vec3 GetForwardNormal()		const;
	
	void SetCameraPosition(Vec3 const& newPosition);
	void SetCameraOrientation(EulerAngles const& newOrientation);
private:

	void UpdateKeyboardControls();
	void UpdateCamera();

private:

	Camera m_camera = Camera();

};