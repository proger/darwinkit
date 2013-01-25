set logging file /tmp/gdb
set logging on
#set logging overwrite
target darwin-kernel
file /Volumes/KernelDebugKit/mach_kernel
source /tank/proger/dev/darwin/xnu-1699.24.8/kgmacros
source /tank/proger/dev/darwin/xnu-1699.24.8/kgmacros.my
attach
