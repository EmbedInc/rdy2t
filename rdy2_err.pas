{   Common error and error status handling.
}
module rdy2_err;
define rdy2_err_cmdnimpl;
%include 'rdy2_2.ins.pas';
{
********************************************************************************
*
*   Function RDY2_ERR_CMDNIMPL (RDY, NAME, OPC, STAT)
*
*   Set STAT according to whether the command with opcode OPC is implemented in
*   this firmware.
*
*   When not implemented, STAT is set to the unimplemented command status code
*   and the function returns TRUE.  In that case, NAME is used as the command
*   name in the error message.
*
*   When the command is implemented, STAT is set to no error and the function
*   returns FALSE.
}
function rdy2_err_cmdnimpl (           {set error status iff command unimplemented}
  in out  rdy: rdy2_t;                 {library use state}
  in      name: string;                {command name}
  in      opc: sys_int_machine_t;      {0-255 command opcode}
  out     stat: sys_err_t)             {set to unimplemented command or no error}
  :boolean;                            {the command is unimplemented}
  val_param;

begin
  if rdy2_cmdimpl (rdy, opc)
    then begin                         {the command is implemented}
      sys_error_none (stat);           {no error}
      rdy2_err_cmdnimpl := false;
      end
    else begin                         {the command is unimplemented}
      sys_stat_set (rdy2_subsys_k, rdy2_cmd_nimpl_k, stat); {init error status}
      sys_stat_parm_str (name, stat);  {add command name}
      sys_stat_parm_int (opc, stat);   {add command opcode}
      rdy2_err_cmdnimpl := true;       {indicate unimplemented}
      end
    ;
  end;
