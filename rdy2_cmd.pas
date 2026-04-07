{   Low level routines to send commands to the remote unit.  These routines only
*   send the raw command and parameter bytes, which could get buffered and not
*   sent immediately.  The caller must NOT be holding the commands sending lock.
*
*   Each routine is named RDY2_CMD_xxx, where XXX is the name of the command
*   as defined in the firmware and shown in the firmware documentation file.
}
module rdy2_cmd;

define rdy_cmdimpl;
define rdy2_cmd_nop;
define rdy2_cmd_ping;
define rdy2_cmd_fwinfo;
define rdy2_cmd_nameset;
define rdy2_cmd_nameget;
define rdy2_cmd_getcmds;

%include 'rdy2_2.ins.pas';
%include 'rdy2t_cmdrsp.ins.pas';       {command and response opcode definitions}
{
********************************************************************************
*
*   Function RDY_CMDIMPL (RDY, CMD)
*
*   Returns TRUE iff the command with opcode CMD is implemented.
}
function rdy2_cmdimpl (                {check for command implemented}
  in out  rdy: rdy2_t;                 {library use state}
  in      cmd: sys_int_machine_t)      {0-255 command opcode}
  :boolean;                            {the command is implemented in this firmware}
  val_param;

begin
  rdy2_cmdimpl := false;               {init to command not implemented}
  if (cmd < 0) or (cmd > 255) then return; {not a valid command opcode ?}

  rdy2_cmdimpl := rdy.cmd[cmd];        {return implemented status}
  end;
{
********************************************************************************
}
procedure rdy2_cmd_nop (               {send NOP command}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  rdy2_show_lock (rdy);
  rdy2_send8 (rdy, cmd_nop_k, stat);
  rdy2_show_unlock (rdy);
  end;
{
********************************************************************************
}
procedure rdy2_cmd_ping (              {send PING command}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  rdy2_show_lock (rdy);
  rdy2_send8 (rdy, cmd_ping_k, stat);
  rdy2_show_unlock (rdy);
  end;
{
********************************************************************************
}
procedure rdy2_cmd_fwinfo (            {send FWINFO command}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  rdy2_show_lock (rdy);
  rdy2_send8 (rdy, cmd_fwinfo_k, stat);
  rdy2_show_unlock (rdy);
  end;
{
********************************************************************************
}
procedure rdy2_cmd_nameset (           {send NAMESET command}
  in out  rdy: rdy2_t;                 {library use state}
  in      name: univ string_var_arg_t; {string to set device name to}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  nchar: sys_int_machine_t;            {number of name characters to send}
  ind: string_index_t;                 {index into NAME string}

label
  abort;

begin
  nchar := max(0, min(255, name.len)); {number of characters to send}

  rdy2_show_lock (rdy);
  rdy2_send8 (rdy, cmd_nameset_k, stat); {NAMESET command opcode}
  if sys_error(stat) then goto abort;
  rdy2_send8 (rdy, nchar, stat);       {number of name characters}
  if sys_error(stat) then goto abort;
  for ind := 1 to nchar do begin       {once for each name character}
    rdy2_send8 (rdy, ord(name.str[ind]), stat);
    if sys_error(stat) then goto abort;
    end;
abort:                                 {to here on error when lock held}
  rdy2_show_unlock (rdy);
  end;
{
********************************************************************************
}
procedure rdy2_cmd_nameget (           {send NAMEGET command}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  rdy2_show_lock (rdy);
  rdy2_send8 (rdy, cmd_nameget_k, stat);
  rdy2_show_unlock (rdy);
  end;
{
********************************************************************************
}
procedure rdy2_cmd_getcmds (           {send GETCMDS command}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  rdy2_show_lock (rdy);
  rdy2_send8 (rdy, cmd_getcmds_k, stat);
  rdy2_show_unlock (rdy);
  end;
