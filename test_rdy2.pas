{   Program TEST_RDY2 [options]
*
*   This program provides a command line interface for the binary protocol of
*   the RDY2 firmware.
}
program test_rdy2;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'stuff.ins.pas';
%include 'picprg.ins.pas';
%include 'utest.ins.pas';
%include 'rdy2.ins.pas';
%include 'builddate.ins.pas';
%include 'rdy2t_cmdrsp.ins.pas';

const
  datar_size = 256;                    {number of entries in DATAR}
  n_cmdnames_k = 10;                   {number of command names in the list}
  cmdname_maxchars_k = 7;              {max chars in any command name}
  max_msg_parms = 2;                   {max parameters we can pass to a message}
  fwname = 'rdy2t';                    {firmware name, for making map file name}
  mapdir = '(cog)src/qprot';           {directory to look for firmware map files in}
{
*   Derived constants.
}
  datar_last = datar_size - 1;         {last valid DATAR index}
  cmdname_len_k = cmdname_maxchars_k + 1; {number of chars to reserve per cmd name}

type
  cmdname_t =                          {one command name in the list}
    array[1..cmdname_len_k] of char;
  cmdnames_t =                         {list of all the command names}
    array[1..n_cmdnames_k] of cmdname_t;

var
  cmdnames: cmdnames_t := [            {list of all the command names}
    'HELP   ',                         {1}
    '?      ',                         {2}
    'QUIT   ',                         {3}
    'Q      ',                         {4}
    'PING   ',                         {5}
    'FWINFO ',                         {6}
    'SHOW   ',                         {7}
    'NAME   ',                         {8}
    'IMPL   ',                         {9}
    'BSAM   ',                         {10}
    ];

var
  rdy_p: rdy2_p_t;                     {to RDY2 library use state}
  rdyopen: rdy2_open_t;                {set of options for opening RDY2 lib}
  prompt:                              {prompt string for entering command}
    %include '(cog)lib/string4.ins.pas';
  pst: string_index_t;                 {scratch command parse index}
  datar:                               {scratch array for processing commands}
    array[0..datar_last] of sys_int_machine_t;
  datarn: sys_int_machine_t;           {number of entries in DATAR}
  ii: sys_int_machine_t;               {scratch integers and loop counters}
  b1: boolean;                         {scratch boolean}
  mapf:                                {firmware map file name}
    %include '(cog)lib/string_treename.ins.pas';

  opt:                                 {upcased command line option}
    %include '(cog)lib/string_treename.ins.pas';
  parm:                                {command parameter}
    %include '(cog)lib/string_treename.ins.pas';
  pick: sys_int_machine_t;             {number of token picked from list}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status code}

label
  next_opt, err_parm, parm_bad, done_opts, loop_cmd,
  flush,
  done_cmd, err_extra, bad_cmd, bad_parm, err_cmparm, cmd_nsupp, leave;
{
********************************************************************************
*
*   Local subroutine LOCKOUT
*
*   Acquire the lock on writing to the user.
}
procedure lockout;
  val_param; internal;

begin
  rdy2_show_lock (rdy_p^);
  end;
{
********************************************************************************
*
*   Local subroutine UNLOCKOUT
*
*   Release the lock on writing to the user.
}
procedure unlockout;
  val_param; internal;

begin
  rdy2_show_unlock (rdy_p^);
  end;

%include '(cog)lib/nextin_local.ins.pas'; {define command reading routines}
{
********************************************************************************
*
*   Subroutine FWINFO_RSP (AGL, ARG)
*
*   This routine is installed to be called automatically by the RDY2 library
*   immediately after each FWINFO response is processed.  It does:
*
*     Sets MAPF to the name of the firmware map file.  MAPF is set to the empty
*     string if the map file can not be found.
}
procedure fwinfo_rsp (                 {FWINFO response callback routine}
  in out  agl: rdy2_t;                 {RDY2 library use state}
  in      arg: sys_int_adr_t);         {app-specific argument, unused}
  val_param; internal;

var
  tnam: string_treename_t;             {scratch for making map file name}
  tk: string_var32_t;                  {scratch token}
  ii: sys_int_machine_t;               {scratch integer}
  stat: sys_err_t;                     {completion status}

label
  done_mapf;

begin
  tnam.max := size_char(tnam.str);     {init local var strings}
  tk.max := size_char(tk.str);
{
*   Set MAPF to the name of the firmware map file for this firmware version.
*   MAPF is set to the empty string when a suitable map file can not be found.
}
  mapf.len := 0;                       {init to map file not available}
  if rdy_p^.fw_rdy2t.ver >= 0 then return; {firmware version is unknown ?}
  {
  *   Build full map file name with firmware version number.
  }
  string_vstring (tnam, mapdir, size_char(mapdir)); {build map file name}
  string_append1 (tnam, '/');
  string_appendn (tnam, fwname, size_char(fwname));
  ii := 2;                             {init version number field width}
  if rdy_p^.fw_rdy2t.ver >= 10         {will make min required digits anyway ?}
    then ii := 0;                      {use free form to convert number}
  string_f_int_max_base (              {make firmware version number string}
    tk,                                {output string}
    rdy_p^.fw_rdy2t.ver,               {input number}
    10,                                {number base}
    ii,                                {field width}
    [ string_fi_leadz_k,               {add leading zeros to fill field}
      string_fi_unsig_k],              {input integer is unsigned}
    stat);
  if sys_error(stat) then goto done_mapf; {abort with map file unavailable}
  string_append (tnam, tk);            {add version number to map file name}
  string_appends (tnam, '.map');       {add file name suffix}

  if file_exists (tnam) then begin     {map file with version number is available ?}
    string_treename (tnam, mapf);      {save full map file name}
    goto done_mapf;
    end;
  {
  *   Map file with firmware version doesn't exist.  Try without version number.
  }
  tnam.len := tnam.len - tk.len - 4;   {remove version number and suffix from file name}
  string_appends (tnam, '.map');       {add file name suffix}

  if file_exists (tnam) then begin     {map file without version number is available ?}
    string_treename (tnam, mapf);      {save full map file name}
    end;
done_mapf:                             {done trying to resolve map file name in MAPF}

  end;
{
********************************************************************************
*
*   Subroutine DATAR_ADD (V)
*
*   Add the value V as the next word in the scratch data array DATAR.  DATARN is
*   updated to indicate the number of entries in DATAR.  Nothing is done if the
*   array is already full.
}
(*
procedure datar_add (                  {add value to DATAR array}
  in      v: sys_int_machine_t);       {the value to add}
  val_param; internal;

begin
  if datarn < datar_size then begin    {array isn't already full ?}
    datar[datarn] := v;                {stuff this value into the array}
    datarn := datarn + 1;              {count one more value in the array}
    end;
  end;
*)
{
********************************************************************************
*
*   Start of main routine.
}
begin
  writeln;
  writeln ('TEST_RDY2 built ', build_dtm_str:size_char(build_dtm_str));
{
*   Initialize our state before reading the command line options.
}
  rdyopen := [rdy2_open_shrsp_k];      {init to show received responses on STDOUT}
  string_cmline_init;                  {init for reading the command line}
{
*   Back here each new command line option.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (opt,                {pick command line option name from list}
    '-SHOWIN -SHOWOUT -SHOWNOP',
    pick);                             {number of keyword picked from list}
  case pick of                         {do routine for specific option}
{
*   -SHOWIN
}
1: begin
  rdyopen := rdyopen + [rdy2_open_shin_k];
  end;
{
*   -SHOWOUT
}
2: begin
  rdyopen := rdyopen + [rdy2_open_shout_k];
  end;
{
*   -SHOWNOP
}
3: begin
  rdyopen := rdyopen + [rdy2_open_shnop_k];
  end;
{
*   Unrecognized command line option.
}
otherwise
    string_cmline_opt_bad;             {unrecognized command line option}
    end;                               {end of command line option case statement}

err_parm:                              {jump here on error with parameter}
  string_cmline_parm_check (stat, opt); {check for bad command line option parameter}
  goto next_opt;                       {back for next command line option}

parm_bad:                              {jump here on got illegal parameter}
  string_cmline_reuse;                 {re-read last command line token next time}
  string_cmline_token (parm, stat);    {re-read the token for the bad parameter}
  sys_msg_parm_vstr (msg_parm[1], parm);
  sys_msg_parm_vstr (msg_parm[2], opt);
  sys_message_bomb ('string', 'cmline_parm_bad', msg_parm, 2);

done_opts:                             {done with all the command line options}
{
*   All done reading the command line.
}
  rdy2_lib_open (                      {open library to access the remote device}
    util_top_mem_context,              {parent memory context}
    string_v(''(0)),                   {no specific device name}
    rdyopen,                           {option flags}
    rdy_p,                             {returned pointer to library state}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  rdy2_callback_fwinfo (               {install callback routine for FWINFO responses}
    rdy_p^,                            {RDY2 library use state}
    addr(fwinfo_rsp),                  {pointer to routine to call}
    0);                                {argument to pass to callback routine, unused}

  rdy2_cmd_fwinfo (rdy_p^, stat);      {send FWINFO command}
  sys_error_abort (stat, '', '', nil, 0);
  rdy2_send_lock (rdy_p^);             {acquire lock on command stream}
  rdy2_send (rdy_p^, stat);            {send all buffered data}
  sys_error_abort (stat, '', '', nil, 0);
  rdy2_send_unlock (rdy_p^);           {release lock on command stream}

  for ii := 0 to datar_last do begin   {init the scratch data array}
    datar[ii] := 0;
    end;
{
***************************************
*
*   Process user commands.
*
*   Initialize before command processing.
}
  string_vstring (prompt, ': '(0), -1); {set command prompt string}

loop_cmd:
  sys_wait (0.100);
  lockout;
  rdy2_show_vstr (rdy_p^, prompt);     {prompt the user to enter a command}
  unlockout;

  string_readin (inbuf);               {get command from the user}
  rdy2_show_atstart (rdy_p^);          {now at start of output line}

  if inbuf.len <= 0 then begin         {user entered a blank line ?}
    goto loop_cmd;
    end;

  p := 1;                              {init BUF parse index}
  while inbuf.str[p] = ' ' do begin    {scan forwards to the first non-blank}
    p := p + 1;
    end;
  pst := p;                            {save parse index at start of command}
  next_keyw (opt, stat);               {extract command name into OPT}
  if string_eos(stat) then goto loop_cmd;
  if sys_error_check (stat, '', '', nil, 0) then begin
    goto loop_cmd;
    end;
  string_tkpick_s (                    {pick command name from list}
    opt, cmdnames, sizeof(cmdnames), pick);

  datarn := 0;                         {init scratch data array to empty}
  case pick of                         {which command is it}
{
**********
*
*   HELP
}
1, 2: begin
  if not_eos then goto err_extra;

  lockout;                             {acquire lock for writing to output}
  writeln;
  writeln ('HELP or ?      - Show this list of commands.');
  writeln ('SHOW IN|OUT|NOP ON|OFF - Show raw bytes, NOP responses');

  writeln ('PING           - Send PING command to test communication link');
  writeln ('FWINFO         - Request firmware version info');
  writeln ('NAME [name]    - Get or set device name');
  writeln ('IMPL           - Update list of implemented commands');
  writeln ('BSAM onoff     - Live input bit sampling on/off');

  writeln ('Q or QUIT      - Exit the program');
  unlockout;                           {release lock for writing to output}
  end;
{
**********
*
*   QUIT
}
3, 4: begin
  if not_eos then goto err_extra;

  goto leave;
  end;
{
**********
*
*   PING
}
5: begin
  if not_eos then goto err_extra;

  rdy2_cmd_ping (rdy_p^, stat);
  if sys_error(stat) then goto err_cmparm;

flush:                                 {send all data now, end command}
  rdy2_send_lock (rdy_p^);
  rdy2_send (rdy_p^, stat);
  rdy2_send_unlock (rdy_p^);
  end;
{
**********
*
*   FWINFO
}
6: begin
  if not_eos then goto err_extra;

  rdy2_cmd_fwinfo (rdy_p^, stat);
  end;
{
**********
*
*   SHOW IN onoff
*   SHOW OUT onoff
*   SHOW NOP onoff
}
7: begin
  next_keyw (parm, stat);
  if sys_error(stat) then goto err_cmparm;
  string_tkpick80 (parm, 'IN OUT NOP', pick);
  case pick of
1:  begin                              {SHOW IN}
      b1 := next_onoff(stat);
      if sys_error(stat) then goto err_cmparm;
      if not_eos then goto err_extra;
      rdy2_show_in (rdy_p^, b1);
      end;
2:  begin                              {SHOW OUT}
      b1 := next_onoff(stat);
      if sys_error(stat) then goto err_cmparm;
      if not_eos then goto err_extra;
      rdy2_show_out (rdy_p^, b1);
      end;
3:  begin                              {SHOW OUT}
      b1 := next_onoff(stat);
      if sys_error(stat) then goto err_cmparm;
      if not_eos then goto err_extra;
      rdy2_show_nop (rdy_p^, b1);
      end;
otherwise
    goto bad_cmd;
    end;
  end;
{
**********
*
*   NAME [name]
}
8: begin
  next_token (parm, stat);             {try to get optional NAME parameter}
  if not string_eos(stat) then begin   {other then end of command line ?}
    if not_eos then goto err_extra;
    rdy2_cmd_nameset (rdy_p^, parm, stat); {set the new device name}
    if sys_error(stat) then goto err_cmparm;
    end;

  rdy2_cmd_nameget (rdy_p^, stat);     {request the device name}
  end;
{
**********
*
*   IMPL
}
9: begin
  if not_eos then goto err_extra;

  rdy2_cmd_getcmds (rdy_p^, stat);
  end;
{
**********
*
*   BSAM onoff
}
10: begin
  b1 := next_onoff (stat);             {get ONOFF into B1}
  if sys_error(stat) then goto err_cmparm;
  if not_eos then goto err_extra;

  rdy2_cmd_bitsam (rdy_p^, b1, stat);
  end;
{
**********
*
*   Unrecognized command name.
}
otherwise
    goto bad_cmd;
    end;

done_cmd:                              {done processing this command}
  if sys_error(stat) then goto err_cmparm;

  if not_eos then begin                {extraneous token after command ?}
err_extra:
    lockout;
    writeln ('Too many parameters for this command.');
    unlockout;
    end;

  if not rdy2_send_empty (rdy_p^) then begin {there is data to send ?}
    rdy2_send_wait (rdy_p^, stat);     {send it, wait for all commands completed}
    if sys_error(stat) then goto err_cmparm;
    end;
  goto loop_cmd;                       {back to process next command}

bad_cmd:                               {unrecognized or illegal command}
  lockout;
  writeln ('Huh?');
  unlockout;
  goto loop_cmd;

bad_parm:                              {bad parameter, parmeter in PARM}
  lockout;
  writeln ('Bad parameter "', parm.str:parm.len, '"');
  unlockout;
  goto loop_cmd;

err_cmparm:                            {parameter error, STAT set accordingly}
  lockout;
  sys_error_print (stat, '', '', nil, 0);
  unlockout;
  goto loop_cmd;

cmd_nsupp:
  lockout;
  writeln ('Command not supported by this firmware.');
  unlockout;
  goto loop_cmd;

leave:
  rdy2_lib_close (rdy_p);              {done accessing the remote device}
  end.
