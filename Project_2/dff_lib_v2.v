module dff #(
  parameter WIDTH=4
) (
  input rst_n, clk,
  input [WIDTH-1:0] D,
  output reg [WIDTH-1:0] Q
);

  always @( posedge clk )
  begin
    if( !rst_n )
      Q <= 0;
    else
      Q <= D;
  end

endmodule

module dff_en #(
  parameter WIDTH=4
) (
  input rst_n, en, clk,
  input [WIDTH-1:0] D,
  output reg [WIDTH-1:0] Q
);

  always @( posedge clk )
  begin
    if( !rst_n )
      Q <= 0;
    else
      if( en )
        Q <= D;
      else
        Q <= Q;
  end

endmodule

/*
 * DFF with a parameterizeable reset value
 */

module dff_rstval #(
  parameter WIDTH=4,
  parameter RSTVAL=0
) (
  input rst_n, clk,
  input [WIDTH-1:0] D,
  output reg [WIDTH-1:0] Q
);

  always @( posedge clk )
  begin
    if( !rst_n )
      Q <= RSTVAL;
    else
      Q <= D;
  end

endmodule

module dff_rstval_tb;

  reg rst_n, clk;
  wire [3:0] Q [0:3];

  dff_rstval #(
    .WIDTH(4),
    .RSTVAL(0)
  ) DUT_0 (
    .rst_n(rst_n),
    .clk(clk),
    .D(4'b0001),
    .Q(Q[0])
  );

  dff_rstval #(
    .WIDTH(4),
    .RSTVAL(1)
  ) DUT_1 (
    .rst_n(rst_n),
    .clk(clk),
    .D(4'b0010),
    .Q(Q[1])
  );

  dff_rstval #(
    .WIDTH(4),
    .RSTVAL(15)
  ) DUT_2 (
    .rst_n(rst_n),
    .clk(clk),
    .D(4'b0100),
    .Q(Q[2])
  );

  dff_rstval #(
    .WIDTH(4),
    .RSTVAL(5)
  ) DUT_3 (
    .rst_n(rst_n),
    .clk(clk),
    .D(4'b1000),
    .Q(Q[3])
  );

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
        rst_n = 0;
    #10 rst_n = 1;
  end

  initial begin
    $monitor( $time, ": %04b %04b %04b %04b",
      Q[0], Q[1], Q[2], Q[3] );

    #20 $stop;
  end
endmodule
