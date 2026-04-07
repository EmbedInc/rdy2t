This repository provides template code for a Embed ReadyBoard-02.
Specifically, it contains:

  RDY2T template firmware.  This firmware runs on the Microchip PIC
  18F2550 of an Embed ReadyBoard-02.  The firmware is meant as a
  convenient starting point for custom ReadyBoard-02 projects.

  Features that can be individually enabled/disabled at build time.  The
  ENAB_xxx switches in the main include file individually enable or
  disable the following features:

    USB interface.  There is no communication with the external world when
    this is disabled.

  RDY2 template host library that provides a procedural interaface to the
  RDY2T firmware over the USB.

  TEST_RDY2 test program that provides a command line interface to the
  RDY2T firmware over USB.  It is also an example of calling the RDY2
  library.
