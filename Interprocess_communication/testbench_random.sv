// Code your testbench here

// or browse Examples

class transaction;


rand bit [7:0] a;

rand bit [7:0] b;

rand bit wr;


endclass



class generator;

  transaction t;

  mailbox #(transaction) mbx;
 

  function new(mailbox #(transaction) mbx);

    this.mbx = mbx;

  endfunction

   

  task run();

   

    for (int i=0; i<10; i++) begin

      t = new();

      t.randomize();

      mbx.put(t);

      $display("[GEN] SENT DATA a = %0d, b = %0d, wr = %0d", t.a, t.b, t.wr);

      #10;

    end

  endtask

 

endclass



class driver;

  transaction t;

  mailbox #(transaction) mbx;

 

  function new(mailbox #(transaction) mbx);

    this.mbx = mbx;

  endfunction

   

    task run();

     

      forever begin

      t = new();

      mbx.get(t);

        $display("[DRV] RCVD DATA a = %0d, b = %0d, wr = %0d", t.a, t.b, t.wr);

      end

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

    fork

    g.run();

    d.run();

    join

  end

 

  initial begin

    #250;

    $finish();

  end

 

endmodule