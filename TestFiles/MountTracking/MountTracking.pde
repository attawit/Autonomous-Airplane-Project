// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: t -*-

//
// Simple test for the AP_IMU_Oilpan driver.
//

#include <FastSerial.h>
#include <AP_GPS.h>         // ArduPilot GPS library
#include <SPI.h>
#include <Arduino_Mega_ISR_Registry.h>
#include <AP_PeriodicProcess.h>
#include <AP_InertialSensor.h>
#include <AP_IMU.h>         // ArduPilot Mega IMU Library
#include <AP_DCM.h>         // ArduPilot Mega DCM Library
#include <AP_Math.h>
#include <AP_Common.h>
#include <AP_ADC.h>
#include <APM_RC.h> // ArduPilot Mega RC Library
APM_RC_APM1 APM_RC;

#include <AP_Math.h>
#include <matrix3.h>
#include <polygon.h>
#include <vector2.h>
#include <vector3.h>

// Configuration
#include "config.h"

////////////////////////////////////////////////////////////////////////////////
// Serial ports
////////////////////////////////////////////////////////////////////////////////
FastSerialPort(Serial, 0);

////////////////////////////////////////////////////////////////////////////////
// ISR Registry
////////////////////////////////////////////////////////////////////////////////
Arduino_Mega_ISR_Registry isr_registry;

////////////////////////////////////////////////////////////////////////////////
// Sensors
////////////////////////////////////////////////////////////////////////////////
// All GPS access should be through this pointer.
static GPS *g_gps;
AP_GPS_None g_gps_driver(NULL);

static AP_ADC_ADS7844          adc;
//AP_InertialSensor_MPU6000 mpu6000( 53 ); /* chip select is pin 53 */
AP_InertialSensor_Oilpan ins( &adc );
//AP_IMU_INS imu(&mpu6000, 0); /* second arg is for Parameters. Can we leave it null?*/
AP_IMU_INS imu(&ins, 0);
AP_DCM dcm(&imu, g_gps);

// we always have a timer scheduler
AP_TimerProcess timer_scheduler;

////////////////////////////////////////////////////////////////////////////////
// LED output
////////////////////////////////////////////////////////////////////////////////
#define A_LED_PIN        37
#define C_LED_PIN        35
#define LED_ON           LOW
#define LED_OFF          HIGH

////////////////////////////////////////////////////////////////////////////////
// IMU variables
////////////////////////////////////////////////////////////////////////////////
// The main loop execution time.  Seconds
//This is the time between calls to the DCM algorithm and is the Integration time for the gyros.
static float G_Dt						= 0.02;		

////////////////////////////////////////////////////////////////////////////////
// System Timers
////////////////////////////////////////////////////////////////////////////////
// Time in miliseconds of start of main control loop.  Milliseconds
static unsigned long 	fast_loopTimer;
static unsigned long 	medium_loopCounter = 0;
// Number of milliseconds used in last main loop cycle
static uint8_t 		delta_ms_fast_loop;

static void flash_leds(bool on)
{
  digitalWrite(A_LED_PIN, on?LED_OFF:LED_ON);
  digitalWrite(C_LED_PIN, on?LED_ON:LED_OFF);
}

/** Returns the mapped integer of "value". This linear map F is defined such that:
  * F(value_min) = mapped_min
  * F(value_max) = mapped_max
  **/
int linearMap(int value, int value_min, int value_max, int mapped_min, int mapped_max) {
  return mapped_min + (((float)(value - value_min))/((float)(value_max-value_min)))*(mapped_max-mapped_min);
}

int panAngleToPW(int angle) {
  return linearMap(angle, -45+13, 45+13, 1000, 2000);
}

int tiltAngleToPW(int angle) {
  int servo_angle = 0.005404 * pow(angle, 2.0) + 1.54987 * ((float) angle) - 3.02604;
  return linearMap(servo_angle, 45-1, 135-1, 2000, 1000);
}

/*
int servoToTiltAngle(int servoAngle) {
  return -0.001468 * pow(servoAngle, 2.0) + 0.64516 * ((float) servoAngle) + 1.95896;
}

int tiltToServoAngle(int tiltAngle) {
  return 0.005404 * pow(tiltAngle, 2.0) + 1.54987 * ((float) tiltAngle) - 3.02604;
}
*/

template <typename T>
void printVector(Vector3<T> v)
{
  Serial.printf("%4.2f  %4.2f  %4.2f\n", v.x, v.y, v.z);
}

template <typename T>
void printMatrix(Matrix3<T> m)
{
  printVector(m.a);
  printVector(m.b);
  printVector(m.c);
}

float angle(Vector3f Va, Vector3f Vb, Vector3f Vn)
{
  float sina = (Va%Vb).length();
  float cosa = Va*Vb;
  float angle = atan2( sina, cosa );
  if (Vn*(Va%Vb) < 0.0)
	angle *= -1.0;
  return angle;
}

void trackingAngles(Vector3f track, Vector3f zero_pan_axis, Vector3f pan_axis, float &pan, float &tilt) {
  // Projection of track onto the plane with normal zero_pan_axis
  Vector3f track_onto_plane = track - pan_axis * (track*pan_axis);
  float backup_pan = pan;
  pan = ToDeg(angle(zero_pan_axis, track_onto_plane, pan_axis));
  if (pan > 90.0)
    pan -= 180.0;
  else if (pan < -90.0)
    pan += 180.0;
  Vector3f tilt_axis = zero_pan_axis%pan_axis;
  // tilt_axis gets rotated by the pan
  tilt_axis = Matrix3f(ToRad(pan), pan_axis) * tilt_axis;
  tilt = ToDeg(angle(track_onto_plane, track, tilt_axis)) - 90.0;
  if (tilt < -90.0)
    tilt += 180.0;
  // Prevents rapid change of pan at the singularities of tilt near zero
  if (tilt > -10.0 && tilt < 10.0)
    pan = backup_pan;
}

void setup(void)
{
  pinMode(53, OUTPUT);
  digitalWrite(53, HIGH);
  
  Serial.begin(9600);
  Serial.println("Doing IMU startup...");
  
  isr_registry.init();
  timer_scheduler.init(&isr_registry);
  APM_RC.Init(&isr_registry);
  
  imu.init(IMU::COLD_START, delay, flash_leds, &timer_scheduler);
  dcm.matrix_reset();
  
  delay(1000);
}

void loop(void)
{
  delay(20);
  if (millis() - fast_loopTimer > 19) {
    delta_ms_fast_loop 	= millis() - fast_loopTimer;
    G_Dt 		= (float)delta_ms_fast_loop / 1000.f;		// used by DCM integrator
    fast_loopTimer	= millis();
    
    // IMU
    // ---
    dcm.update_DCM();

    // We are using the IMU
    // ---------------------
    Vector3f gyros = imu.get_gyro();
    Vector3f accels = imu.get_accel();
    
    /*Serial.printf_P(PSTR("r:%4d  p:%4d  y:%3d  g=(%5.1f %5.1f %5.1f)  a=(%5.1f %5.1f %5.1f)\n"),
      (int)dcm.roll_sensor / 100,
      (int)dcm.pitch_sensor / 100,
      (uint16_t)dcm.yaw_sensor / 100,
      gyros.x, gyros.y, gyros.z,
      accels.x, accels.y, accels.z);*/
    
    float yaw = (float)dcm.yaw_sensor / 100.0;
    float pitch = (float)dcm.pitch_sensor / 100.0;
    float roll = (float)dcm.roll_sensor / 100.0;
    Serial.printf("%3.2f %3.2f %3.2f END\n", yaw, pitch, roll);
    
    /*Matrix3f rotation = Matrix3f(ToRad(roll), Vector3f(0.0, 1.0, 0.0))
                        * Matrix3f(ToRad(pitch), Vector3f(1.0, 0.0, 0.0))
                        * Matrix3f(-ToRad(yaw), Vector3f(0.0, 0.0, 1.0));*/
    Matrix3f rotation = Matrix3f(ToRad(roll), Vector3f(1.0, 0.0, 0.0))
                        * Matrix3f(ToRad(pitch), Vector3f(0.0, 1.0, 0.0))
                        * Matrix3f(ToRad(yaw), Vector3f(0.0, 0.0, 1.0));
    // Standard convention for yaw, pitch, roll gives the follwing coodinates:
    // x axis - front
    // y axis - 90 degrees clockwise from x axis when looking from up
    // z axis - down
    printMatrix(rotation);
    
    float pan, tilt;
    Vector3f track = rotation.col(0);
    Vector3f zero_pan_axis(0.0, 1.0, 0.0);
    Vector3f pan_axis(0.0, 0.0, 1.0);
    trackingAngles(track, zero_pan_axis, pan_axis, pan, tilt);
    
    int panServo  = panAngleToPW(int(pan));
    int tiltServo = tiltAngleToPW(int(tilt));
    
    //Serial.printf("Pan:   %4.2f  Servo 0 Value: %d\n", pan,  panServo);
    //Serial.printf("Tilt:  %4.2f  Servo 1 Value: %d\n", tilt, tiltServo);
    APM_RC.OutputCh(0, panServo);
    APM_RC.OutputCh(1, tiltServo);
  }
}
