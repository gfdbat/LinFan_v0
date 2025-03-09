# LinFan_v0 (2025-03-09)
LinFan: IC Thermal Management System Based on Programmable Hardware(FPGA)

![image](https://github.com/user-attachments/assets/0bfd6fd0-bd72-44fa-8426-1f03e38c921f)
![image](https://github.com/user-attachments/assets/9a396d07-e195-4f7c-a62f-770dbbcf31d3)

LinFan is an efficient FPGA heat management system that provides functions such as temperature detection, fan control, RPM feedback, OLED display, etc. It can serve as a foundational module for more complex embedded systems.

It is a hardware controller based on programmable hardware FPGA, which can achieve automated thermal control and help release the performance of FPGA projects.It is an intelligent heat management system developed based on FPGA (Zynq XC7Z020), aimed at optimizing the heat dissipation effect of IC devices, improving system stability and performance. Traditional commercial heat management systems typically rely on EC (embedded controller) to control fan speed, while LinFan uses programmable hardware FPGA to achieve automated thermal control, allowing the performance of FPGA projects to be fully released.

This project is named LinFan, which means "smart" in Changsha City of Hunan province, China. Also, LinFan also contains the English word 'Fan', which is of great interest!

# Try Linfan on your FPGA
**It's simple and fast to do!**
First of all, you need to ensure that you have:
* An AMD Xilinx FPGA equipped with XADC
* A 4-pin PWM controlled speed fan
* A 4pin IIC interface OLED display screen (with a resolution of 128 * 64, and a controller of `SH1106` in my project)
* [Optional] 4 seven segment digital tubes
Follow the steps:
* Create a Vivado project and add RTL code to the project (Top Module: embedded_ctrl.v)
* Set clock constraints. The clock of PL needs to be set to 50MHz. 
* Set pin constraints to constrain the TACH and PWM interfaces of your fan, as well as the SCL and SDA interfaces of the screen IIC interface. Ensure that the TACH, SCL, and SDA interfaces are configured in PULLUP mode.
* IMPORTANT: Modify the OLED intialization commands in `oled_data_gen.v`, accroding to your OLED controller User Manual
* Finally, generate a bitstream!
![image](https://github.com/user-attachments/assets/05b016e7-c0c8-42e4-be31-b38add38d9e9)
# If you want to configure some parameters
* Target On-chip Temperatue (Default 40'C)
  * In `embedded_ctrl.v`, change `temp_target` in the instance of cooler_ctrl_tempTarget
* Threshold for fan to start running (Default is a difference of +- 1 degree between the actual temperature and the preset temperature)
  * In `cooler_ctrl_tempTarget.v`, modify the parameter of `TEMP_THRESHOLD` (10 * 0.1'C == 1'C)
* Frequency of Writing Pixels (Default 200, basically the limit of my OLED screen)
  * In `oled_data_gen.v`, modify the parameter of `WR_WAIT_TIME`
* Frequency of PWM
  * In `pwm_output.v`, modify the division factor(default 20 to generate 2.5MHz from 50MHz)

# TroubleShooting
* If the OLED display is not stable under 5V, then try 3.3V

# Contributing
Linfan is an open-source project and welcomes contributions.
