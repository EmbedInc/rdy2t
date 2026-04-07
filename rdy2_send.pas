{   Low level sending to the remote unit.
*
*   The output buffer is managed so that there is always room for at least one
*   byte when the lock is not held.  When the buffer is filled, it is sent
*   immediately.  Both these actions are performed with the same lock held.
*   RDY2_SEND8 is the low level routine to add one more byte to the output
*   buffer.
}
module rdy2_send;
define rdy2_send_lock;
define rdy2_send_unlock;
define rdy2_send;
define rdy2_send_empty;
define rdy2_send_wait;
define rdy2_send8;
define rdy2_send16;
define rdy2_send24;
define rdy2_send32;
%include 'rdy2_2.ins.pas';
{
********************************************************************************
*
*   Subroutine RDY2_SEND_LOCK (RDY)
*
*   Acquire the lock on sending to the remote unit.  This routine waits
*   indefinitely until the lock is available.
}
procedure rdy2_send_lock (             {acquire lock on sending to remote unit}
  in out  rdy: rdy2_t);                {library use state}
  val_param;

begin
  sys_thread_lock_enter (rdy.lock_out);
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SEND_UNLOCK (RDY)
*
*   Release the lock on sending to the remote unit.
}
procedure rdy2_send_unlock (           {release lock on sending to remote unit}
  in out  rdy: rdy2_t);                {library use state}
  val_param;

begin
  sys_thread_lock_leave (rdy.lock_out);
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SEND (RDY, STAT)
*
*   Send all buffered data to the remote unit.  The buffer will always be empty
*   when this routine returns.
*
*   The sending lock must be held when this routine is called.
}
procedure rdy2_send (                  {send all buffered data, must hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param;

const
  nmax = 16;                           {max bytes to show per line}

var
  nline: sys_int_machine_t;            {number of bytes shown on current line}
  ii: sys_int_machine_t;               {scratch integer and loop counter}

begin
  nline := 0;                          {init to no bytes shown}

  if rdy.obufn > 0
    then begin                         {there is something to send}
      file_write_embusb (rdy.obuf, rdy.conn, rdy.obufn, stat); {send the data}

      if rdy.show_out then begin       {show output bytes to user ?}
        rdy2_show_lock (rdy);          {acquire lock on writing output to user}
        for ii := 0 to rdy.obufn-1 do begin {once for each output byte}
          if nline = 0 then begin      {need to start a new output line ?}
            write ('-->');
            end;
          write (' ', rdy.obuf[ii]);   {show value of this output byte}
          nline := nline + 1;          {count one more output byte on current line}
          if nline >= nmax then begin  {output line is full ?}
            writeln;
            nline := 0;                {reset to no bytes on current output line}
            end;
          end;                         {back for next output byte}
        if nline > 0 then begin        {partial output line written ?}
          writeln;                     {end the line}
          end;
        rdy2_show_unlock (rdy);        {release lock on writing to user}
        end;

      end
    else begin
      sys_error_none (stat);
      end
    ;
  rdy.obufn := 0;                      {the buffer is now definitely empty}
  end;
{
********************************************************************************
*
*   Function RDY2_SEND_EMPTY (RDY)
*
*   The function returns TRUE iff the output buffer is empty.
}
function rdy2_send_empty (             {check for output buffer empty}
  in out  rdy: rdy2_t)                 {library use state}
  :boolean;                            {no buffered unsent data}
  val_param;

begin
  rdy2_send_empty := rdy.obufn <= 0;
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SEND_WAIT (RDY, STAT)
*
*   Send all buffered data to the remote unit, then wait for all the pending
*   commands to have been completed.  This is done by appending a PING command
*   to the end of the data and waiting for the corresponding PONG response.
*
*   The sending lock must NOT be held when this routine is called.
}
procedure rdy2_send_wait (             {send, wait for all commands done, not hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param;

label
  abort;

begin
  rdy2_send_lock (rdy);                {acquire the sending lock}

  sys_event_reset_bool (rdy.pong);     {reset to PONG response not received}
  rdy.show_pong := false;              {make sure next PONG triggers event}
  rdy2_cmd_ping (rdy, stat);           {append PING command to pending data}
  if sys_error(stat) then goto abort;

  rdy2_send (rdy, stat);               {send all buffered data}
  rdy2_send_unlock (rdy);              {release lock on sending to remote system}

  if sys_event_wait_tout (rdy.pong, rdy2_waitsec, stat) then begin {timeout or error ?}
    if not sys_error(stat) then begin  {no error, wait timed out ?}
      sys_stat_set (rdy2_subsys_k, rdy2_err_noresp_k, stat); {indicate no response}
      end;
    end;
  return;

abort:                                 {error with lock held, STAT indicates error}
  rdy2_send_unlock (rdy);
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SEND8 (RDY, DAT, STAT)
*
*   Send the low 8 bits of DAT to the remote unit.  The data may be buffered and
*   not immediately sent.
*
*   The sending lock must be held when this routine is called.
}
procedure rdy2_send8 (                 {send 8 bits, must hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  in      dat: univ sys_int_conv8_t;   {data in low bits}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}

  rdy.obuf[rdy.obufn] := dat & 16#FF;  {write the byte into the buffer}
  rdy.obufn := rdy.obufn + 1;          {update number of bytes now in buffer}

  if rdy.obufn >= rdy2_obuf_size then begin {buffer is now full ?}
    rdy2_send (rdy, stat);             {send buffer, reset to empty}
    end;
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SEND16 (RDY, DAT, STAT)
*
*   Send the low 16 bits of DAT to the remote unit.  Multiple bytes are sent in
*   most to least significant order.  The data may be buffered and not
*   immediately sent.
*
*   The sending lock must be held when this routine is called.
}
procedure rdy2_send16 (                {send 16 bits, must hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  in      dat: univ sys_int_conv16_t;  {data in low bits}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  rdy2_send8 (rdy, rshft(dat, 8), stat);
  if sys_error(stat) then return;
  rdy2_send8 (rdy, dat, stat);
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SEND24 (RDY, DAT, STAT)
*
*   Send the low 24 bits of DAT to the remote unit.  Multiple bytes are sent in
*   most to least significant order.  The data may be buffered and not
*   immediately sent.
*
*   The sending lock must be held when this routine is called.
}
procedure rdy2_send24 (                {send 24 bits, must hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  in      dat: univ sys_int_conv24_t;  {data in low bits}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  rdy2_send8 (rdy, rshft(dat, 16), stat);
  if sys_error(stat) then return;
  rdy2_send8 (rdy, rshft(dat, 8), stat);
  if sys_error(stat) then return;
  rdy2_send8 (rdy, dat, stat);
  end;
{
********************************************************************************
*
*   Subroutine RDY2_SEND32 (RDY, DAT, STAT)
*
*   Send the low 32 bits of DAT to the remote unit.  Multiple bytes are sent in
*   most to least significant order.  The data may be buffered and not
*   immediately sent.
*
*   The sending lock must be held when this routine is called.
}
procedure rdy2_send32 (                {send 32 bits, must hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  in      dat: univ sys_int_conv32_t;  {data in low bits}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  rdy2_send8 (rdy, rshft(dat, 24), stat);
  if sys_error(stat) then return;
  rdy2_send8 (rdy, rshft(dat, 16), stat);
  if sys_error(stat) then return;
  rdy2_send8 (rdy, rshft(dat, 8), stat);
  if sys_error(stat) then return;
  rdy2_send8 (rdy, dat, stat);
  end;
