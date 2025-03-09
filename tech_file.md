[image](https://github.com/user-attachments/assets/f72c304f-b39b-4642-838a-ebc296205566)
# LinFan: IC Thermal Management System Based on Programmable Hardware

## 1 Background

Most modern laptops are equipped with fans to actively dissipate heat in order to release performance, allowing the processor to maintain high-frequency operation. The thermal management system of IC usually has hardware and software layers, with hardware mainly including controllers, temperature sensors, PWM adjustable fans, etc., and software mainly including control algorithms. A good thermal management system can efficiently control the temperature of the main hardware and ensure the normal operation of the system.

EC (Embedded Controller) is commonly used for control in commercial products. I will develop a hardware controller based on programmable hardware FPGA, which can achieve automated thermal control and help release the performance of FPGA projects.

The project is named LinFan, which means "smart" in Changsha City of Hunan province. At the same time, LinFan also contains the English word 'Fan', which has a lot of meaning!

### 1.1 Composition of thermal management system
Main control process:
* temperature detection => fan speed regulation and driver

Temperature sensor:
* On chip integration of processors
* Temperature control IC on the motherboard
* Temperature control IC on the fan

Fan Control Method:
* Pre-set temperature curve
  * One temperature corresponds to one speed, which is relatively unstable and difficult to converge quickly
* Dynamic adjustment strategy
  * PID algorithm or machine learning algorithm (based on load prediction of fan demand)
* MINE: target temperature driving
  * Users can input a preset temperature, and the system will then attempt to stabilize at this temperature

Fan control and feedback:
* Input control
  * PWM Pulse Width Modulation
  * DC linear speed regulation
* output feedback
  * TACH/SENSE speed feedback

## 2 Specific Implementation Plan
The control layer of the system (based on Zynq FPGA: xc7z020clg400-2):
* Need a temperature reading module to read the temperature from the sensor
* Need a fan speed regulation module to dynamically control the fan speed based on the absolute value and relative change of temperature. The specific control method is PWM
* Need an OLED control module to receive various parameters from the system and fan parameters, integrate them into data and curves, and drive the OLED display screen for real-time display through the IIC interface

The system's peripherals mainly include:
* 4-pin (including PWM and RPM) cooling fan
* 1.3-inch OLED display screen. Used to monitor temperature values, controller speed control values, fan speed values, and to draw temperature+RPM curves for easy observation of thermal management control processes
* Seven segment digital tube. Used for debugging in the early stages of development

Regarding the control strategy of the fan:
* Adopting a differential control strategy, the speed of the fan is adjusted based on temperature changes, rather than absolute temperature and speed. Specifically, in FPGA, the controller is implemented using FSM finite state machine, which is divided into four states (initial, temperature+, temperature -, temperature stable) to dynamically regulate the fan speed. But even if this method can make the temperature converge, it is difficult to estimate the final stable value
* Another strategy is to add a constraint to the controller, which is the final temperature target value. The controller strives to achieve and stabilize at this temperature value through relevant algorithms. In future embedded system designs, this will facilitate users to choose the system's working mode (energy-saving priority, balance or performance priority), increase the system's configurability and adaptability

### 2.1 Temperature Reading
The temperature reading part includes two aspects, one is the temperature sensor (XADC embedded in FPGA), and the other is the controller XADC_ctrl for reading temperature. The controller continuously sends read data requests through XADC's DRP interface and reads the data when the temperature data is ready. The read data is the 12 bit raw data raw_temp, which needs to be converted according to the following formula to obtain the Celsius temperature:

![image](https://github.com/user-attachments/assets/0b8dbce9-99cc-47ba-adf5-c67637c0d7f6)
<center>AMD Xilinx ug480_7series_XADC.pdf P57</center>

This temperature is used for subsequent fan speed regulation and OLED monitor display. To control the fan more finely, convert it in units of 0.1 degrees Celsius. Let the encoding of ADC be x, the temperature in Celsius (0.1'C) be T, then there is
$$T=(x\times\frac{503.975}{4096}-273.15)\times10=1.2304x-2731.5$$
For example, when encoded as 0x997 (2455), the corresponding temperature is 28.91'C. Now we need to consider how to implement it using Verilog. While ensuring the conversion speed, try to increase it as much as possible. In terms of multiplication, shift is used:
$$1.2304=1+0.125(1+0.25+0.125)+\delta=1.21875+\delta$$
Corresponding to three shifts (>>3,>>4,>>5), the functions that Verilog can now implement:
$$T_1=x+x>>3+x>>4+x>>5-2731=1.21875x-2731$$
Of course, this comes at the cost of accuracy, with a slope difference of as much as 0.01. Considering the temperature encoding is relatively large, which will result in single digit and significant errors. Consider adjusting the intercept to correct this error. Note that the application scenario is for daily use, with temperatures roughly ranging from 20 ° C to 100 ° C, just need to control the error within this range. Observing that by adjusting the intercept, the average error can be reduced, resulting in a corrected version:

![image](https://github.com/user-attachments/assets/4b57682b-f098-42c3-ba2c-19ab38dee9d2)
<center>Optimize the temperature value conversion process</center>
With this limitation, calculate the errors corresponding to the beginning and end of the interval, which are 28 and 32 respectively, and take the average as 30, that is, let the function the intercept of increases by 30 to 2701, resulting in the corrected function
$$T_2=1.21875x-2701$$
The maximum error of this function in the applied interval does not exceed 2, which is 0.2 ℃. Create graphs of these functions in Geogebra:
![image](https://github.com/user-attachments/assets/81a749f0-2e5d-4f00-a92d-3bb4e021c8b7)
**legend**
* The red line represents the ideal
* The blue line represents before the correction
* The green line represents the revised version
It is obvious to see that the difference between the red line and the green line is very small, and the error control is very good.
![image](https://github.com/user-attachments/assets/a875cb50-cbde-404f-9fac-97842de35db5)
On a larger scale, it can be seen that difference between T1 and T2 is significant, and the approximation effect is not good.
At this point, we have obtained a key sensor value: temperature on the chip.

### 2.2 Early debugging tools: Seven segment digital tube
In the early stages of verifying the smooth reading of temperature values, if the OLED display screen with IIC interface was used, there would be too much development content and errors would be difficult to debug. Therefore, the simplest and most stable seven segment digital tube was used to display the temperature and verify the correctness of temperature reading.
The temperature has just been read as bin binary and requires a module to convert it into BCD code. Then another module is needed to read the BCD code and scan four seven segment digital tubes (a total of 16 bits) at a certain frequency. The effect is as follows:

![image](https://github.com/user-attachments/assets/61cd72e7-c01e-477b-a3c1-c13c116fb6ba)
<center>Seven segment digital tube displays junction temperature(38.8'C)</center>

After completing the RPM fan speed module, this seven segment digital tube can also be used for quick verification.

### 2.3 OLED display screen with IIC interface
This display screen serves as a monitor for the system and is planned to display three parameters: IC temperature, fan speed output by the temperature control module, and fan speed RPM obtained by actually reading the TACH pin. I bought a 1.3-inch OLED screen with IIC interface for 14RMB(about $1.9351) on Taobao, as shown below:

![image](https://github.com/user-attachments/assets/197f8416-0257-4c41-a24c-33616e64d68f)

This screen is a complete component that includes a screen and a controller, with the controller being an IIC interface. When using this screen, mainly refer to the data manual of the controller:

![image](https://github.com/user-attachments/assets/d63d2fc2-29c7-43cc-9b2b-20ed29de427a)
<center>OLED Controller Model: SH1106</center>

Two types of data can be passed in through the IIC interface: one is a command type used to configure registers; Another way is to display data, which will be written to an embedded RAM by the controller. The information provided by the display screen merchant includes a data manual. Due to being a commercial product, the controller of IIC is very complex with many commands, making it difficult to start at once. Another source of information is software engineering for embedded development platforms, such as STM32 and 8051 microcontrollers. I have found that these software engineering can also greatly assist in RTL development. View the main of STM32 project:

```c
#include "bmp.h"
 int main(void)
  {	u8 t;
		delay_init();	    	 // Delay function initialization
		NVIC_Configuration(); 	 // Set NVIC interrupt grouping with 2 bits of preemption priority and 2 bits of response priority
LED_Init();			     // LED port initialization
		OLED_Init();			// OLED Initialization 
		OLED_Clear()  	; 
	
		t=' ';
		OLED_ShowChar();
...
```
There are three key functions: the Init function is used to configure the screen controller, the Clear function is used to clear the screen (after power on, the data in RAM is messy and the screen will appear blurred, so it needs to be cleared), and the showChinese/showChar function displays specific data on the screen.
```
void OLED_Init(void)
{ 	
...
	OLED_WR_Byte(0xAE,OLED_CMD);//--display off
	OLED_WR_Byte(0x02,OLED_CMD);//---set low column address
	OLED_WR_Byte(0x10,OLED_CMD);//---set high column address
	OLED_WR_Byte(0x40,OLED_CMD);//--set start line address  
	OLED_WR_Byte(0xB0,OLED_CMD);//--set page address

	OLED_WR_Byte(0x81,OLED_CMD); // contract control
	OLED_WR_Byte(0xFF,OLED_CMD);//--128   

	OLED_WR_Byte(0xA1,OLED_CMD);//set segment remap 
	OLED_WR_Byte(0xA6,OLED_CMD);//--normal / reverse
	OLED_WR_Byte(0xA8,OLED_CMD);//--set multiplex ratio(1 to 64)
	OLED_WR_Byte(0x3F,OLED_CMD);//--1/64 duty

	OLED_WR_Byte(0xAD,OLED_CMD);//set charge pump enable
	OLED_WR_Byte(0x8B,OLED_CMD);//-0x8B internal VCC
	OLED_WR_Byte(0x33,OLED_CMD);//-0X30---0X33 set VPP 9V
...
}
void OLED_Clear(void)  
{  
	u8 i,n;		    
	for(i=0;i<8;i++)  
	{  
		OLED_WR_Byte (0xb0+i,OLED_CMD);    // Set Page Addr(0-7)
		OLED_WR_Byte (0x02,OLED_CMD);      // Set Display Position-High Column Addr
		OLED_WR_Byte (0x10,OLED_CMD);      // Set Display Position-Low Column Addr
		for(n=0;n<128;n++)OLED_WR_Byte(0,OLED_DATA); 
	} //Update Display
}
void OLED_ShowChar(u8 x,u8 y,u8 chr,u8 Char_Size)
{      	
	unsigned char c=0,i=0;	
		c=chr-' ';// Offset			
		if(x>Max_Column-1){x=0;y=y+2;}
		if(Char_Size ==16){
			OLED_Set_Pos(x,y);	
			for(i=0;i<8;i++)
				OLED_WR_Byte(F8X16[c*16+i],OLED_DATA);
			OLED_Set_Pos(x,y+1);
			for(i=0;i<8;i++)
				OLED_WR_Byte(F8X16[c*16+i+8],OLED_DATA);
		}else{	
			OLED_Set_Pos(x,y);
			for(i=0;i<6;i++)
				OLED_WR_Byte(F6x8[c][i],OLED_DATA);			
		}
}
```
As can be seen, these functions use two key subfunctions, Set_Sos (x, y) and WR_Syte (data). The former sets the display coordinates, while the latter transmits specific binary data. So in RTL, if these two functions can be implemented, the most basic display function can be completed. Of course, an IIC interface or controller is also required in RTL to send the bytes to be sent out in IIC timing.
Step by step, first we try to light up the screen, then try to display one character, and finally display multiple characters, as well as connect real-time signals such as external signals (temp, RPM) to the screen. The emotional journey is recorded as follows:

![image](https://github.com/user-attachments/assets/8b89fa46-54ab-45bf-bb01-357aa20f5950)
<center>Step 1: Turn on the screen(Don’t ask why it is shattered)</center>

![image](https://github.com/user-attachments/assets/c551dc45-8c47-43ad-9097-f43f283bb601)
<center> Clear screen + write a few characters </center>

The specific Verilog implementation mainly consists of two modules: `oled_data_gen` and `iic_dri`. The former generates pixel data to be displayed and initializes configuration commands, while the latter is the controller of IIC, both of which use FSM finite state machine method to implement.

### 2.4 Selection and installation of Fan/Cooler
I have been browsing on taobao.com for a long time, but I haven't seen any suitable fans. Finally, I saw a fan specifically designed for the Raspberry Pi 5, but I found that it could also be used for my FPGA core board because its size is almost the same as mine, so I placed an order decisively. He is the Raspberry Pi 5 Active Cooler.

![image](https://github.com/user-attachments/assets/6953b058-62b5-4134-bee8-13722967218f)
<center>Raspberry Pi 5: Active Cooler</center>

The Raspberry Pi has built-in control for the fan, and if it is a Raspberry Pi development board, it can be plug and play. I only realized after buying it that the fan interface uses a very rare JST-SH interface with a one millimeter spacing, which cannot be connected to the development board with DuPont wire. In order to expedite the development process, I adopted a very primitive approach:

![image](https://github.com/user-attachments/assets/357c407e-ca09-44d0-82c6-01ed3cc26be8)

Yes, I just cut off the head of the DuPont wire, peeling off a part of the skin, and twisting a part of the wire into a bundle (yes, the JST-SH socket is very thin, only about three or four copper wires can be inserted) and inserting it into the JST-SH interface. Fortunately, there are only four and the operation is relatively fast. But this method exposes the metal wires and is prone to short circuits. Once configured, they cannot be moved.

![image](https://github.com/user-attachments/assets/013c436e-65ff-4d5e-9f95-a0fab2b312f2)
<center>Rearrange thermal conductive silicone sheet</center>

Four thermal conductive silicone sheets have been attached to the bottom of the fan, but they are compatible with Raspberry Pi 5 and do not match my core board. So a piece of paper was used as an intermediary. First, the paper was pressed onto the core board to create a shape and the edges of FPGA, DDR, Flash, and eMMC were drawn with a pen. Then, a thermal conductive silicone sheet was attached to the paper. Finally, the silicone was attached to the bottom of the heat sink with the paper, and the paper was gently peeled off. The final effect was very ideal.
Now the fan has also been connected to the system, bringing two new wires: PWM and RPM.
PWM is the signal that RTL needs to output to the fan. Create a new module, read in the fan speed control value 'speed', and set the output PWM duty cycle according to this value. As for RPM, it is the signal input to RTL.
Create another module to read in this RPM signal and calculate the RPM value. Now that we have the temperature value and RPM value, we can send these two values to the display module for display:

![image](https://github.com/user-attachments/assets/6b2f91f7-5844-4193-8ff4-076ae1c4a773)
<center>Display temperature and RPM of fan</center>

Now the entire system has completed half of it, and the remaining part is mainly the control function, which dynamically adjusts the fan speed according to temperature changes. Implementing this function means that the system has formed an organic whole, and can even be packaged as Vivado's IP, serving as an important guarantee module when implementing larger embedded systems based on FPGA in the future.

## 3 Design and Implementation of Display Screen Driver Module

![image](https://github.com/user-attachments/assets/5b16f432-d9ca-43d9-85a4-c2351ec0302a)
<center>Display driver architecture</center>

The display screen is an IIC interface, so an IIC driver is needed to convert data into I2C protocol waveforms. Going further, we need a data generator for displaying data and a module for sending data. The final plan is to display two main contents on the display screen, text version data and waveform version data, so two large register groups were designed to store these data.
For numerical data, refresh the latest data into the register group at regular intervals. For waveform data, it is stored in the form of a shift register group, whose size corresponds one-to-one with the pixels of the display screen (the waveform displays 4 pages, each page is 8 * 128 in size).

Due to the short time required for each refresh (with few pixels), it is refreshed every time the clock arrives. The waveform data can only be refreshed at a reduced speed, and when it needs to be refreshed, the rising edge of wave_flashflag notifies the waveform register group. Each refresh only needs to refresh the rightmost pixel column, so that the dynamic effect of the waveform moving to the left can be achieved through shifting.

The data needs to be preprocessed before it can be sent to the register group. The displayed waveform is divided into temperature waveform and fan RPM waveform. The length of the pixel column is 32 (0-31), so it is necessary to map the range of data to this range, and this mapping is linear, so it is easy to implement.

$$Temperature([20-70]=>[0-31]): temp_{mapped} = (temp >> 4) – 10$$
$$RPM([0-10000]=>[0-31]): RPM_{mapped} = RPM >> 8$$

Afterwards, in order to display a straight line on the screen, each column can only have one pixel. To distinguish, display three adjacent pixels of temperature, with a temperature line width of 3, by first converting to a unique heat code and then shifting left and right. The waveform of RPM has a width of only one pixel.

$$temp_{waved} = 32'b1 << temp_{mapped} | ((32'b1 << temp_{mapped}) >> 1) | ((32'b1 << temp_{mapped}) << 1)$$
$$RPM_{waved} = 32'b1 << RPM_{mapped}$$

Then, use an OR gate (two waveforms overlap and cannot be seen) or an XOR gate (RPM displays as 0 when two waveforms overlap) to combine the two waveforms and send them to the shift register group. At this point, the architecture of the display driver has been perfected. The specific driver for this display driver architecture is implemented using FSM.

## 4 Overall Architecture

![image](https://github.com/user-attachments/assets/801a9922-bc24-4df0-9710-cf916f4705b6)
<center>Overall Architecture: Architecture Diagram</center>
![image](https://github.com/user-attachments/assets/1269ee19-b7a0-45fa-8a7a-26c99442d3fc)
<center>Overall Architecture: Micro-architecture Diagram</center>

At this point, the overall architecture of the system has also been implemented. The XADC Controller reads the temperature on the chip and provides it to the fan controller and display module. The fan controller outputs a control speed (speed, 0-100), which determines the duty cycle of the PWM waveform and is converted into the corresponding PWM waveform. The TACH feedback provided by the fan is converted into RPM value by RPM Counter and provided to the display module. The central FSM of the system is the fan control FSM, as shown in the following figure:

![image](https://github.com/user-attachments/assets/6582db6e-4d9e-42da-910b-467abbde7049)
<center>FSM Diagram of the Fan Controller</center>

Users can input a preset temperature, and the system will then attempt to stabilize at this temperature. When the temperature exceeds the preset temperature by more than 1 ° C, the temperature of the fan will slowly increase; Otherwise, the speed will decrease. When the temperature is within the preset temperature range of ± 1 ° C, the temperature of the fan will stabilize. According to this plan, theoretically, under the condition of constant load, the oscillation of temperature and RPM will gradually decrease, and the system will automatically output an RPM that is most suitable for the target temperature, ensuring the stable operation of the entire FPGA on-chip system.

![image](https://github.com/user-attachments/assets/453a618b-75f8-4dc7-92ef-5f626d47483b)
<center>The Whole Happy Family</center>

At this point, the project has come to an end. There may be new feature updates in the future (such as screen display content updates or algorithm updates for fan speed controllers), please continue to follow me😊 
Welcome to friendly communication, your support is my biggest motivation for updating :)
Follow me and follow up on the progress of this project!

2025-03-09 18:27 GTM+8
Beijing, China



