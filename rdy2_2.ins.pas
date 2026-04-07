{   Private include for the RDY2 library.  This file is for modules that
*   implement the RDY2 library.
}
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'stuff.ins.pas';
%include 'picprg.ins.pas';
%include 'utest.ins.pas';
%include 'rdy2.ins.pas';

procedure rdy2_in (                    {thread that receives all input from remote unit}
  var     rdy: rdy2_t);                {RDY2 lib use state passed by reference}
  val_param; extern;
