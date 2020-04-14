module adler32_acc(
	input clk, rst_n, 
	input[7:0] data,
	output[31:0] checksum
);


	wire[15:0] next_A, current_A, A_Sum, next_B, current_B, B_Sum;
	
	assign A_Sum = data + current_A;
	assign B_Sum = next_A + current_B;

	modulus mod1(
		.dividend(A_Sum),
		.divisor(65521),
		.result(next_A)
	);

	modulus mod2(
		.dividend(B_Sum),	
		.divisor(65521),
		.result(next_B)
	);


	dff_rstval #(
		.WIDTH(16),
		.RSTVAL(1)) 
	A(.rst_n(rst_n),.clk(clk),.D(next_A),.Q(current_A));

	dff_rstval #(
		.WIDTH(16),
		.RSTVAL(0))
	B(.rst_n(rst_n),.clk(clk),.D(next_B),.Q(current_B));

	assign checksum[15:0] = current_A;
	assign checksum[31:16] = current_B;

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
