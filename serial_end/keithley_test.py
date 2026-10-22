import pyvisa

rm = pyvisa.ResourceManager("@py")

address = "TCPIP0::172.21.162.155::5025::SOCKET"
psu = rm.open_resource(address)

psu.timeout = 10000
psu.write_termination = "\n"
psu.read_termination = "\n"

print("Connected to:", psu.query("*IDN?").strip())

print("Output enabled:", psu.query(":OUTP?").strip())
print("Voltage setpoint:", psu.query(":VOLT?").strip())
print("Current limit:", psu.query(":CURR?").strip())

psu.close()
rm.close()