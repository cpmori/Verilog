module checksum_compiler(
	input[15:0] in1, in2,
	input clk, rst_n, data_valid,
	output[15:0] comp_val
);

	wire[15:0] Asum,Anew,next_A,Aold;
	
	assign Asum = in1 + in2;
	
//	modulus new_A(
//		output Anew;
//	);
	
	assign next_A = data_valid ? Anew : Aold;
	
	
	
	

endmodule

module moduluo(
	input[15:0] dividend, divisor, 
	output[15:0] result
);

	wire[15:0] difference;
	
	assign difference = dividend - divisor;
	
	assign result = (difference[15] == 1) ? dividend : difference;
	


endmodule

module modulus_tb;

	reg[15:0] val1, val2;
	wire[15:0] result;
	
	modulus DUT(
		.dividend(val1),
		.divisor(val2),
		.result(result)
	);
	initial 
	begin
		$monitor($time, ":%d mod %d = %d",val1,val2,result);
		
		val1 =16'hFFFF;
		val2 = 65521;
		
		#10
		
		val1 = 500;
		val2 = 400;
		
		#10 
		
		val1 = 5655;
		val2 = 5000;
		
		#10
		$stop;
	
	end
endmodule
	
	
module edge_tb;
	reg rst_n,clk;
	reg last_data, data_valid;
	reg[7:0] data;

	wire checksum_valid;
	wire[31:0] checksum;

	adler32 DUT (
		.rst_n(rst_n),
		.clock(clk),
		.data_valid(data_valid),
		.data(data),
		.last_data(last_data),
		.checksum_valid(checksum_valid),	
		.checksum(checksum)
	);

	always #5 clk = ~clk;

	initial 
	begin
		$monitor($time, ": checksum is %08h",checksum);
		data_valid = 1;
		last_data = 0;
		data = 8'hCC;
		rst_n = 0;
		clk = 0;
	#20	rst_n = 1;
//	#50	data = 8'hFF;		
	#3500
		last_data = 1;	
	
	#10 $stop;
	end
endmodule 
