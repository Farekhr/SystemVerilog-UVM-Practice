class first;

  bit[3:0] a, b, c, result;

  function new(input bit[7:0] data1, data2, data3);

    a = data1;

    b = data2;

    c = data3;

  endfunction

 

  task add_and_disp(output bit[3:0] result);

    result = a + b + c;

    $display("a: %0d, b: %0d, c: %0d, result:, %0d", a, b, c, result);

  endtask

endclass



module tb();

  bit[3:0] x = 4'd1;

  bit[3:0] y = 4'd2;

  bit[3:0] z = 4'd4;

  bit[3:0] result;

 

initial begin

  first f1;

  f1 = new(x, y, z);

      f1.add_and_disp(result);

    end

endmodule