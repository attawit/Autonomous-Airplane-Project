// -*- tab-width: 4; Mode: C++; c-basic-offset: 3; indent-tabs-mode: t -*-
/*
	AAP_Sonar.cpp - Arduino Library for AAP Sonar Sensor

	Variables:


	Methods:
		getDistance() : read value from analog port and return distance in cm

*/

#include "AAP_Sonar.h"
#include "WProgram.h"

// vars
volatile int raw = 0;
volatile float cm = 0;

// Constructor //////////////////////////////////////////////////////////////
AAP_Sonar::AAP_Sonar()
{
	pinMode(6,INPUT);
}
// Public Methods //////////////////////////////////////////////////////////////
float
AAP_Sonar::getDistance()
{
	raw = analogRead(6);
	cm = raw * 1.26554528; // cm = raw * 5 / 0.0098 / 1024 * 2.54
	return cm;
}