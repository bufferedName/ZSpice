.SUBCKT AND in1 in2 out
Mp1 out_buf in1 VDD VDD PMOS_3P3 L=LP W=WP
Mp2 out_buf in2 VDD VDD PMOS_3P3 L=LP W=WP
Mn1 out_buf in1 buf buf NMOS_3P3 L=LN W=2*WN
Mn2 buf in2 GND GND NMOS_3P3 L=LN W=2*WN
XINV GND out_buf out INV
.ENDS AND