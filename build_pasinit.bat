@echo off
rem
rem   Set up for building a Pascal module.
rem
call build_vars

call src_get %srcdir% %libname%.ins.pas
call src_get %srcdir% %libname%_2.ins.pas

call src_getbase
call src_getfrom stuff stuff.ins.pas
call src_getfrom picprg picprg picprg.ins.pas
call src_getfrom utest utest.ins.pas

make_debug debug_switches.ins.pas
call src_builddate "%srcdir%"

call src_get_ins_aspic pic cmdrsp
call src_go %srcdir%
call src_get %srcdir% %buildname% %fwname%_cmdrsp.ins.aspic
call src_get %srcdir% %buildname% %fwname%_cmdrsp.aspic
prepic %fwname%_cmdrsp.aspic
