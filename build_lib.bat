@echo off
rem
rem   BUILD_LIB
rem
rem   Build the RDY2T library.
rem
setlocal
call build_pasinit

call src_insall %srcdir% %libname%

call src_pas %srcdir% %libname%_bitsam
call src_pas %srcdir% %libname%_cmd
call src_pas %srcdir% %libname%_err
call src_pas %srcdir% %libname%_in
call src_pas %srcdir% %libname%_lib
call src_pas %srcdir% %libname%_name
call src_pas %srcdir% %libname%_send
call src_pas %srcdir% %libname%_show

call src_lib %srcdir% %libname%
call src_msg %srcdir% %libname%
