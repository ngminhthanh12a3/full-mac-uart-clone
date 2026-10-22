import serial, threading, time
from serial.threaded import ReaderThread, Protocol
import numpy as np

ser = serial.Serial('/dev/ttyUSB1', 460800)

f16_info = np.finfo(np.float16)
print("float16 info:")
print("  Min:", f16_info.min)
print("  Max:", f16_info.max)
print("  Precision:", f16_info.precision)

def send_serial_data(ser: serial.Serial):
    print("tx: ", ser.name)         # check which port was really used
    # rng = np.random.default_rng()
    # random_f16 = rng.random(3, dtype=np.float32)  # Generate 48 random float16 numbers
    # # print("Random float16 data:", random_f16)
    # print("Random float16 data:", random_f16, random_f16.astype(np.float16))
    # random_f16 = random_f16 * (f16_info.max) - (f16_info.max/2)  # Scale to fit within the range of float16
    # # random_f16 = random_f16.astype(np.float16)  # Convert to float16
    # print("Random float16 data (scaled):", random_f16, random_f16.astype(np.float16))

    # # random_f16.astype(np.byte)
    # print(random_f16[0].tobytes(), len(random_f16.tobytes()))
    # print("Random float16 data (scaled):", random_f16, random_f16.astype(np.float16))
    
    # print('HEX form: ', bin(np.float16(random_f16[0]).view("H")))
    # for data_i in b'\xab\xcd\x00\x01\x12\xab\xcd':
    # # for data_i in b'\xab\xcd':
    #     ser.write(bytes([data_i]))     # write hexadecimal data
    #     time.sleep(1)              # wait a bit before sending the next byte
    # ser.write(b'\xab')

    with open('mac_fp16_golden_pattern.txt', 'r') as f:
        for line in f:
            byte_str_arr = line.split('_')
            byte_str_arr[-1].replace('\n', '')
            print(byte_str_arr, len(byte_str_arr))
            #
            # test
            test_byte = int(byte_str_arr[0], 2).to_bytes(2, byteorder='big')
            print(test_byte, int.from_bytes(test_byte, byteorder='big'))
            # ser.write()
            byte_arr = [int(byte_str, 2).to_bytes((len(byte_str) + 7) // 8, byteorder='big') for byte_str in byte_str_arr]
            byte_arr = b''.join(byte_arr)#.join(b'\xab\xcd')
            byte_arr = b'\xab\xcd\x00\x09' + byte_arr + b'\xab\xcd'

            ser.write(byte_arr)
            # for byte in byte_arr:
            #     print(byte, len(byte))
            break
            # data_i = int(line.strip(), 16)  # Convert hex string to integer
            # ser.write(bytes([data_i]))     # write hexadecimal data
            # time.sleep(1)              # wait a bit before sending the next byte

    # ser.close()             # close port

def receive_serial_data(ser: serial.Serial):
    # ser = serial.Serial('/dev/ttyUSB0', 460800)
    print("rx: ", ser.name)         # check which port was really used
    try:
        while True:
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)  # read all available data
                print("rx: ", data)
    except KeyboardInterrupt:
        ser.close()             # close port
        # pass

# Create a thread to send serial data
t1 = threading.Thread(target=send_serial_data, args=(ser,))
# Create a thread to receive serial data
t2 = threading.Thread(target=receive_serial_data, args=(ser,))

t1.start()
t2.start()
t1.join()
t2.join()