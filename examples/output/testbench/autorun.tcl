quit -sim
vlib work
vlog adders.v top.v testbench.v
vsim work.test_top -voptargs="+acc"
view wave
delete wave *
add wave sim:/test_top/*
radix -hex
run -all
