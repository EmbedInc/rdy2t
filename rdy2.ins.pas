{   Public include file for the RDY2 library.  This library provides a
*   procedural interface to the RDY2T template firmware running on an Embed
*   ReadyBoard-02.  The computer running this code must be connected to the
*   ReadyBoard via USB.
}
const
  rdy2t_fwtype = 76;                   {RDY2T firmware type ID}
{
*   Status codes.
}
  rdy2_subsys_k = -89;                 {RDY2 library subsystem ID}
  rdy2_err_noresp_k = 1;               {no response from the remote system}
  rdy2_cmd_nimpl_k = 2;                {command not implemented}
{
*   Configuration constants.
}
  rdy2_obuf_size = 64;                 {size of output buffer to remote sys, bytes}
  rdy2_waitsec = 3.0;                  {max seconds to wait for response from remote sys}
  rdy2_bitsam_sz = 1024;               {max runs live bit sample FIFO can hold}
{
*   Derived constants.
}
  rdy2_obuflast = rdy2_obuf_size - 1;  {last valid 0-N output buffer byte index}

type
  rdy2_open_k_t = (                    {option flags for starting new lib use}
    rdy2_open_shin_k,                  {show all raw input bytes}
    rdy2_open_shout_k,                 {show all raw output bytes}
    rdy2_open_shnop_k,                 {show NOP response, with consecutive count}
    rdy2_open_shrsp_k);                {show interpreted received responses}
  rdy2_open_t = set of rdy2_open_k_t;  {all flags in one set}

  rdy2_bitsam_t = record               {state related to live bit sampling feature}
    fifo_p: string_fifo_p_t;           {FIFO of same-value runs}
    inv: boolean;                      {invert the sampled 0/1 data}
    end;

  rdy2_p_t = ^rdy2_t;
  rdy2_t = record                      {state for one use of this library}
    mem_p: util_mem_context_p_t;       {points to context for all dynamic memory}
    conn: file_conn_t;                 {USB connection to the Ag-S}
    lock_out: sys_sys_threadlock_t;    {mutex for sending to remote system}
    obuf:                              {output buffer to remote system}
      array [0..rdy2_obuflast] of int8u_t;
    obufn: sys_int_machine_t;          {number of bytes in OBUF}
    pong: sys_sys_event_id_t;          {signalled when PONG response received}
    fw_rdy2t: utest_fw_t;              {RDY2T firmware info}
    name: string_var80_t;              {name reported by unit}
    cmd: array[0..255] of boolean;     {command is implemented in this firmware}
    quit: boolean;                     {trying to shut down}
    show_lock: sys_sys_threadlock_t;   {mutex for writing to standard output}
    show_in: boolean;                  {show raw input bytes from unit}
    show_out: boolean;                 {show raw output bytes to unit}
    show_nop: boolean;                 {show NOP responses, with consecutive count}
    show_rsp: boolean;                 {show interpreted responses}
    show_pong: boolean;                {show PONG response, not trigger PONG event}
    stline: boolean;                   {user output position is at start of line}
    fwinfo_call_p: univ_ptr;           {to routine to call after FWINFO response}
    fwinfo_app: sys_int_adr_t;         {app-specific argument to FWINFO callback}
    bitsam: rdy2_bitsam_t;             {state for optional BITSAM feature}
    inexit: sys_sys_event_id_t;        {signalled when input thread exits}
    end;

  rdy2_fwinfo_call_p_t = ^procedure (  {to FWINFO callback routine}
    in out rdy: rdy2_t;                {library use state}
    in     arg: sys_int_adr_t);        {application-specific argument}
    val_param;
{
********************************************************************************
*
*   Entry points.
}
procedure rdy2_bitsam_clear (          {clear any existing bit sampled data}
  in out  rdy: rdy2_t);                {library use state}
  val_param; extern;

procedure rdy2_bitsam_polarity (       {set reported polarity of live bit samples}
  in out  rdy: rdy2_t;                 {library use state}
  in      pos: boolean);               {TRUE high 1 low 0, FALSE opposite}
  val_param; extern;

procedure rdy2_bitsam_run (            {get next sampled bit run}
  in out  rdy: rdy2_t;                 {library use state}
  out     bit: sys_int_machine_t;      {bit value, 0 or 1, after polarity applied}
  out     len: sys_int_machine_t);     {number of consecutive samples of this value}
  val_param; extern;

procedure rdy2_callback_fwinfo (       {install callback routine for FWINFO response}
  in out  rdy: rdy2_t;                 {library use state}
  in      call_p: rdy2_fwinfo_call_p_t; {to routine to call on FWINFO resp, NIL = none}
  in      arg: sys_int_adr_t);         {app-specific parameter to callback routine}
  val_param; extern;

procedure rdy2_cmd_bitsam (            {send BITSAM command}
  in out  rdy: rdy2_t;                 {library use state}
  in      on: boolean;                 {switch the feature on}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_cmd_fwinfo (            {send FWINFO command}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_cmd_getcmds (           {send GETCMDS command}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_cmd_nameget (           {send NAMEGET command}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_cmd_nameset (           {send NAMESET command}
  in out  rdy: rdy2_t;                 {library use state}
  in      name: univ string_var_arg_t; {string to set device name to}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_cmd_nop (               {send NOP command}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_cmd_ping (              {send PING command}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

function rdy2_cmdimpl (                {check for command implemented}
  in out  rdy: rdy2_t;                 {library use state}
  in      cmd: sys_int_machine_t)      {0-255 command opcode}
  :boolean;                            {the command is implemented in this firmware}
  val_param; extern;

function rdy2_err_cmdnimpl (           {set error status iff command unimplemented}
  in out  rdy: rdy2_t;                 {library use state}
  in      name: string;                {command name}
  in      opc: sys_int_machine_t;      {0-255 command opcode}
  out     stat: sys_err_t)             {set to unimplemented command or no error}
  :boolean;                            {the command is unimplemented}
  val_param; extern;

procedure rdy2_lib_close (             {end RDY2 lib use, release resources}
  in out  rdy_p: rdy2_p_t);            {pointer to library use state, returned NIL}
  val_param; extern;

procedure rdy2_lib_open (              {start new use of the RDY2 library}
  in out  mem: util_mem_context_t;     {parent memory context, will make sub context}
  in      name: univ string_var_arg_t; {required device name, empty to match any}
  in      opt: rdy2_open_t;            {option flags}
  out     rdy_p: rdy2_p_t;             {will point to new library use state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_name_cmd (              {get command name from opcode}
  in out  rdy: rdy2_t;                 {library use state}
  in      opc: sys_int_machine_t;      {0-255 command opcode}
  in out  name: univ string_var_arg_t); {returned cmd name, empty on undefined}
  val_param; extern;

procedure rdy2_name_rsp (              {get response name from opcode}
  in out  rdy: rdy2_t;                 {library use state}
  in      opc: sys_int_machine_t;      {0-255 response opcode}
  in out  name: univ string_var_arg_t); {returned rsp name, empty on undefined}
  val_param; extern;

procedure rdy2_send (                  {send all buffered data, must hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_send8 (                 {send 8 bits, must hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  in      dat: univ sys_int_conv8_t;   {data in low bits}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_send16 (                {send 16 bits, must hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  in      dat: univ sys_int_conv16_t;  {data in low bits}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_send24 (                {send 24 bits, must hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  in      dat: univ sys_int_conv24_t;  {data in low bits}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_send32 (                {send 32 bits, must hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  in      dat: univ sys_int_conv32_t;  {data in low bits}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

function rdy2_send_empty (             {check for output buffer empty}
  in out  rdy: rdy2_t)                 {library use state}
  :boolean;                            {no buffered unsent data}
  val_param; extern;

procedure rdy2_send_lock (             {acquire lock on sending to remote unit}
  in out  rdy: rdy2_t);                {library use state}
  val_param; extern;

procedure rdy2_send_unlock (           {release lock on sending to remote unit}
  in out  rdy: rdy2_t);                {library use state}
  val_param; extern;

procedure rdy2_send_wait (             {send, wait for all commands done, not hold lock}
  in out  rdy: rdy2_t;                 {library use state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure rdy2_show_atstart (          {indicate at start of output line to user}
  in out  rdy: rdy2_t);                {library use state}
  val_param; extern;

procedure rdy2_show_end (              {end output line to user, release lock}
  in out  rdy: rdy2_t);                {library use state}
  val_param; extern;

procedure rdy2_show_eol (              {end the current output line to the user}
  in out  rdy: rdy2_t);                {library use state}
  val_param; extern;

procedure rdy2_show_eol_end (          {write newline, release lock on user output}
  in out  rdy: rdy2_t);                {library use state}
  val_param; extern;

procedure rdy2_show_in (               {enable/disable showing raw input bytes}
  in out  rdy: rdy2_t;                 {library use state}
  in      on: boolean);                {enable showing input bytes}
  val_param; extern;

procedure rdy2_show_lock (             {acquire lock on writing to user}
  in out  rdy: rdy2_t);                {library use state}
  val_param; extern;

procedure rdy2_show_nop (              {enable/disable showing NOP responses}
  in out  rdy: rdy2_t;                 {library use state}
  in      on: boolean);                {enable showing output bytes}
  val_param; extern;

procedure rdy2_show_nstart (           {indicate output line to user is not at start}
  in out  rdy: rdy2_t);                {library use state}
  val_param; extern;

procedure rdy2_show_out (              {enable/disable showing raw output bytes}
  in out  rdy: rdy2_t;                 {library use state}
  in      on: boolean);                {enable showing output bytes}
  val_param; extern;

procedure rdy2_show_resp (             {enable/disable showing responses except NOP}
  in out  rdy: rdy2_t;                 {library use state}
  in      on: boolean);                {enable showing responses from remote system}
  val_param; extern;

procedure rdy2_show_start (            {to start of next line if not already at start}
  in out  rdy: rdy2_t);                {library use state}
  val_param; extern;

procedure rdy2_show_str (              {show Pascal string to user}
  in out  rdy: rdy2_t;                 {library use state}
  in      str: string);                {string to write}
  val_param; extern;

procedure rdy2_show_vstr (             {show varstring to user}
  in out  rdy: rdy2_t;                 {library use state}
  in      vstr: univ string_var_arg_t); {string to write}
  val_param; extern;

procedure rdy2_show_unlock (           {release user writing lock}
  in out  rdy: rdy2_t);                {library use state}
  val_param; extern;
