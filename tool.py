##########################################################
#
# Tool for RTL code generation
#
##########################################################

# for i in range(127):
# #for i in reversed(range(127)):
#     #print(f"{{waved[3][{i*8+7}:{i*8}],waved[2][{i*8+7}:{i*8}],waved[1][{i*8+7}:{i*8}],waved[0][{i*8+7}:{i*8}]}} <= {{waved[3][{(i+1)*8+7}:{(i+1)*8}],waved[2][{(i+1)*8+7}:{(i+1)*8}],waved[1][{(i+1)*8+7}:{(i+1)*8}],waved[0][{(i+1)*8+7}:{(i+1)*8}]}};")
#     #print(f"{127-i}: i2c_data_w <= waved[wave_pos_cnt][{i*8+7}:{i*8}];")
#     print(f"{i}: i2c_data_w <= waved[wave_pos_cnt][{i*8+7}:{i*8}];")

for i in range(8):
    print(f'ow[{i}],',end='')