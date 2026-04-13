{   Routines related to the optional live bit sampling feature.
}
module rdy2_bitsam;
define rdy2_bitsam_polarity;
define rdy2_bitsam_clear;
define rdy2_bitsam_run;
define rdy2_bitsam_bit;
%include 'rdy2_2.ins.pas';
{
********************************************************************************
*
*   Subroutine RDY2_BITSAM_POLARITY (RDY, POS)
*
*   Set the polarity with which live bit samples are reported.  POS of TRUE sets
*   positive polarity, meaning high is 1 and low 0.  POS of FALSE is the
*   opposite.
}
procedure rdy2_bitsam_polarity (       {set reported polarity of live bit samples}
  in out  rdy: rdy2_t;                 {library use state}
  in      pos: boolean);               {TRUE high 1 low 0, FALSE opposite}
  val_param;

begin
  rdy.bitsam.inv := not pos;
  end;
{
********************************************************************************
*
*   Subroutine RDY2_BITSAM_CLEAR (RDY)
*
*   Clear (delete) any live sampled bit data.
*
*   Samples received from the remote unit are pushed onto a FIFO.  This routine
*   deletes any data in the FIFO, resetting it to empty.  New samples will
*   continue to be written to the FIFO as they are received.
}
procedure rdy2_bitsam_clear (          {clear any existing bit sampled data}
  in out  rdy: rdy2_t);                {library use state}
  val_param;

begin
  string_fifo_reset (rdy.bitsam.fifo_p^); {reset the FIFO to empty}
  end;
{
********************************************************************************
*
*   Subroutine RDY2_BITSAM_RUN (RDY, BIT, LEN)
*
*   Get the next constant-value run of live bit sampled data.  This routine
*   blocks until a run is availble.
*
*   BIT is returne 0 or 1 indicating the bit value of this run.  The selected
*   polarity is applied to the raw data to make BIT.
*
*   LEN is the number of consecutive samples in the run.  This is guaranteed to
*   be at least 1.
}
procedure rdy2_bitsam_run (            {get next sampled bit run}
  in out  rdy: rdy2_t;                 {library use state}
  out     bit: sys_int_machine_t;      {bit value, 0 or 1, after polarity applied}
  out     len: sys_int_machine_t);     {number of consecutive samples of this value}
  val_param;

var
  run: sys_int_machine_t;              {byte from FIFO for this run}

begin
  run := string_fifo_get (rdy.bitsam.fifo_p^); {get next run}

  bit := rshft(run, 7);                {get the raw bit value}
  if rdy.bitsam.inv then begin         {invert from raw value ?}
    bit := (bit + 1) & 1;
    end;

  len := (run & 16#7F) + 1;            {number of samples in this run}
  end;
{
********************************************************************************
*
*   Function RDY2_BITSAM_BIT (RDY)
*
*   Get the next live sampled bit.  Sampled bit data is sent from the remote
*   unit to the computer in runs.  This routine returns the next sequential bit,
*   getting and unpacking runs as needed.  The bit polarity set with
*   RDY2_BITSAM_POLARITY is applied to the returned bit.
*
*   Results are not defined when the application gets runs directly in addition
*   to calling this routine since the last CLEAR.  When this routine is in use,
*   it should be considered to "own" incoming runs.
*
*   This routine blocks until the next bit value is available.
}
function rdy2_bitsam_bit (             {get next BITSAM bit, unpack runs as needed}
  in out  rdy: rdy2_t)                 {library use state}
  :sys_int_machine_t;                  {0 or 1 bit value, polarity applied}
  val_param;

begin
  if rdy.bitsam.runlen <= 0 then begin {there is no current run ?}
    rdy2_bitsam_run (rdy, rdy.bitsam.runval, rdy.bitsam.runlen); {get the next run}
    end;

  rdy2_bitsam_bit := rdy.bitsam.runval; {pass back bit value}
  rdy.bitsam.runlen := rdy.bitsam.runlen - 1; {one less bit left in current run}
  end;
