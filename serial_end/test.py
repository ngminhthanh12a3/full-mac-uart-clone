import serial, threading, time
from serial.threaded import ReaderThread, Protocol

ser = serial.Serial('/dev/ttyUSB1', 460800)
def send_serial_data(ser: serial.Serial):
    print("tx: ", ser.name)         # check which port was really used
    while True:
        ser.write(b'\xab\xcd\x00\x00\xab\xcd')
        input("Press Enter to send data...")  # Wait for user input before sending the next batch of data
        # for data_i in b'\xab\xcd\x00\x00\xab\xcd':
        # # for data_i in b'\xab\xcd':
        #     ser.write(bytes([data_i]))     # write hexadecimal data
        #     time.sleep(1)              # wait a bit before sending the next byte
    # ser.write(b'\xab')
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

# t1.start()
t2.start()
# t1.join()
t2.join()