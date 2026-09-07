//AUTHOR: RYAN FAREKH
module dff
  (
    input clk, rst, din,
    output reg dout
  );
  
  always@(posedge clk)
    begin
      if (rst == 1'b1) begin
        dout <= 1'b0;
      end
      else begin
        dout <= din;
      end
    end
  
  
endmodule

interface dff_if();
  logic din, dout, clk, rst;
endinterface