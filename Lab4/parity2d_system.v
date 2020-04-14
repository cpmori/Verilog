/**************************************************************/
/* Testbench                                                  */
/**************************************************************/
module parity2d_system_tb;

  reg         rst, clk;
  reg  [27:0] tx_data;
  reg         tx_valid;
  wire        tx_ready;
  wire        tx_ser_data;
  wire        start;
  wire        rx_ser_data;
  wire [27:0] rx_data;
  wire        rx_valid;
  wire        rx_err;

  reg         en_err_inject, err_inject;
  reg  [ 5:0] err_cnt;

  // free running clock
  always #5 clk = ~clk;

  // process for initializing clock and performing reset
  initial
  begin
        clk = 0;
        rst = 1;
    #10 rst = 0;
  end

  // stimulate the transmitter
  initial
  begin
    tx_data  = { 7'd108, 7'd87, 7'd114, 7'd95 };
    tx_valid = 0;
    //
    // the first data won't have any errors
    en_err_inject = 0;

    // wait a few clock cycles before start
    repeat( 20 )
      @( posedge clk );

    // drive valid and wait for ready; the 45 units of time is just to show the
    // signal offset from the rising clock edge to make it clear that it's
    // a 1 leading into the next clock edge
    #45 tx_valid = 1;
    wait ( tx_valid && tx_ready );
    // data assumed transferred so de-assert valid
    @( posedge clk )
      tx_valid = 0;

    // wait for the received side to assert valid meaning that it's received,
    // processed, and provided the data
    wait ( rx_valid )
    repeat( 20 )
      @( posedge clk );

    // the second transfer should have some errors
    en_err_inject = 1;
    // drive valid and wait for ready
    #45 tx_valid = 1;
    wait ( tx_valid && tx_ready );
    // data assumed transferred so de-assert valid
    @( posedge clk )
      tx_valid = 0;

    #600 $stop();
  end

  // simple block that looks for transmits
  always @( posedge clk )
    if( tx_valid && tx_ready )
      $display( $time, ": wrote    %028b to transmitter", tx_data );

  // simple block that looks for receives
  always @( posedge clk )
    if( rx_valid )
      $display( $time, ": received %028b from receiver: %s", rx_data,
        rx_err ? "ERROR" : "CHECK OK" );

  // start is connected between the transmitter and the receiver, however, the
  // serial data is not; this is to model a channel that introduces errors; the
  // XOR will flip the bit when err_inject is a 1 and keep it the same when it's
  // a zero
  assign rx_ser_data = tx_ser_data ^ err_inject;

  /**************************************************************/
  /*
   * This is where you'll make your changes.  Adjust the points at which an
   * error is injected to "fool" the parity 2D checking scheme.
   */
  // assert err_inject according to a schedule that is provided by a free
  // running counter; the numbers selected were arbitrary
  always @*
    if( en_err_inject )
      if( err_cnt == 37  || err_cnt == 38|| err_cnt == 45 || err_cnt== 46 )
        err_inject = 1;
      else
        err_inject = 0;
    else
      err_inject = 0;
  /**************************************************************/

  // this is the free running clock that the error injection logic uses to
  // determine when to flip a bit in the channel
  always @( posedge clk )
    if( rst )
      err_cnt <= 0;
    else
      err_cnt <= err_cnt + 1;

  transmitter tx_DUT (
    .rst( rst ),
    .clk( clk ),
    .data( tx_data ),
    .valid( tx_valid ),
    .ready( tx_ready ),
    .start( start ),
    .ser_data( tx_ser_data )
  );

  receiver rx_DUT (
    .rst( rst ),
    .clk( clk ),
    .start( start ),
    .ser_data( rx_ser_data ),
    .data( rx_data ),
    .valid( rx_valid ),
    .err( rx_err )
  );

endmodule

/**************************************************************/
/* Reusable component: counter with terminal count            */
/**************************************************************/
module counter_tc #(
  parameter WIDTH=16
) (
  input                  rst,
  input                  clk,
  input      [WIDTH-1:0] tc_cmp,
  input                  load,
  input      [WIDTH-1:0] init_val,
  input                  en,
  input                  inc_ndec,
  output reg [WIDTH-1:0] count,
  output                 tc
);

  always @( posedge clk )
  begin
    if( rst )
      count <= 0;
    else
      if( load )
        count <= init_val;
      else
        if( en )
          if( inc_ndec )
            count <= count + 1;
          else
            count <= count - 1;
        else
          count <= count;
  end

  assign tc = ( count == tc_cmp );

endmodule

/**************************************************************/
/* Reusable component: even parity bit generator              */
/**************************************************************/
module even_pgen #(
  parameter WIDTH=7
) (
  input  [WIDTH-1:0] din,
  output             even_parity
);

  // this operation produces a single bit that is the XOR over the input
  assign even_parity = ^din;

endmodule


/**************************************************************/
/* Transmitter                                                */
/**************************************************************/
module transmitter (
  // active high synchronous reset
  input         rst,
  input         clk,

  // input side with valid/ready handshake
  input  [27:0] data,
  input         valid,
  output        ready,

  // output side serial data
  output        start,
  output        ser_data
);

  wire capture, init, dec, shift, tc;

  tx_datapath dp (
    .rst( rst ),
    .clk( clk ),
    .data( data ),
    .ser_data( ser_data ),
    .capture( capture ),
    .init( init ),
    .dec( dec ),
    .shift( shift ),
    .tc( tc )
  );

  tx_controller ct (
    .rst( rst ),
    .clk( clk ),
    .valid( valid ),
    .ready( ready ),
    .start( start ),
    .capture( capture ),
    .init( init ),
    .dec( dec ),
    .shift( shift ),
    .tc( tc )
  );

endmodule

// This register takes a word of data as input and adds a parity bit upon
// parallel capture; the device also accepts a serial input bit so as to support
// chaining multiple together
module parity_piso_reg #(
  parameter WIDTH=7
) (
  input              rst,
  input              clk,
  input              ser_in,
  input  [WIDTH-1:0] din,
  input              load,
  input              shift,
  output             ser_out
);

  // internally we have a WIDTH wide register
  reg [WIDTH:0] piso;
  wire parity;

  // this is an instance of the logic that generates a parity bit for the data
  // that are coming in as parallel data to the register;
  even_pgen #( .WIDTH(WIDTH) )
    pgen ( din, parity );

  // this is the PISO itself; the only real difference between this and ones
  // that we've seen before is that this one has a serial input bit, too;
  // instead of just pulling in a zero we can pull in another bit so that we can
  // chain many of these together
  always @( posedge clk )
  begin
    if( rst )
      piso <= 0;
    else
      if( load )
        piso <= { parity, din };
      else
        if( shift )
          piso <= { ser_in, piso[WIDTH:1] };
        else
          piso <= piso;
  end

  // this is the single bit serial output downstream
  assign ser_out = piso[0];

endmodule

/* Transmitter datapath                                       */
module tx_datapath (
  // top level signals connected to datapath
  input         rst,
  input         clk,
  input  [27:0] data,
  output        ser_data,

  // internal signals to and from the controller
  input         capture,
  input         init,
  input         dec,
  input         shift,
  output        tc
);

  // to chain the registers together
  wire [3:0] carry;
  wire [6:0] col_parity;

  // just a placeholder for the counter
  wire [5:0] count;

  // in order to use the generic counter we need to work out what the value of
  // the enable and increment/decrement; the counter needs an enable to cause
  // the value to change and the inc_ndec signal to tell it which way to count;
  // the counter expects an active low decrement on inc_ndec but we use an
  // active high signal on dec, so we must invert it.
  counter_tc #( .WIDTH( 6 ) )
    shift_counter (
      .rst( rst ),
      .clk( clk ),
      .tc_cmp( 6'd0 ),
      .load( init ),
      .init_val( 6'd40 ),
      .en( dec ),
      .inc_ndec( !dec ),
      .count( count ),
      .tc( tc )
    );

  // least significant character
  parity_piso_reg #( .WIDTH( 7 ) )
    d0 (
      .rst( rst ),
      .clk( clk ),
      .ser_in( carry[0] ),
      .din( data[6:0] ),
      .load( capture ),
      .shift( shift ),
      .ser_out( ser_data )
    );

  parity_piso_reg #( .WIDTH( 7 ) )
    d1 (
      .rst( rst ),
      .clk( clk ),
      .ser_in( carry[1] ),
      .din( data[13:7] ),
      .load( capture ),
      .shift( shift ),
      .ser_out( carry[0] )
    );

  parity_piso_reg #( .WIDTH( 7 ) )
    d2 (
      .rst( rst ),
      .clk( clk ),
      .ser_in( carry[2] ),
      .din( data[20:14] ),
      .load( capture ),
      .shift( shift ),
      .ser_out( carry[1] )
    );

  // most significant character
  parity_piso_reg #( .WIDTH( 7 ) )
    d3 (
      .rst( rst ),
      .clk( clk ),
      .ser_in( carry[3] ),
      .din( data[27:21] ),
      .load( capture ),
      .shift( shift ),
      .ser_out( carry[2] )
    );

  // there are clever ways to implement the column parity just like there are
  // more generic or parametetizable ways too;  this is just a simple brute
  // force way of generating the column parity word
  assign col_parity = {
    { data[27] ^ data[20] ^ data[13] ^ data[6] },
    { data[26] ^ data[19] ^ data[12] ^ data[5] },
    { data[25] ^ data[18] ^ data[11] ^ data[4] },
    { data[24] ^ data[17] ^ data[10] ^ data[3] },
    { data[23] ^ data[16] ^ data[ 9] ^ data[2] },
    { data[22] ^ data[15] ^ data[ 8] ^ data[1] },
    { data[21] ^ data[14] ^ data[ 7] ^ data[0] }
  };

  // parity character
  parity_piso_reg #( .WIDTH( 7 ) )
    dp (
      .rst( rst ),
      .clk( clk ),
      .ser_in( 1'b0 ),
      .din( col_parity ),
      .load( capture ),
      .shift( shift ),
      .ser_out( carry[3] )
    );

endmodule

/* Transmitter controller                                     */
module tx_controller (
  // top level signals connected to controller
  input      rst,
  input      clk,
  input      valid,
  output reg ready,
  output reg start,

  // internal signals connected to controller
  output reg capture,
  output reg init,
  output reg dec,
  output reg shift,
  input      tc
);

  localparam WAIT_ON_VALID = 0;
  localparam ISSUE_START   = 1;
  localparam SHIFT_DATA    = 2;

  reg [1:0] cstate, nstate;

  always @( posedge clk )
    if( rst )
      cstate <= WAIT_ON_VALID;
    else
      cstate <= nstate;

  always @*
  begin

    /* we can include defaults at the top of the procedural block so that we
     * don't have to put values for each in each of the states; simplifies what
     * we have to write for each state since we only need to include the values
     * that are different from the default */
    ready   = 0;
    start   = 0;
    capture = 0;
    init    = 0;
    dec     = 0;
    shift   = 0;

    case( cstate )

      WAIT_ON_VALID : begin
        ready   = 1;
        capture = 1;
        init    = 1;
        if( valid )
          nstate = ISSUE_START;
        else
          nstate = WAIT_ON_VALID;
      end

      ISSUE_START : begin
        start  = 1;
        dec    = 1;
        nstate = SHIFT_DATA;
      end

      SHIFT_DATA : begin
        shift = 1;
        dec   = 1;
        if( tc )
          nstate = WAIT_ON_VALID;
        else
          nstate = SHIFT_DATA;
      end

      default : begin
        nstate = WAIT_ON_VALID;
      end

    endcase
  end

endmodule

/*************************************************************/
/* Receiver                                                  */
/*************************************************************/
module receiver (
  // active high synchronous reset
  input         rst,
  input         clk,

  // input side serial data
  input         start,
  input         ser_data,

  // output side data pulse
  output [27:0] data,
  output        valid,
  output        err
);

  wire init, dec, shift, tc;

  rx_datapath dp (
    .rst( rst ),
    .clk( clk ),
    .ser_data( ser_data ),
    .data( data ),
    .err( err ),
    .init( init ),
    .dec( dec ),
    .shift( shift ),
    .tc( tc )
  );

  rx_controller ct (
    .rst( rst ),
    .clk( clk ),
    .start( start ),
    .valid( valid ),
    .init( init ),
    .dec( dec ),
    .shift( shift ),
    .tc( tc )
  );

endmodule

/* Receiver datapath                                          */
module rx_datapath (
  // top level signals connected to datapath
  input         rst,
  input         clk,
  input         ser_data,
  output [27:0] data,
  output        err,

  // internal signals to and from the controller
  input         init,
  input         dec,
  input         shift,
  output        tc
);

  reg  [39:0] sipo;
  wire [ 5:0] count;
  wire row_parity_err, col_parity_err;

  // unlike the transmitter this is brute force implementation of the receiver
  // creating a common SIPO shift register and building the parity checking;
  // note that there is no flexibility in the design as it hardcodes the bits
  // that are used in the parity generation and comparison
  always @( posedge clk )
    if( rst )
      sipo <= 0;
    else
      if( shift )
        sipo <= { ser_data, sipo[39:1] };
      else
        sipo <= sipo;

  // peeling off the bits for the output data
  assign data = {
    sipo[30:24],
    sipo[22:16],
    sipo[14: 8],
    sipo[ 6: 0]
  };

  // OR-together all row parity
  assign row_parity_err = 
    ( sipo[39] != ^sipo[38:32] ) |
    ( sipo[31] != ^sipo[30:24] ) |
    ( sipo[23] != ^sipo[22:16] ) |
    ( sipo[15] != ^sipo[14: 8] ) |
    ( sipo[ 7] != ^sipo[ 6: 0] );

  // determine column parity error
  assign col_parity_err =
    ( sipo[32] != ^{ sipo[24], sipo[16], sipo[ 8], sipo[ 0] } ) |
    ( sipo[33] != ^{ sipo[25], sipo[17], sipo[ 9], sipo[ 1] } ) |
    ( sipo[34] != ^{ sipo[26], sipo[18], sipo[10], sipo[ 2] } ) |
    ( sipo[35] != ^{ sipo[27], sipo[19], sipo[11], sipo[ 3] } ) |
    ( sipo[36] != ^{ sipo[28], sipo[20], sipo[12], sipo[ 4] } ) |
    ( sipo[37] != ^{ sipo[29], sipo[21], sipo[13], sipo[ 5] } ) |
    ( sipo[38] != ^{ sipo[30], sipo[22], sipo[14], sipo[ 6] } );

  // error is if either the row parity or column parity check are in error
  assign err = row_parity_err | col_parity_err;

  // another example of the counter instantiation that needs modification to
  // ensure that we get the behavior that we want
  counter_tc #( .WIDTH( 6 ) )
    shift_counter (
      .rst( rst ),
      .clk( clk ),
      .tc_cmp( 6'd1 ),
      .load( init ),
      .init_val( 6'd40 ),
      .en( dec ),
      .inc_ndec( !dec ),
      .count( count ),
      .tc( tc )
    );

endmodule

/* Receiver controller                                        */
module rx_controller (
  // top level signals connected to controller
  input      rst,
  input      clk,
  input      start,
  output reg valid,

  // internal signals connected to controller
  output reg init,
  output reg dec,
  output reg shift,
  input      tc
);

  localparam WAIT_ON_START = 0;
  localparam SHIFT_DATA    = 1;
  localparam SEND_DATA     = 2;

  reg [1:0] cstate, nstate;

  always @( posedge clk )
    if( rst )
      cstate <= WAIT_ON_START;
    else
      cstate <= nstate;

  always @*
  begin

    // set defaults so that states only show changes
    valid = 0;
    init  = 0;
    dec   = 0;
    shift = 0;

    case( cstate )

      WAIT_ON_START : begin
        init = 1;
        if( start )
          nstate = SHIFT_DATA;
        else
          nstate = WAIT_ON_START;
      end

      SHIFT_DATA : begin
        shift = 1;
        dec   = 1;
        if( tc )
          nstate = SEND_DATA;
        else
          nstate = SHIFT_DATA;
      end

      SEND_DATA : begin
        valid  = 1;
        nstate = WAIT_ON_START;
      end

      default : begin
        nstate = WAIT_ON_START;
      end

    endcase

  end

endmodule
