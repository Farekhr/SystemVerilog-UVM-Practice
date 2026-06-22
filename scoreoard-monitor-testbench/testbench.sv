class transaction;
  
  bit [3:0] a, b;
  bit clk;
  reg [7:0] mul;
  
  function void display();
    $display("VALUE of a = %0d, value of b = %0d", this.a, this.b);
  endfunction
  
endclass

interface top_if;
  logic clk;
  logic [3:0] a, b;
  logic [7:0] mul;
  
endinterface

class monitor;
  
  virtual top_if vif;
  mailbox #(transaction) mbx;
  transaction trans;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    trans = new();
    forever begin
      repeat(2) @(posedge vif.clk);
      trans.a = vif.a;
      trans.b = vif.b;
      trans.mul = vif.mul;
      mbx.put(trans);
      $display("[MON] DATA SENT");
      trans.display();
    end
  endtask
  
endclass

class scoreboard;
  
  mailbox #(transaction) mbx;
  transaction trans;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  function void compare(input transaction trans);
    
    if (trans.mul == trans.a * trans.b) $display("[SCO]: DATA MATCH");
    else $error("[SCO]: DATA MISMATCH");
    
  endfunction
  
  task run();
    forever begin
      mbx.get(trans);
      $display("[SCO]: RCDV DATA FROM MONITOR");
      compare(trans);
    end
      
  endtask
  
endclass


module tb;
  
  top_if vif();
  
  top dut (vif.clk, vif.a, vif.b, vif.mul);
  
  mailbox #(transaction) mbx;
  
  monitor mon;
  scoreboard sco;
  
  
  initial begin
    vif.clk <= 0;
  end
  
  always #5 vif.clk <= ~vif.clk;
  
  initial begin
    for(int i = 0; i<20; i++) begin
      repeat (2) @(posedge vif.clk);
      vif.a <= $urandom_range(1,15);
      vif.b <= $urandom_range(1,15);
    end
    
  end
  
  initial begin 
    mbx = new();
    mon = new(mbx);
    sco = new(mbx);
    mon.vif = vif;
  end
  
  initial begin
    fork
      mon.run();
      sco.run();
    join
  end
  
  initial begin
    $dumpfile("dump.vcd");
     $dumpvars;    
    #300;
    $finish();
  end
  
endmodule