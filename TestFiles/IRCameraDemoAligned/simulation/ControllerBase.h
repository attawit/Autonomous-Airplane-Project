#ifndef _ControllerBase_h
#define _ControllerBase_h

#include <stdlib.h>

#include <GL/gl.h>
#include <GL/glut.h>
#include <GL/gle.h>

#include <iostream>
#include <fstream>

#include <Eigen/Core>
#include <Eigen/Geometry>
#include <math.h>
#include <vector>

using namespace std;
USING_PART_OF_NAMESPACE_EIGEN

enum button_type { UP, DOWN };

class ControllerBase
{
public:

  ControllerBase(const Vector3d& pos, const Matrix3d& rot)
  	: position(pos)
  	, rotation(rot)
  {}
  
  ControllerBase()
  	: position(0.0, 0.0, 0.0)
  	, rotation(Matrix3d::Identity())
  {}

  ~ControllerBase() {}

  void setTransform(const Vector3d& pos, const Matrix3d& rot)
  {
  	position = pos;
  	rotation = rot;
  }
  
  void setTransform(ControllerBase* control)
  {
  	position = control->position;
  	rotation = control->rotation;
  }

  void getTransform(Vector3d& pos, Matrix3d& rot)
  {
  	pos = position;
  	rot = rotation;
  }
  
  const Vector3d& getPosition() const
  {
  	return position;
  }

  const Matrix3d& getRotation() const
  {
  	return rotation;
  }

  virtual bool hasButtonPressed(button_type bttn_type) = 0;

	virtual bool hasButtonPressedAndReset(button_type bttn_type) = 0;
  
protected:
  Vector3d position;
  Matrix3d rotation;
};

#endif // _ControllerBase_h

