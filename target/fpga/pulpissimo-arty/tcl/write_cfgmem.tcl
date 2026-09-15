if {$argc != 4} {
    error "Usage: write_cfgmem.tcl BITSTREAM APPLICATION OUTPUT APPLICATION_OFFSET"
}

set bitstream [file normalize [lindex $argv 0]]
set application [file normalize [lindex $argv 1]]
set output [file normalize [lindex $argv 2]]
set application_offset [expr [lindex $argv 3]]
set flash_size_bytes 0x01000000

if {![file exists $bitstream]} {
    error "Bitstream does not exist: $bitstream"
}
if {![file exists $application]} {
    error "Application image does not exist: $application"
}
if {[file size $bitstream] > $application_offset} {
    error "Bitstream overlaps application offset 0x[format %08x $application_offset]"
}
if {[file size $application] > $flash_size_bytes - $application_offset} {
    error "Application image exceeds the remaining onboard flash capacity"
}

file mkdir [file dirname $output]
write_cfgmem -force -format mcs -interface SPIx4 -size 16 \
    -loadbit "up 0x00000000 $bitstream" \
    -loaddata "up 0x[format %08x $application_offset] $application" \
    $output

puts "Created $output"
puts "  FPGA bitstream: 0x00000000 ([file size $bitstream] bytes)"
puts "  Application:     0x[format %08x $application_offset] ([file size $application] bytes)"
