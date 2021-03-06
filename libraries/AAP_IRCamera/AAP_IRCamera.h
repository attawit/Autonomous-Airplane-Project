#ifndef AAP_IRCamera_h
#define AAP_IRCamera_h
#define byte uint8_t
#include <inttypes.h>

#include "../vector/vector.h"
#include "../AP_Math/AP_Math.h"

class AAP_IRCamera
{
  public:
	AAP_IRCamera();

	//Assumes sources is an array of size 4
	//sources[i] is invalid if both sources[i].x and sources[i].y are equal to 1023
	void init();
	void getRawData(Vector2i sources[]);
	void getRawDataFull(Vector2i sources[], uint8_t intensity[]);
	Vector3f getPosition();
	bool getTransform2(Vector3f& pos, Matrix3f& rot);
  private:
  	int _IRsensorAddress;
	int _slaveAddress;
	byte _data_buf[37];
	void Write_2bytes(byte d1, byte d2);
};
#endif
