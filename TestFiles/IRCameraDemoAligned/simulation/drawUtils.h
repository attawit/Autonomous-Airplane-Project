#ifndef _drawUtils_h
#define _drawUtils_h

#include <stdlib.h>

#include <GL/gl.h>
#include <GL/glut.h>
#include <GL/gle.h> 

#include <iostream>
#include <fstream>

#include <Eigen/Core>
#include <Eigen/Geometry>
#include <math.h>

#include "mathUtils.h"

using namespace std;
// import most common Eigen types
USING_PART_OF_NAMESPACE_EIGEN

void drawCylinder(Vector3d pos, Matrix3d rot, double h, double r);
void drawCylinder(Vector3d start_pos, Vector3d end_pos, double r);
void drawEndEffector(Vector3d pos, Matrix3d rot, double degrees, float color0, float color1, float color2);
void drawGrip(Vector3d pos, Matrix3d rot, double radius, double degrees, float color0, float color1, float color2);
void drawSphere(Vector3d position, float radius);
void drawCursor(int device_id, float color);
void drawAxes(Vector3d pos, Matrix3d rot);
void labelAxes(Vector3d pos, Matrix3d rot);
void drawArrow(Vector3d pos, Vector3d direction);
void drawPlane(Vector3d pos, Vector3d normal, float side);
void printText(float x, float y, const char *string);

void glVertex3f(const Vector3d& v);
void glVertex3d(const Vector3d& v);

static double gCursorScale = 6;
static GLuint gCursorDisplayList = 0;

#endif //_drawUtils_h
