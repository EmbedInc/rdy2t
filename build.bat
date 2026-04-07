@echo off
rem
rem   Build everything from this source directory.
rem
setlocal
call godir "(cog)source/qprot/rdy2t"

call build_fw
call build_lib
call build_progs
