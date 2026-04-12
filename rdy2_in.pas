{   Thread that receives all input from the remote unit.
}
module rdy2_in;
define rdy2_in;
%include 'rdy2_2.ins.pas';
%include 'rdy2t_cmdrsp.ins.pas';       {define command and response opcodes}

const
  chunksize = 64;                      {max bytes to read from remote unit at a time}
{
********************************************************************************
*
*   Subroutine RDY2_IN (RDY)
*
*   Top routine of the thread that receives and processes all input from the
*   remote unit.  This thread automatically stops when RDY.QUIT is true.
}
procedure rdy2_in (                    {thread that receives all input from remote unit}
  var     rdy: rdy2_t);                {RDY2 lib use state passed by reference}
  val_param;

const
  datar_size = 256;                    {number of entries DATAR configured for}

  chunklast = chunksize - 1;           {last valid input buffer index}
  datar_last = datar_size - 1;         {last valid DATAR index}

var
  ibuf:                                {raw input buffer}
    array[0..chunklast] of int8u_t;
  ibufi: sys_int_machine_t;            {index of next byte to read from IBUF}
  ibufn: sys_int_adr_t;                {number of bytes left to read from IBUF}
  nnop: sys_int_machine_t;             {number of consecutive NOPs received}
  ii, jj, kk: sys_int_machine_t;       {scratch integers and loop counters}
  i1, i2, i3: sys_int_conv32_t;        {response parameters}
  tk: string_var80_t;                  {scratch token}
  tk2: string_var32_t;
  rsp: sys_int_machine_t;              {response opcode}
  datar:                               {scratch array for processing responses}
    array[0..datar_last] of sys_int_machine_t;
  datarn: sys_int_machine_t;           {number of entries in DATAR}
  call_p: rdy2_fwinfo_call_p_t;        {to FWINFO response callback routine}

label
  loop;
{
****************************************
*
*   Function IBYTE
*   This function is local to RDY2_IN.
*
*   Return the next byte from the remote unit.
}
function ibyte                         {return next byte from remote system}
  :sys_int_machine_t;                  {0-255 byte value}
  val_param;

var
  stat: sys_err_t;                     {completion status}

begin
  if rdy.quit then begin               {trying to exit the program ?}
    sys_thread_exit;
    end;

  while ibufn <= 0 do begin            {keep reading until buffer is non-empty}
    file_read_embusb (                 {read another chunk from the USB}
      rdy.conn,                        {connection to the USB}
      chunksize,                       {max number of bytes to read}
      ibuf,                            {returned data}
      ibufn,                           {number of bytes actually read}
      stat);
    if rdy.quit then begin             {trying to exit the program ?}
      sys_thread_exit;
      end;
    sys_error_abort (stat, '', '', nil, 0);
    ibufi := 0;                        {reset to fetch from start of buffer}
    end;

  if rdy.show_in then begin
    rdy2_show_lock (rdy);
    writeln ('<-- ', ibuf[ibufi]);
    rdy2_show_unlock (rdy);
    end;

  ibyte := ibuf[ibufi];                {get the data byte to return}
  ibufi := ibufi + 1;                  {advance buffer index for next time}
  ibufn := ibufn - 1;                  {count one less byte left in the buffer}
  end;
{
****************************************
*
*   Function GETI16U
*   This function is local to RDY2_IN.
*
*   Returns the next two input bytes interpreted as a unsigned 16 bit integer.
}
(*
function geti16u                       {get next 2 bytes as unsigned integer}
  :sys_int_machine_t;

var
  ii: sys_int_machine_t;

begin
  ii := lshft(ibyte, 8);               {get the high byte}
  ii := ii ! ibyte;                    {get the low byte}
  geti16u := ii;
  end;
*)
{
****************************************
*
*   Function GETI24U
*   This function is local to RDY2_IN.
*
*   Returns the next three input bytes interpreted as a unsigned 24 bit integer.
}
(*
function geti24u                       {get next 3 bytes as unsigned integer}
  :sys_int_machine_t;

var
  ii: sys_int_machine_t;

begin
  ii := lshft(ibyte, 16);              {get the high byte}
  ii := ii ! lshft(ibyte, 8);
  ii := ii ! ibyte;                    {get the low byte}
  geti24u := ii;
  end;
*)
{
****************************************
*
*   Subroutine DATAR_ADD (V)
*
*   Add the value V as the next word in the scratch data array DATAR.  DATARN is
*   updated to indicate the number of entries in DATAR.  Nothing is done if the
*   array is already full.
}
procedure datar_add (                  {add value to DATAR array}
  in      v: sys_int_machine_t);       {the value to add}
  val_param; internal;

begin
  if datarn < datar_size then begin    {array isn't already full ?}
    datar[datarn] := v;                {stuff this value into the array}
    datarn := datarn + 1;              {count one more value in the array}
    end;
  end;
{
****************************************
*
*   Executable code for RDY2_IN.
}
begin
  tk.max := size_char(tk.str);         {init local var strings}
  tk2.max := size_char(tk2.str);
  ibufn := 0;                          {init the input buffer to empty}
  nnop := 0;                           {init number of consecutive NOPs received}

loop:                                  {back here to process each new response}
  rsp := ibyte;                        {get new response opcode}
  if rsp <> rsp_nop_k then begin       {this is not a NOP response ?}
    nnop := 0;                         {reset number of consecutive NOPs received}
    end;
  datarn := 0;                         {initialize DATAR to empty for this response}
  case rsp of                          {which response is it ?}
{
******************************
*
*   NOP
}
rsp_nop_k: begin
  nnop := nnop + 1;                    {count one more consecutive NOP}
  if rdy.show_nop then begin
    rdy2_show_lock (rdy);
    writeln ('NOP ', nnop);
    rdy2_show_unlock (rdy);
    end;
  end;
{
******************************
*
*   PONG
}
rsp_pong_k: begin
  if rdy.show_pong
    then begin                         {just show the response to the user}
      rdy2_show_lock (rdy);
      writeln ('PONG');
      rdy2_show_unlock (rdy);
      end
    else begin                         {don't show response, signal PONG event instead}
      sys_event_notify_bool (rdy.pong);
      end
    ;
  rdy.show_pong := rdy.show_rsp;       {reset to show next PONG according to SHOW_RSP}
  end;
{
******************************
*
*   FWINFO type version sequence
}
rsp_fwinfo_k: begin
  i1 := ibyte;                         {TYPE}
  i2 := ibyte;                         {VERSION}
  i3 := ibyte;                         {SEQUENCE}

  case i1 of                           {which firmware is it ?}
rdy2t_fwtype: begin
      rdy.fw_rdy2t.typ := i1;
      rdy.fw_rdy2t.ver := i2;
      rdy.fw_rdy2t.seq := i3;
      end;
    end;

  if rdy.show_rsp then begin
    rdy2_show_lock (rdy);
    write ('Firmware ');
    case i1 of
rdy2t_fwtype: write ('RDY2T');
otherwise
      write ('type ', i1);
      end;
    writeln (' ver ', i2, ' seq ', i3);
    rdy2_show_unlock (rdy);
    end;

  if rdy.fwinfo_call_p <> nil then begin {callback routine set ?}
    call_p := rdy.fwinfo_call_p;       {get pointer to callback routine}
    call_p^ (rdy, rdy.fwinfo_app);     {call the callback routine}
    end;
  end;
{
******************************
*
*   NAME n name
}
rsp_name_k: begin
  i1 := ibyte;                         {number of characters in the name}
  tk.len := 0;                         {init the name string to empty}
  for ii := 1 to i1 do begin           {once for each name string character}
    string_append1 (tk, chr(ibyte));   {add this character to end of name string}
    end;

  string_copy (tk, rdy.name);          {update the name of the unit connected via USB}

  if rdy.show_rsp then begin
    rdy2_show_lock (rdy);
    writeln ('NAME "', rdy.name.str:rdy.name.len, '"');
    rdy2_show_unlock (rdy);
    end;
  end;
{
******************************
*
*   CMDS dat0 ... dat31
}
rsp_cmds_k: begin
  ii := 0;                             {init opcode for next input bit}
  for jj := 0 to 31 do begin           {once for each data byte}
    i1 := ibyte;                       {get this data byte}
    for kk := 1 to 8 do begin          {once for each bit in this byte}
      rdy.cmd[ii] := (i1 & 1) <> 0;    {set implemented status from this bit}
      ii := ii + 1;                    {advance to next opcode}
      i1 := rshft(i1, 1);              {move next input bit into position}
      end;                             {back for next input bit in this byte}
    end;                               {back for next input byte}

  if rdy.show_rsp then begin
    rdy2_show_lock (rdy);
    writeln ('Implemented commands:');
    for ii := 0 to 255 do begin
      if rdy.cmd[ii] then begin
        rdy2_name_cmd (rdy, ii, tk);   {get command name}
        writeln (ii:5, '  ', tk.str:tk.len);
        end;
      end;
    rdy2_show_unlock (rdy);
    end;
  end;
{
******************************
*
*   BITSAM n run ... run
}
rsp_bitsam_k: begin
  i1 := ibyte + 1;                     {get number of runs}

  for ii := 1 to i1 do begin           {get all the runs into DATAR}
    datar_add (ibyte);
    end;

  jj := string_fifo_nempty (rdy.bitsam.fifo_p^); {get room in FIFO}
  jj := min(datarn, jj);               {number of runs can write to FIFO now}
  for ii := 1 to jj do begin           {once for each run to write to the FIFO}
    string_fifo_put (                  {write this run to the FIFO}
      rdy.bitsam.fifo_p^,              {the FIFO}
      datar[ii - 1]);                  {the data byte to write}
    end;                               {back to write next run to the FIFO}

  if rdy.show_rsp then begin
    rdy2_show_lock (rdy);
    write ('Bit samples:');
    for ii := 0 to datarn-1 do begin   {once for each run}
      jj := datar[ii];                 {get descriptor for this run}
      i1 := rshft(jj, 7);              {get 0/1 run value}
      i2 := (jj & 16#7F) + 1;          {get length of this run}
      write (' ', i2, 'x', i1);        {show this run}
      end;
    writeln;
    rdy2_show_unlock (rdy);
    end;
  end;
{
******************************
*
*   Unrecognized opcode.
}
otherwise
    if rdy.show_rsp then begin
      rdy2_show_lock (rdy);
      writeln ('Unrecognized response opcode ', rsp);
      rdy2_show_unlock (rdy);
      end;
    end;                               {end of response opcode cases}
  goto loop;                           {back to get next response}
  end;
