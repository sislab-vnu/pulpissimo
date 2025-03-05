define n


endef # make errors more visually appealing

export BOARD=arty

#Nexys has different revisions. Check which one to use
ifdef rev

ifeq ($(rev), artyA7-35T)
	export XILINX_PART=xc7a50ticsg324-1L
	export XILINX_BOARD=digilentinc.com:arty-a7-35:1.0
endif
ifeq ($(rev), artyA7-100T)
	export XILINX_PART=xc7a100tcsg324-1
	export XILINX_BOARD=digilentinc.com:arty-a7-100:1.0
endif
#Check if one was found
ifndef XILINX_PART
$(error $n$nCould not find board revision $(rev).$nPossible revisions: artyA7-35T, artyA7-100T.$n$n)
endif

else
$(error $n$nNo Nexys board revision given. Please use 'make arty rev=[artyA7-100T|artyA7-35T]'$n$n)
endif

export FC_CLK_PERIOD_NS=100
export PER_CLK_PERIOD_NS=200
export SLOW_CLK_PERIOD_NS=30517
$(info Setting environment variables for $(BOARD) board)
