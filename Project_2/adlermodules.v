module checksum_compiler(
	input[15:0] in1, in2,
	input clk, rst_n, data_valid,
	output[15:0] comp_val
);

	wire[15:0] Asum,Anew,next_A,Aold;
	
	assign Asum = in1 + in2;
	
	modulus new_A(
		output Anew;
	);
	
	assign next_A = data_valid ? Anew : Aold;
	
	
	
	

endmodule

module modulus(
	input[15:0] dividend, divisor, 
	output[15:0] result
);

	wire[15:0] difference;
	
	assign difference = dividend - divisor;
	
	assign result = (difference > 0 ) ? difference : dividend;
	


endmodule

module modulus_tb;

	reg[15:0] val1, val2;
	wire[15:0] result;
	
	modulud DUT(
		.dividend(val1),
		.divisor(val2),
		.result(result)
	);
	initial 
	begin
		$monitor($time, ": mod value %16b",result);
		
		val1 = 52;
		val2 = 50;
		
		#10
		
		val1 = 500;
		val2 = 400;
		
		#10 
		
		val1 = 145655;
		val2 = 140000;
		
		#10
		$stop
	
	end
endmodule
	
	
	
	
	
	
	
	
	
	

endmodule 