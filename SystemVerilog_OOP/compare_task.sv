module tb;

function int unsigned mult (input int unsigned a, b);

return a * b;

endfunction

initial begin

int unsigned a = 2;

int unsigned b = 3;

int unsigned res = adder(a, b);

if (res == 6) begin

$display("Test Passed");

end

else begin

$display("Test Failed");

end

end

endmodule