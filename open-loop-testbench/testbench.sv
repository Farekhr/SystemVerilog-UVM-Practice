// Code your testbench here
// or browse Examples
class transaction;
 
  randc bit [3:0] a;
  randc bit [3:0] b;
  bit clk;
  reg [7:0] mul;
  
  function void display();
    $display("VALUE OF A = %0d, VALUE OF B = %0d, VALUE OF MUL = %0d", a, b, mul);
  endfunction
  
  function transaction copy();
    copy = new();
    copy.a = this.a;
    copy.b = this.b;
    copy.mul = this.mul;
    copy.clk = this.clk;
    
  endfunction
 
endclass

interface top_if();
  
  logic clk;
  logic [3:0] a,b;
  reg [7:0] mul;
  
endinterface

class generator;
  
  transaction trans;
  mailbox #(transaction) mbx;
  event done;
  
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    trans = new();
  endfunction
  
  task run();
    for (int i = 0; i < 10; i++) begin
      trans.randomize();
      mbx.put(trans.copy);
      $display("[GEN] SENT DATA");
      trans.display();
      #20;
    end
    -> done;
  endtask  
endclass

class driver;
  
  transaction data;
  mailbox #(transaction) mbx;
  
  virtual top_if tif;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    forever begin
      mbx.get(data);
      $display("[DRV] RCVD DATA AND INTERFACE TRIGGER");
      @(posedge tif.clk) begin
      tif.a <= data.a;
      tif.b <= data.b;
      end
      
    end
  endtask 
  
endclass

module tb;
  
  top_if tif();
  generator gen;
  driver drv;
  mailbox #(transaction) mbx;
  event done;
  
  top dut (.a(tif.a), .b(tif.b), .mul(tif.mul), .clk(tif.clk));
  
  always #10 tif.clk <= ~tif.clk;
  
  initial begin 
    tif.clk <= 0;  
  end
  
  initial begin
    mbx = new();
    gen = new(mbx);
    drv = new(mbx);
    drv.tif = tif;
    done = gen.done;
  end
  
  initial begin 
    fork 
      gen.run();
      drv.run();      
    join_none
    wait(done.triggered);
    $finish();
  end
  
    initial begin
    $dumpfile("dump.vcd"); 
    $dumpvars;  
  end
  
endmodule