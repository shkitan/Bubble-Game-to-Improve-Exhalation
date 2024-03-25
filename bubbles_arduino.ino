#include "Seeed_BMP280.h"
#include <Wire.h>
 
BMP280 bmp280;

void setup() {
 //initialize the serial communication:
 bmp280.init();
 Serial.begin(9600);
} 
 
void loop() {
 //send the value of analog input 0:
  Serial.print(analogRead(A0));
  float pressure;
 
  //get and print atmospheric pressure data
  Serial.print(",");
  Serial.print(pressure = bmp280.getPressure()); 
  Serial.print("\n");//add a line between output of different times.

//wait a bit for the analog-to-digital converter to stabilize after last 
//reading: delay(2); } 
}
