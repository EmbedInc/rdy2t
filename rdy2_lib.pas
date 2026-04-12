{   High level RDY2 library management.
}
module rdy2_lib;
define rdy2_lib_open;
define rdy2_lib_close;
define rdy2_callback_fwinfo;
%include 'rdy2_2.ins.pas';

const
  maxtime = 10.0;                      {max seconds to wait for USB dev available}
  wait_retry = 0.25;                   {seconds to wait between USB retries}
  vid = 5824;                          {Voti USB vendor ID}
  pid = 1481;                          {ReadyBoard-02}
{
********************************************************************************
*
*   Local subroutine RDY2_LIB_OPEN_CONN (RDY, NAME, STAT)
*
*   Open the I/O connection to the remote unit.
}
procedure rdy2_lib_open_conn (         {open I/O connection to remote unit}
  in out  rdy: rdy2_t;                 {library use state}
  in      name: univ string_var_arg_t; {required device name, "" matches any}
  out     stat: sys_err_t);            {completion status}
  val_param; internal;

var
  stime: sys_clock_t;                  {starting time}
  found: boolean;                      {a suitable device was found in the list}
  usbdev: file_usbdev_list_t;          {list of USB devices}
  dev_p: file_usbdev_p_t;              {points to current USB devices list entry}
  dt: real;                            {time since start}

label
  retry, next_dev, done_list;

begin
  sys_error_none (stat);               {init to no error}
  found := false;                      {init to no suitable USB device found}
  stime := sys_clock;                  {save the starting time}

retry:                                 {back here to try finding USB device again}
{
*   Make list of Embed USB devices.
}
  file_embusb_list_get (               {get list of known Embed USB devices}
    file_usbid(vid, pid),              {list only ReadyBoard-02 devices}
    rdy.mem_p^,                        {parent memory context for the list}
    usbdev,                            {returned list of devices}
    stat);
  if sys_error(stat) then return;
{
*   Scan the list of USB devices looking for the right one.
}
  dev_p := usbdev.list_p;              {init to first list entry}
  while dev_p <> nil do begin          {loop over the list entries}
    if name.len > 0 then begin         {name specified, must match start ?}
      if not string_match (dev_p^.name, name) {definite name mismatch ?}
        then goto next_dev;
      if dev_p^.name.len > name.len then begin {device has more info in its name ?}
        if dev_p^.name.str[name.len + 1] <> ' ' {next character must be blank}
          then goto next_dev;
        end;
      end;                             {end of looking for specific device name}
    found := true;                     {a suitable USB device was found}
    file_open_embusb (                 {try to open this device}
      dev_p^.vidpid,                   {USB VID and PID}
      dev_p^.name,                     {name of this device}
      rdy.conn,                        {returned connection to the device}
      stat);
    goto done_list;
next_dev:                              {advance to the next device in the list}
    dev_p := dev_p^.next_p;            {to next list entry}
    end;

done_list:
{
*   Done scanning the list of USB devices.
*
*   When FOUND is FALSE, then no suitable device was found.  The intended device
*   could have been recently plugged in and enumerating, so we wait overall up
*   to MAXTIME seconds.
*
*   FOUND of TRUE indicates a matching device was found.  In that case STAT
*   indicates whether the device was successfully opened.
}
  file_usbdev_list_del (usbdev);       {deallocate the list of USB devices}

  if found then return;                {found device, STAT indicates success}

  dt := sys_clock_to_fp2(              {make seconds since start}
    sys_clock_sub (sys_clock, stime) );
  if dt >= maxtime then begin          {time is up ?}
    if not sys_error(stat) then begin  {not already indicating an error ?}
      sys_stat_set (                   {indicate USB device not found error}
        file_subsys_k, file_stat_usbidn_nfound_k, stat);
      sys_stat_parm_vstr (name, stat);
      sys_stat_parm_int (vid, stat);
      sys_stat_parm_int (pid, stat);
      end;
    return;
    end;

  sys_wait (wait_retry);               {wait a little while before retrying}
  goto retry;                          {back to try finding USB device again}
  end;
{
********************************************************************************
*
*   Subroutine RDY2_LIB_OPEN (MEM, NAME, RDY_P, STAT)
*
*   Open a new use of the RDY2 library.  MEM is the parent memory context.  A
*   subordinate memory context for the new library use will be created under
*   MEM.  When there is no error, RDY_P will be returned pointing to the new
*   library use state.
*
*   NAME is the required name of the device to connect to.  When NAME is the
*   empty string, then the first USB device with the ReadyBoard-02 VID/PID is
*   connected to.
}
procedure rdy2_lib_open (              {start new use of the RDY2 library}
  in out  mem: util_mem_context_t;     {parent memory context, will make sub context}
  in      name: univ string_var_arg_t; {required device name, empty to match any}
  in      opt: rdy2_open_t;            {option flags}
  out     rdy_p: rdy2_p_t;             {will point to new library use state}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  mem_p: util_mem_context_p_t;         {to new private memory context}
  ioopen: boolean;                     {I/O connection to remote unit is open}
  thid: sys_sys_thread_id_t;           {ID of newly created thread}
  ii: sys_int_machine_t;               {scratch integer and loop counter}

label
  abort1, abort2, abort3, abort4;

begin
  ioopen := false;                     {init to I/O connection to unit not open}

  util_mem_context_get (mem, mem_p);   {create mem context for new lib use}
  util_mem_context_err_bomb (mem_p);
  util_mem_grab (                      {allocate memory for lib use state}
    sizeof(rdy_p^), mem_p^, false, rdy_p);
  util_mem_grab_err_bomb (rdy_p, sizeof(rdy_p^));

  rdy_p^.mem_p := mem_p;               {save pointer to new memory context}
  rdy2_lib_open_conn (rdy_p^, name, stat); {open USB connection to remote unit}
  if sys_error(stat) then goto abort1;
  ioopen := true;                      {I/O connection to remote unit is now open}

  sys_thread_lock_create (rdy_p^.lock_out, stat); {create output sending mutex}
  if sys_error(stat) then goto abort1;
  rdy_p^.obufn := 0;                   {init output buffer to empty}
  sys_event_create_bool (rdy_p^.pong); {create event signalled on PONG response}
  utest_fw_init (rdy_p^.fw_rdy2t);     {init RDY2 firmware info to unknown}
  rdy_p^.name.max := size_char(rdy_p^.name.str); {init unit name to empty string}
  rdy_p^.name.len := 0;
  for ii := 0 to 255 do begin          {init implemented commands array}
    rdy_p^.cmd[ii] := ii <= 5;         {init to only basic required commands implemented}
    end;
  rdy_p^.quit := false;                {init to not indicate ending library use}
  sys_thread_lock_create (rdy_p^.show_lock, stat); {create writing to user mutex}
  if sys_error(stat) then goto abort2;
  rdy_p^.show_in := rdy2_open_shin_k in opt;
  rdy_p^.show_out := rdy2_open_shout_k in opt;
  rdy_p^.show_nop := false;            {init showing responses to off for now}
  rdy_p^.show_rsp := false;
  rdy_p^.show_pong := rdy_p^.show_rsp;
  rdy_p^.stline := true;               {init to user output is at start of line}
  rdy_p^.fwinfo_call_p := nil;
  rdy_p^.fwinfo_app := 0;
{
*   Start the thread that receives and processes the response stream from the
*   remote unit.
}
  sys_thread_create (                  {start the input receiving thread}
    sys_threadproc_p_t(addr(rdy2_in)), {top thread routine}
    sys_int_adr_t(rdy_p),              {pointer to library use state}
    thid,                              {returned ID of the new thread}
    stat);
  if sys_error(stat) then goto abort3;

  sys_thread_event_get (               {get input thread exit event}
    thid,                              {ID of thread getting exit event of}
    rdy_p^.inexit,                     {returned event}
    stat);
  if sys_error(stat) then begin        {unable to get thread exit event ?}
    rdy_p^.quit := true;               {try to tell thread to exit}
    file_close (rdy_p^.conn);          {close the I/O connection}
    ioopen := false;                   {indicate I/O connection is closed}
    sys_wait (0.500);                  {give thread time to react to closed I/O}
    goto abort3;
    end;
{
*   Send initial commands the result of which are needed for the library to
*   function correctly.
}
  rdy2_cmd_fwinfo (rdy_p^, stat);      {get firmware version info}
  if sys_error(stat) then goto abort4;
  rdy2_cmd_getcmds (rdy_p^, stat);     {get list of implemented commands}
  if sys_error(stat) then goto abort4;

  rdy2_send_wait (rdy_p^, stat);       {send all commands, wait for done}
  if sys_error(stat) then goto abort4;

  rdy_p^.show_nop := rdy2_open_shnop_k in opt; {set showing responses according to caller}
  rdy_p^.show_rsp := rdy2_open_shrsp_k in opt;
  rdy_p^.show_pong := rdy_p^.show_rsp;
  return;                              {new lib use created, normal return point}
{
*   Error exits.  STAT must already be set to indicate the error.
}
abort4:
  sys_event_del_bool (rdy_p^.inexit);  {delete thread exit event}

abort3:                                {user output writing lock created}
  sys_thread_lock_delete (rdy_p^.show_lock, stat); {delete user output mutex}

abort2:                                {sending mutex and PONG event created}
  sys_event_del_bool (rdy_p^.pong);    {delete event for PONG response}
  sys_thread_lock_delete (rdy_p^.lock_out, stat); {delete sending mutex}

abort1:                                {new mem context exists, I/O might be open}
  if ioopen then begin                 {I/O connection is open ?}
    file_close (rdy_p^.conn);          {close the I/O connection}
    end;
  util_mem_context_del (mem_p);        {delete mem context, dealloc memory}
  rdy_p := nil;                        {indicate no lib use created}
  end;
{
********************************************************************************
*
*   Subroutine RDY2_LIB_CLOSE (RDY_P)
*
*   End a use of the RDY2 library and release all resources allocated to that
*   use.  On entry RDY_P points to the library use state to close.  It is
*   retured NIL.  RDY_P may be NIL on entry, in which case nothing is done.
}
procedure rdy2_lib_close (             {end RDY2 lib use, release resources}
  in out  rdy_p: rdy2_p_t);            {pointer to library use state, returned NIL}
  val_param;

var
  mem_p: util_mem_context_p_t;         {to new private memory context}
  stat: sys_err_t;

begin
  rdy_p^.quit := true;                 {indicate trying to shut down}
  file_close (rdy_p^.conn);            {close I/O connection to the unit}
  discard( sys_event_wait_tout (rdy_p^.inexit, 1.0, stat) ); {wait for thread to exit}
  sys_event_del_bool (rdy_p^.inexit);  {delete thread exit event}

  sys_thread_lock_delete (rdy_p^.lock_out, stat); {delete sending mutex}
  sys_event_del_bool (rdy_p^.pong);    {delete event for PONG response}
  sys_thread_lock_delete (rdy_p^.show_lock, stat); {delete user output mutex}

  mem_p := rdy_p^.mem_p;               {make local copy of pointer to mem context}
  util_mem_context_del (mem_p);        {delete mem context, release dyn mem}
  rdy_p := nil;                        {indicate lib use state no longer exists}
  end;
{
********************************************************************************
*
*   Subroutine RDY2_CALLBACK_FWINFO (RDY, CALL_P, ARG)
*
*   Set a routine to be called automatically after each FWINFO response is
*   received from the remote unit.  CALL_P is a pointer to the routine to call.
*   It may be NIL to cause no routine to be called after a FWINFO response.  ARG
*   is an arbitrary argument that will be saved and passed on to the callback
*   routine when called.
}
procedure rdy2_callback_fwinfo (       {install callback routine for FWINFO response}
  in out  rdy: rdy2_t;                 {library use state}
  in      call_p: rdy2_fwinfo_call_p_t; {to routine to call on FWINFO resp, NIL = none}
  in      arg: sys_int_adr_t);         {app-specific parameter to callback routine}
  val_param;

begin
  rdy.fwinfo_call_p := call_p;         {save pointer to callback routine, or NIL}
  rdy.fwinfo_app := arg;               {save app-specific argument to pass to callback}
  end;
