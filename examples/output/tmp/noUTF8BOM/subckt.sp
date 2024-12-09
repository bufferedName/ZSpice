*subckt.sp
.SUBCKT hadd a b s c
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