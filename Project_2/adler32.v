module adler32(
	input clock,
	rst_n,
	data_valid,
	last_data,
	input [7:0] data,
	output checksum_valid,
	output [31:0] checksum
);	
	wire brief_reset;
	datapath D1(
		.data(data),
		.clk(clock),
		.rst_n(rst_n & brief_reset),
		.checksum(checksum),
		.data_valid(data_valid)
	);
	controller C1(
		.clk(clock), 
		.rst_n(rst_n),
		.last_data(last_data),
		.checksum_valid(checksum_valid),
		.brief_reset(brief_reset)
	);
	
endmodule


module datapath(
	input[7:0] data,
	input clk,rst_n, data_valid,
	output[31:0] checksum
);

	wire[15:0] old_A,old_B, next_A, next_B, sum_A, sum_B, new_A, new_B;
	
	assign sum_A = data + old_A;
	assign sum_B = old_B + new_A;
	
	modulus mod1(
		.dividend(sum_A),
		.divisor(65521),
		.result(new_A)
	);
	
	modulus mod2(
		.dividend(sum_B),
		.divisor(65521),
		.result(new_B)
	);
	
	dff_rstval #(.WIDTH(16),.RSTVAL(1))A(
		.rst_n(rst_n), 
		.clk(clk),
		.D(next_A),
		.Q(old_A)
	);
	
	dff_rstval #(.WIDTH(16),.RSTVAL(0))B(
		.rst_n(rst_n), 
		.clk(clk), 
		.D(next_B), 
		.Q(old_B)
	);
	
	
		
	assign next_A = data_valid ? new_A: old_A;
	assign next_B = data_valid ? new_B: old_B;
	
	assign checksum[15:0] = old_A;
	assign checksum[31:16] = old_B;
	

endmodule

module controller(
	input clk, rst_n, last_data,
	output checksum_valid,brief_reset
);	

	wire[1:0] current_state,next_state;
	
	dff #(.WIDTH(2)) DFF(
		.rst_n(rst_n),
		.clk(clk),
		.D(next_state),
		.Q(current_state)
	);
	
	assign next_state[0] = last_data & ~current_state[1] & ~current_state[0];
	assign next_state[1] = current_state[0];
	assign checksum_valid = ~current_state[1] & current_state[0];
	assign brief_reset = ~current_state[1];

endmodule
	
module modulus(
	input[15:0] dividend,
	input[15:0] divisor,
	output[15:0] result
);
	wire[15:0] difference;

	assign difference = dividend - divisor;

	assign result = (divisor > dividend) ? dividend : difference; 

endmodule
	
		
	
	
	
	
	
	
