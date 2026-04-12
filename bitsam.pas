{   Program BITSAM [options]
*
*   Write sampled digital data to a CSV file.  The sampled digital data is from
*   a ReadyBoard-02 running the RDY2T firmware with the BITSAM and USB optional
*   features enabled.
*
*   One "event" will be written to the CSV file.  An event is detected by
*   specific start and end sequences.  The logic for these sequences is isolated
*   to separate subroutines so that they can be easily rewritten for different
*   sequences.
*
*   The ReadyBoard must be running and connected to the computer before this
*   program is run.
*
*   The command line options are:
*
*     -CSV fnam
*
*       FNAM is the name of the CSV file to write the sampled bit data to.  The
*       required ".csv" file name suffix may be omitted.  The default output
*       file name is "bitsam.csv".
}
program bitsam;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'stuff.ins.pas';
%include 'picprg.ins.pas';
%include 'utest.ins.pas';
%include 'rdy2.ins.pas';
%include 'builddate.ins.pas';

const
  defcsv = 'bitsam';                   {default generic CSV output file name}
  max_msg_parms = 2;                   {max parameters we can pass to a message}
  lastn = 8;                           {number of previous samples to keep around}
  samper = 0.0001;                     {sample period, seconds}
  invert = true;                       {invert levels reported by remote unit}

  lasts_max = lastn - 1;               {max valid LASTS index}

type
  datst_t = record                     {data for detecting start sequence}
    nlow: sys_int_machine_t;           {number of consecutive low samples}
    end;

  daten_t = record                     {data for detecting end sequence}
    nlow: sys_int_machine_t;           {number of consecutive low samples}
    end;

var
  csv: csv_out_t;                      {CSV file writing state}
  rdy_p: rdy2_p_t;                     {to RDY2 library use state}
  fnam:                                {scratch file name}
    %include '(cog)lib/string_treename.ins.pas';
  lasts:                               {last LASTN samples}
    array[0..lasts_max] of sys_int_machine_t;
  lastsn: sys_int_machine_t;           {number of samples in LASTS}
  lastsind: sys_int_machine_t;         {LASTS index of most recent sample}
  ii, jj: sys_int_machine_t;           {scratch integers and loop counters}
  runval: sys_int_machine_t;           {0 or 1 value of run being unpacked}
  runl: sys_int_machine_t;             {number of bits left in current run}
  datst: datst_t;                      {state for detecting start sequence}
  daten: daten_t;                      {state for detecting end sequence}
  trig_st, trig_en: boolean;           {start and end sequences detected}
  samp: sys_int_machine_t;             {0 or 1 current sample}
  sampn: sys_int_machine_t;            {sample number relative to start trigger}

  opt:                                 {upcased command line option}
    %include '(cog)lib/string32.ins.pas';
  parm:                                {command parameter}
    %include '(cog)lib/string_treename.ins.pas';
  pick: sys_int_machine_t;             {number of token picked from list}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status code}

label
  next_opt, err_parm, parm_bad, done_opts;
{
********************************************************************************
*
*   Subroutine CHECK_START
*
*   Check for the start sequence has occurred.  When so, TRIG_ST is set to TRUE.
}
procedure check_start;
  internal;

const
  zt = 0.020;                          {seconds consecutive low}

  zn = round(zt / samper);             {number of samples required low}

begin
  if trig_st then return;              {already detected start sequence}

  if samp = 1
    then begin                         {new sample is high}
      if datst.nlow >= zn then begin   {trigger ?}
        trig_st := true;
        return;
        end;
      datst.nlow := 0;                 {reset to no consecutive samples low}
      end
    else begin                         {new sample is low}
      if datst.nlow <= zn then begin   {not at full count ?}
        datst.nlow := datst.nlow + 1;  {count one more consecutive low}
        end;
      end
    ;
  end;
{
********************************************************************************
*
*   Subroutine CHECK_END
*
*   Check for the end sequence has occurred.  When so, TRIG_EN is set to TRUE.
}
procedure check_end;
  internal;

const
  zt = 0.020;                          {seconds consecutive low}

  zn = round(zt / samper);             {number of samples required low}

begin
  if not trig_st then return;          {start not detected yet ?}
  if trig_en then return;              {end already detected ?}

  if samp = 1
    then begin                         {new sample is high}
      daten.nlow := 0;                 {reset to no consecutive samples low}
      end
    else begin                         {new sample is low}
      daten.nlow := daten.nlow + 1;    {count one more consecutive low}
      if daten.nlow >= zn then begin   {trigger ?}
        trig_en := true;
        end;
      end
    ;
  end;
{
********************************************************************************
*
*   Subroutine GET_SAMPLE
*
*   Get the next single sample and update the state accordingly.  SAMP will be
*   set to the new sample value.  SAMPN will be incremented by 1 if after the
*   start trigger.
*
*   The start and end triggers are updated with this new sample.
}
procedure get_sample;
  internal;

begin
{
*   Get a new run if the current run is exhausted.
}
  if runl <= 0 then begin              {there is no active current run ?}
    rdy2_bitsam_run (rdy_p^, runval, runl); {get next run}
    end;
{
*   Update the state to the new sample.
}
  samp := runval;                      {get value from this run}
  runl := runl - 1;                    {one less sample left in this run}

  if sampn >= 0 then sampn := sampn + 1; {update sequential sample number}
{
*   Update the saved previous samples with this new sample.
}
  lastsind := lastsind + 1;            {to next saved sample index}
  if lastsind > lasts_max then lastsind := 0; {wrap back to start ?}
  lasts[lastsind] := samp;             {save this sample}
  if lastsn < lastn then lastsn := lastsn + 1; {update number of previous samples}
{
*   Update the start/end detection state to this new sample.
}
  check_start;                         {check for start sequence}
  check_end;                           {check for end sequence}
  end;
{
********************************************************************************
*
*   Subroutine WCSV_SAMP (N, VAL)
*
*   Write one sample to the CSV file.  N is the sequential sample number, with 0
*   being the sample at the start trigger.  VAL is the 0 or 1 value of the
*   sample to write.
}
procedure wcsv_samp (                  {write one sample to the CSV output file}
  in      n: sys_int_machine_t;        {sample number, 0 at start trigger}
  in      val: sys_int_machine_t);     {0 or 1 sample value}
  val_param; internal;

var
  t: double;                           {data time of this sample}
  stat: sys_err_t;                     {completion status}

begin
  t := n * samper;                     {make sample time in seconds}

  csv_out_fp_fixed (csv, t, 4, stat);  {write data time in ms}
  sys_error_abort (stat, '', '', nil, 0);
  csv_out_int (csv, val, stat);        {write bit value}
  sys_error_abort (stat, '', '', nil, 0);
  csv_out_line (csv, stat);            {finish this CSV output line}
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Start of main routine.
}
begin
  writeln ('Program BITSAM built ', build_dtm_str:size_char(build_dtm_str));
{
*   Initialize our state before reading the command line options.
}
  string_vstring (fnam, defcsv, size_char(defcsv)); {init to default CSV file name}
{
*   Back here each new command line option.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (opt,                {pick command line option name from list}
    '-CSV',
    pick);                             {number of keyword picked from list}
  case pick of                         {do routine for specific option}
{
*   -CSV
}
1: begin
  string_cmline_token (fnam, stat);    {get CSV file name}
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
{
*   Open and initialize the CSV output file.
}
  csv_out_open (fnam, csv, stat);      {open the CSV output file}
  sys_error_abort (stat, '', '', nil, 0);

  csv_out_str (csv, 'Seconds', stat);  {write CSV header line}
  sys_error_abort (stat, '', '', nil, 0);
  csv_out_str (csv, 'dat', stat);
  sys_error_abort (stat, '', '', nil, 0);
  csv_out_line (csv, stat);
  sys_error_abort (stat, '', '', nil, 0);
{
*   Connect to the ReadyBoard.
}
  rdy2_lib_open (                      {open library to access the remote device}
    util_top_mem_context,              {parent memory context}
    string_v(''(0)),                   {no specific device name}
    [],                                {option flags}
    rdy_p,                             {returned pointer to library state}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  write ('Firmware ');
  case rdy_p^.fw_rdy2t.typ of
rdy2t_fwtype: write ('RDY2T');
otherwise
    write ('type ', rdy_p^.fw_rdy2t.typ);
    end;
  writeln (' ver ', rdy_p^.fw_rdy2t.ver, ' seq ', rdy_p^.fw_rdy2t.seq);
{
*   Init for getting bit samples.
}
  lastsn := 0;                         {init to no previous saved samples}
  lastsind := lasts_max;               {init index to most recent sample}

  trig_st := false;                    {start sequence not detected yet}
  trig_en := false;                    {end sequence not detected yet}
  sampn := -1;                         {init sample number to before trigger}

  runl := 0;                           {there is no current run}
  {
  *   Init start sequence detection state.
  }
  datst.nlow := 0;
  {
  *   Init end sequence detection state.
  }
  daten.nlow := 0;
  {
  *   Start sampling.
  }
  rdy2_bitsam_polarity (               {select polarity}
    rdy_p^, not invert);
  rdy2_bitsam_clear (rdy_p^);          {clear any previously stored samples}

  rdy2_cmd_bitsam (rdy_p^, true, stat); {turn on live bit sampling}
  sys_error_abort (stat, '', '', nil, 0);
  rdy2_send_wait (rdy_p^, stat);
  sys_error_abort (stat, '', '', nil, 0);
{
*   Wait for the start sequence.
}
  while not trig_st do begin           {loop until start trigger}
    get_sample;
    end;

  sampn := 0;                          {the latest sample is now sample 0}
{
*   Write the previous stored samples to the CSV file.
}
  ii := lastsn - 1;                    {number of previous saved samples}
  if ii > 0 then begin                 {there are previous samples to write ?}
    jj := lastsind - ii;               {go to oldest sample}
    if jj < 0 then jj := jj + lastn;   {wrap back to end of buffer}
    ii := -ii;                         {make number of indexed sample}
    while ii <= 0 do begin             {loop over previous sample, oldest to newest}
      wcsv_samp (ii, lasts[jj]);       {write this sample to CSV file}
      jj := jj + 1;                    {to next sample}
      if jj > lasts_max then jj := 0;  {wrap back to start of buffer}
      ii := ii + 1;                    {make number of this next sample}
      end;
    end;
{
*   Write samples to the CSV file until the end trigger is reached.
}
  while not trig_en do begin           {loop until end sequence detected}
    get_sample;                        {get the next sample}
    wcsv_samp (sampn, samp);           {write it to the CSV file}
    end;
{
*   Clean up and leave.
}
  rdy2_cmd_bitsam (rdy_p^, false, stat); {turn off live bit sampling}
  sys_error_abort (stat, '', '', nil, 0);
  rdy2_send_wait (rdy_p^, stat);
  sys_error_abort (stat, '', '', nil, 0);

  rdy2_lib_close (rdy_p);              {disconnect from the remote system}

  csv_out_close (csv, stat);           {close the CSV output file}
  sys_error_abort (stat, '', '', nil, 0);
  end.
