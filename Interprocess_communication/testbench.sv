class transaction;


bit [7:0] addr = 7'h12;

bit [3:0] data = 4'h4;

bit we = 1'b1;

bit rst = 1'b0;


endclass



class generator;

  transaction t;

  mailbox #(transaction) mbx;

 

  function new(mailbox #(transaction) mbx);

    this.mbx = mbx;

  endfunction

   

  task run();

      t = new();

      mbx.put(t);

    $display("[GEN] SENT DATA addr = %0d, data = %0d, we = %0d, rst = %0d", t.addr, t.data, t.we, t.rst);

    endtask

 

endclass



class driver;

  transaction t;

  mailbox #(transaction) mbx;

 

  function new(mailbox #(transaction) mbx);

    this.mbx = mbx;

  endfunction

   

    task run();

      t = new();

      mbx.get(t);

      $display("[DRV] RCVD DATA addr = %0d, data = %0d, we = %0d, rst = %0d", t.addr, t.data, t.we, t.rst);

  endtask

 

endclass



module tb;

  generator g;

  driver d;

  mailbox #(transaction) mbx;

 

  initial begin

    mbx = new();

    g = new(mbx);

    d = new(mbx);

   

    g.run();

    d.run();

  end

 

  initial begin

    #250;

    $finish();

  end

 

endmodule