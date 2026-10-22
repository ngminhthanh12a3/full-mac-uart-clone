import serial, threading, time
from serial.threaded import ReaderThread, Protocol
import numpy as np

ser = serial.Serial('/dev/ttyUSB0', 4808)

f16_info = np.finfo(np.float16)
print("float16 info:")
print("  Min:", f16_info.min)
print("  Max:", f16_info.max)
print("  Precision:", f16_info.precision)

send_block = [0, '', 0, 0]
temp_rx_bin = b''
def send_serial_data(ser: serial.Serial, send_block:list):
    input_success = 0
    output_success = 0
    print("tx: ", ser.name)         # check which port was really used
    while True:
        with open('mac_fp16_golden_pattern.txt', 'r') as f:
            f_lines = f.readlines()
            # for line in f:
            for i in range(len(f_lines)):
                # send_block[1] = i
                send_block[2] = send_block[3] = 0
                
                print(f"Test case {i} ###########################")
                line = f_lines[i]
                byte_str_arr = line.split('_')
                byte_str_arr[-1].replace('\n', '')
                
                
                byte_arr = [int(byte_str, 2).to_bytes((len(byte_str) + 7) // 8, byteorder='big') for byte_str in byte_str_arr]
                byte_arr = b''.join(byte_arr)#.join(b'\xab\xcd')
                byte_arr = b'\xab\xcd\x01\x09' + byte_arr + b'\xab\xcd'
                
                str_byte_arr = ' '.join([f'{msb:08b}{lsb:08b}' for (msb, lsb) in zip(byte_arr[4:-3:2], byte_arr[5:-4:2])]+[f'{byte_arr[-3]:08b}'])
                print("Send Data: ", str_byte_arr)
                send_block[1] = str_byte_arr
                
                ser.write(byte_arr)

                while not send_block[0]:
                    pass
                
                input_success += not not send_block[2]

                send_block[0] = 0

                byte_arr = b'\xab\xcd\x00\x00\xab\xcd'
                str_byte_arr = ' '.join([f'{msb:08b}{lsb:08b}' for (msb, lsb) in zip(byte_arr[4:-3:2], byte_arr[5:-3:2])]+[f'{byte_arr[-3]:08b}'])
                print("Send Output-Requesting Frame, expected output: ", byte_str_arr[-2])
                send_block[1] = byte_str_arr[-2]
                ser.write(byte_arr)

                while not send_block[0]:
                    pass

                output_success += not not send_block[2]
                send_block[0] = 0
                # break
            # input()
        print(f"Total input success: {input_success}/{len(f_lines)}")
        print(f"Total output success: {output_success}/{len(f_lines)}")
    

    # ser.close()             # close port

def receive_serial_data(ser: serial.Serial, send_block:list, temp_rx_bin):
    # ser = serial.Serial('/dev/ttyUSB0', 460800)
    print("rx: ", ser.name)         # check which port was really used
    try:
        while True:
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)  # read all available data
                time.sleep(1)
                temp_rx_bin += data

                if len(data) == 0:
                    continue
                # continue
                # 
                if len(temp_rx_bin) > 8:

                    print("rx: ", temp_rx_bin, len(temp_rx_bin))
                    if temp_rx_bin[0] == 171 and temp_rx_bin[-2] == 171 and temp_rx_bin[1] == 205 and temp_rx_bin[-1] == 205:
                        print(f"Header success, cmd = {temp_rx_bin[2]:02x}, data_len = {temp_rx_bin[3]}")
                        
                        if temp_rx_bin[2]:
                            str_rx_data = ' '.join([f'{msb:08b}{lsb:08b}' for (lsb, msb) in zip(temp_rx_bin[4:-3:2], temp_rx_bin[5:-3:2])]+[f'{temp_rx_bin[-3]:08b}'])
                            # else:

                            print('Bin rx = ', str_rx_data)
                            data_match = str_rx_data==send_block[1]
                            send_block[2] = data_match
                            print("Data match: ", data_match)
                        else:
                            str_rx_data = ' '.join([f'{msb:08b}{lsb:08b}' for (lsb, msb) in zip(temp_rx_bin[4:-3:2], temp_rx_bin[5:-3:2])]+[f'{temp_rx_bin[-3]:08b}'])
                            # else:

                            print('Bin rx = ', str_rx_data)
                            output_data = str_rx_data.split(' ')[0]
                            
                            int_expected_output = int(send_block[1], 2)
                            int_output = int(output_data, 2)

                            data_match = False
                            if int_expected_output == int_output:
                                print("Match 100%")
                                data_match = True
                            elif (int_expected_output == int_output + 1) or (int_expected_output == int_output - 1):
                                print("Match 99%")
                                data_match = True
                            
                            send_block[2] = data_match
                            # print("Data match: ", output_data==send_block[1])
                        send_block[0] = 1
                    else:
                        print("Header failed")
                        send_block[0] = 2
                    temp_rx_bin = b''
                
    except KeyboardInterrupt:
        ser.close()             # close port
        # pass

# Create a thread to send serial data
t1 = threading.Thread(target=send_serial_data, args=(ser, send_block))
# Create a thread to receive serial data
t2 = threading.Thread(target=receive_serial_data, args=(ser, send_block, temp_rx_bin))

t1.start()
t2.start()
t1.join()
t2.join()