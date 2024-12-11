.LIB sm046005-1j.hspice typical
.OPTION POST
.PARAM WN=1u LN=0.35u WP=2u LP=0.35u


.GLOBAL VDD GND
VDD VDD GND 3.3

.SUBCKT XOR in1 in2 out
.LIB sm046005-1j.hspice typical
XINV_1 GND in1 in1_n INV
XINV_2 GND in2 in2_n INV
Mp1 buf1 in1 VDD VDD PMOS_3P3 L=LP W=2*WP
Mp2 out in2_n buf1 buf1 PMOS_3P3 L=LP W=2*WP
Mp3 buf2 in1_n VDD VDD PMOS_3P3 L=LP W=2*WP
Mp4 out in2 buf2 buf2 PMOS_3P3 L=LP W=2*WP
Mn1 out in1 buf3 buf3 NMOS_3P3 L=LN W=2*WN
Mn2 out in2_n buf3 buf3 NMOS_3P3 L=LN W=2*WN
Mn3 buf3 in1_n GND GND NMOS_3P3 L=LN W=2*WN
Mn4 buf3 in2 GND GND NMOS_3P3 L=LN W=2*WN
.ENDS XOR

.SUBCKT AND in1 in2 out
.LIB sm046005-1j.hspice typical
Mp1 out_buf in1 VDD VDD PMOS_3P3 L=LP W=WP
Mp2 out_buf in2 VDD VDD PMOS_3P3 L=LP W=WP
Mn1 out_buf in1 buf buf NMOS_3P3 L=LN W=2*WN
Mn2 buf in2 GND GND NMOS_3P3 L=LN W=2*WN
XINV GND out_buf out INV
.ENDS AND

.SUBCKT OR in1 in2 out
.LIB sm046005-1j.hspice typical
Mp1 buf in1 VDD VDD PMOS_3P3 L=LP W=2*WP
Mp2 out_buf in2 buf buf PMOS_3P3 L=LP W=2*WP
Mn1 out_buf in1 GND GND NMOS_3P3 L=LN W=WN
Mn2 out_buf in2 GND GND NMOS_3P3 L=LN W=WN
XINV GND out_buf out INV
.ENDS OR

.SUBCKT INV nc in out
.LIB sm046005-1j.hspice typical
Mp out in VDD VDD PMOS_3P3 L=LP W=WP
Mn out in GND GND NMOS_3P3 L=LN W=WN
.ENDS INV

.SUBCKT hadd a b s c
.LIB sm046005-1j.hspice typical
Mp1 buf1 a VDD VDD PMOS_3P3 L=LP W=2*WP
Mp2 out_buf b buf1 buf1 PMOS_3P3 L=LP W=2*WP
Mn1 out_buf a GND GND NMOS_3P3 L=LN W=WN
Mn2 out_buf b GND GND NMOS_3P3 L=LN W=WN
XAND a b c AND
Mp3 buf out_buf VDD VDD PMOS_3P3 L=LP W=2*WP
Mp4 s c buf buf PMOS_3P3 L=LP W=2*WP
Mn3 s out_buf GND GND NMOS_3P3 L=LN W=WN
Mn4 s c GND GND NMOS_3P3 L=LN W=WN
.ENDS hadd

.SUBCKT top_module a_0 b_0 a_1 b_1 a_2 b_2 a_3 b_3 cin sum_0 sum_1 sum_2 sum_3 cout
.LIB sm046005-1j.hspice typical
Rshort_cout cout carry_out_3 0
Rshort_carry_in_0 carry_in_0 cin 0
Rshort_carry_in_1 carry_in_1 carry_out_0 0
Rshort_carry_in_2 carry_in_2 carry_out_1 0
Rshort_carry_in_3 carry_in_3 carry_out_2 0
Xadd_01000 a_0 b_0 carry_in_0 sum_0 carry_out_0 add1
Xadd_11001 a_1 b_1 carry_in_1 sum_1 carry_out_1 add1
Xadd_21002 a_2 b_2 carry_in_2 sum_2 carry_out_2 add1
Xadd_31003 a_3 b_3 carry_in_3 sum_3 carry_out_3 add1
.ENDS top_module

.SUBCKT add1 a b cin sum cout
.LIB sm046005-1j.hspice typical
XOR1004 c1 c2 cout OR
Xhadd11005 a b s c1 hadd
Xhadd21006 s cin sum c2 hadd
.ENDS add1



X_TOP a_0 b_0 a_1 b_1 a_2 b_2 a_3 b_3 cin sum_0 sum_1 sum_2 sum_3 cout top_module
C_sum_0 sum_0 GND 1pF
C_sum_1 sum_1 GND 1pF
C_sum_2 sum_2 GND 1pF
C_sum_3 sum_3 GND 1pF
C_cout cout GND 1pF


V_a_0 a_0 GND PULSE(0V 3.3V 5us 0us 0us 5us 10us)
V_b_0 b_0 GND PULSE(0V 3.3V 10us 0us 0us 10us 20us)
V_a_1 a_1 GND PULSE(0V 3.3V 20us 0us 0us 20us 40us)
V_b_1 b_1 GND PULSE(0V 3.3V 40us 0us 0us 40us 80us)
V_a_2 a_2 GND PULSE(0V 3.3V 80us 0us 0us 80us 160us)
V_b_2 b_2 GND PULSE(0V 3.3V 160us 0us 0us 160us 320us)
V_a_3 a_3 GND PULSE(0V 3.3V 320us 0us 0us 320us 640us)
V_b_3 b_3 GND PULSE(0V 3.3V 640us 0us 0us 640us 1280us)
V_cin cin GND PULSE(0V 3.3V 1280us 0us 0us 1280us 2560us)


.TRAN 0.01us 2560us

.END
