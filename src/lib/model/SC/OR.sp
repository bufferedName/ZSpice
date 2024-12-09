.SUBCKT OR in1 in2 out
Mp1 buf in1 VDD VDD PMOS_3P3 L=LP W=2*WP
Mp2 out_buf in2 buf buf PMOS_3P3 L=LP W=2*WP
Mn1 out_buf in1 GND GND NMOS_3P3 L=LN W=WN
Mn2 out_buf in2 GND GND NMOS_3P3 L=LN W=WN
XINV GND out_buf out INV
.ENDS OR