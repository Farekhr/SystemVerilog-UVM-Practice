class generator;

 

  bit [3:0] a = 5,b =7;

  bit wr = 1;

  bit en = 1;

  bit [4:0] s = 12;

 

  function void display();

    $display("a:%0d b:%0d wr:%0b en:%0b s:%0d", a,b,wr,en,s);

  endfunction

 

  function generator copy();

    copy = new();

    copy.a = a;

    copy.b = b;

    copy.wr = wr;

    copy.en = en;

    copy.s = s;

  endfunction


endclass



module tb();

  generator g1;

  generator g2;

  initial begin

    g1 = new();

    g2 = g1.copy();

    g2.display();

    //$display("g1 members: a: %0d, b: %0d, wr: %0d, en: %0d, s: %0d", g2.a, g2.b, g2.wr, g2.en, g2.s);

  end

endmodule