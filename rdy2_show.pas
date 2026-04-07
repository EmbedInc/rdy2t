{   Routines related to writing to standard output.
}
module rdy2_show;
define rdy2_show_lock;
define rdy2_show_unlock;
define rdy2_show_start;
define rdy2_show_end;
define rdy2_show_eol_end;
define rdy2_show_atstart;
define rdy2_show_nstart;
define rdy2_show_in;
define rdy2_show_out;
define rdy2_show_resp;
define rdy2_show_nop;
define rdy2_show_vstr;
define rdy2_show_str;
define rdy2_show_eol;
%include 'rdy2_2.ins.pas';
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_LOCK (RDY)
*
*   Acquire the lock for writing text to the user.
}
procedure rdy2_show_lock (             {acquire lock on writing to user}
  in out  rdy: rdy2_t);                {library use state}
  val_param;

begin
  sys_thread_lock_enter (rdy.show_lock);
  rdy2_show_start (rdy);               {make sure at start of a line}
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_UNLOCK (RDY)
*
*   Release the lock for writing text to the user.
}
procedure rdy2_show_unlock (           {release lock on writing to user}
  in out  rdy: rdy2_t);                {library use state}
  val_param;

begin
  sys_thread_lock_leave (rdy.show_lock);
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_START (RDY)
*
*   Make sure the writing position of output to the user is at the start of a
*   line.  Nothing is done if the writing position is already known to be at the
*   start of a line.
}
procedure rdy2_show_start (            {to start of next line if not already at start}
  in out  rdy: rdy2_t);                {library use state}
  val_param;

begin
  if not rdy.stline then begin         {not at start of line ?}
    writeln;                           {to start of next line}
    rdy.stline := true;                {now definitely at start of line}
    end;
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_END (RDY)
*
*   End the current output line, then release the lock on writing to the user.
*   Nothing is written when the writing position is already at the start of a
*   line.
}
procedure rdy2_show_end (              {end output line to user, release lock}
  in out  rdy: rdy2_t);                {library use state}
  val_param;

begin
  rdy2_show_start (rdy);               {leave position at start of line}
  rdy2_show_unlock (rdy);              {release lock on writing to the user}
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_EOL_END (RDY)
*
*   Unconditionally go to the start of the next output line, then release the
*   lock on writing to the user.
}
procedure rdy2_show_eol_end (          {write newline, release lock on user output}
  in out  rdy: rdy2_t);                {library use state}
  val_param;

begin
  rdy2_show_eol (rdy);                 {to start of next line}
  rdy2_show_unlock (rdy);              {release lock on writing to the user}
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_ATSTART (RDY)
*
*   Indicate that the current user output writing position is at the start of a
*   line.
}
procedure rdy2_show_atstart (          {indicate at start of output line to user}
  in out  rdy: rdy2_t);                {library use state}
  val_param;

begin
  rdy.stline := true;
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_NSTART (RDY)
*
*   Indicate that the current user output writing position is not at the start
*   of a line.
}
procedure rdy2_show_nstart (           {indicate output line to user it not at start}
  in out  rdy: rdy2_t);                {library use state}
  val_param;

begin
  rdy.stline := false;
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_IN (RDY, ON)
*
*   Enable or disable showing the raw bytes received from the remote unit.  This
*   is off by default.
}
procedure rdy2_show_in (               {enable/disable showing raw input bytes}
  in out  rdy: rdy2_t;                 {library use state}
  in      on: boolean);                {enable showing input bytes}
  val_param;

begin
  rdy.show_in := on;
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_OUT (RDY, ON)
*
*   Enable or disable showing the raw bytes sent to the remote unit.  This is
*   off by default.
}
procedure rdy2_show_out (              {enable/disable showing raw output bytes}
  in out  rdy: rdy2_t;                 {library use state}
  in      on: boolean);                {enable showing output bytes}
  val_param;

begin
  rdy.show_out := on;
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_RESP (RDY, ON)
*
*   Enable or disable showing interpreted complete responses received from the
*   remote unit, other than NOP responses.  This is off by default.
}
procedure rdy2_show_resp (             {enable/disable showing responses}
  in out  rdy: rdy2_t;                 {library use state}
  in      on: boolean);                {enable showing responses from remote system}
  val_param;

begin
  rdy.show_rsp := on;
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_NOP (RDY, ON)
*
*   Enable or disable showing NOP responses received from the remote unit.  This
*   is off by default.
}
procedure rdy2_show_nop (              {enable/disable showing NOP responses}
  in out  rdy: rdy2_t;                 {library use state}
  in      on: boolean);                {enable showing output bytes}
  val_param;

begin
  rdy.show_nop := on;
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_VSTR (RDY, VSTR)
*
*   Write the string VSTR to standard output.  The output is left at the end of
*   the string.  The output line is not ended.
}
procedure rdy2_show_vstr (             {show varstring to user}
  in out  rdy: rdy2_t;                 {library use state}
  in      vstr: univ string_var_arg_t); {string to write}
  val_param;

begin
  if vstr.len > 0 then begin           {there is something to write ?}
    write (vstr.str:vstr.len);         {write the string}
    rdy.stline := false;               {now definitely not at start of line}
    end;
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_STR (RDY, STR)
*
*   Same as RDY2S_SHOW_VSTR except that the string is a Pascal string, not an
*   Embed vstring.
}
procedure rdy2_show_str (              {show Pascal string to user}
  in out  rdy: rdy2_t;                 {library use state}
  in      str: string);                {string to write}
  val_param;

var
  vstr: string_var80_t;                {the string in varstring format}

begin
  vstr.max := size_char(vstr.str);     {init local var string}

  string_vstring (vstr, str, size_char(str)); {make var string version}
  rdy2_show_vstr (rdy, vstr);          {write the string}
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SHOW_EOL (RDY)
*
*   End the current output line to the user.  An end of line is written.  The
*   writing position is left at the start of the next line.
}
procedure rdy2_show_eol (              {end the current output line to the user}
  in out  rdy: rdy2_t);                {library use state}
  val_param;

begin
  writeln;                             {to start of next line}
  rdy.stline := true;                  {now definitely at start of line}
  end;
