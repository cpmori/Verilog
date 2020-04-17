module adler32(
	input clock,
	rst_n,
	data_valid,
	last_data,
	input [7:0] data,
	output checksum_valid
	output [31:0] checksum_valid
);
	
	datapath D1();
	controller C1();
	
endmodule


module datapath(
	input[7:0] data,
	input clk,rst_n, 
	output[31:0] checksum
);

	wire[15:0] current_A,current_B, next_A, next_B, sum_A, sum_B, mod_A, mod_B;
	
	assign sum_A = data + current_A;
	assign sum_B = current_B + next_A;
	
	modulus mod1(
		.dividend(sum_A),
		.divisor(65521),
		.result(mod_A)
	);
	
	modulus mod1(
		.dividend(sum_B),
		.divisor(65521),
		.result(mod_B)
	);
	
	dff_rstval #(
		.WIDTH(16),
		.RSTVAL(1))
	A(.rst_n(rst_n), .clk(clock),.D(next_A),.Q(current_A));
	
	dff_rstval #(
		.WIDTH(16),
		.RSTVAL(0))
	B(.rst_n(rst_n), . clk(clock), .D(next_B), .Q(current_B));
	
	assign next_A = data_valid ? mod_A : current_A;
	assign next_B = data_valid ? mod_B : current_B;
	
	assign checksum[15:0] = current_A;
	assign checksum[31:16] = current_B;
	

endmodule


module controller(
	input clk, rst_n, last_data,
	output checksum_valid
);	

	wire current_state,next_state;
	
	dff #(.WIDTH(1)) DFF(
		.rst_n(rst_n),
		.clk(clk),
		.D(next_state),
		.Q(current_state)
	);
	
	assign next_state = last_data & ~(current_state);
	assign checksum_valid = current_state;

endmodule
	
module modulus(
	input[15:0] dividend,
	input[31:0] divisor,
	output[15:0] result
);
	wire[31:0] sign_extend;
	assign sign_extend[31:16] = 0;
	assign sign_extend[15:0] = dividend; 
	assign result = (sign_extend - divisor < 0) ? (sign_extend - divisor) : dividend;

endmodule
	
	
	
	
	
	
	
	
	
	