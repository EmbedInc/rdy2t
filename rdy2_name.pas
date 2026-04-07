{   Routines related to command and response names.
}
module rdy2_name;
define rdy2_name_cmd;
define rdy2_name_rsp;
%include 'rdy2_2.ins.pas';
{
********************************************************************************
*
*   Subroutine RDY2_NAME_CMD (RDY, OPC, NAME)
*
*   Get the name of a command from its opcode.  OPC is the 0-255 command opcode.
*   NAME is returned the upper case command name.  NAME is returned the empty
*   string when OPC is out of range or no such command is defined.
}
procedure rdy2_name_cmd (              {get command name from opcode}
  in out  rdy: rdy2_t;                 {library use state}
  in      opc: sys_int_machine_t;      {0-255 command opcode}
  in out  name: univ string_var_arg_t); {returned cmd name, empty on undefined}
  val_param;

begin
%include 'rdy2t_cmdnames.ins.pas';
  end;
{
********************************************************************************
*
*   Subroutine RDY2_NAME_RSP (RDY, OPC, NAME)
*
*   Get the name of a response from its opcode.  OPC is the 0-255 response
*   opcode.  NAME is returned the upper case response name.  NAME is returned
*   the empty string when OPC is out of range or no such response is defined.
}
procedure rdy2_name_rsp (              {get response name from opcode}
  in out  rdy: rdy2_t;                 {library use state}
  in      opc: sys_int_machine_t;      {0-255 response opcode}
  in out  name: univ string_var_arg_t); {returned rsp name, empty on undefined}
  val_param;

begin
%include 'rdy2t_rspnames.ins.pas';
  end;
