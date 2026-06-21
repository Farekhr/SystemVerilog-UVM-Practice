class first;

  bit[7:0] a, b, c;

  function new(input bit[7:0] data1, data2, data3);

    a = data1;

    b = data2;

    c = data3;

  endfunction

endclass



module tb();

  bit[7:0] x = 8'd2;

  bit[7:0] y = 8'd4;

  bit[7:0] z = 8'd56;

 

initial begin

  first f1;

  f1 = new(x, y, z);

      $display("data1: %0d, data2: %0d, data3: %0d", f1.a, f1.b, f1.c);

    end

endmodule