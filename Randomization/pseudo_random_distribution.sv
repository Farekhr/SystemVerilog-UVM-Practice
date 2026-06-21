class generator;

 

  rand bit rst;

  rand bit wr;

  constraint approx {

    rst dist { 0:=30, 1:=70};

    wr dist {  0:=50, 1:=50};

 

  }

endclass

   module tb;

     generator k;

     int i =0;

     initial begin

       k=new();

       for(i=0; i<20; i++)begin

         k.randomize();

         $display ("values are wr=%0d, rst=%0d", k.wr, k.rst);

         

       end

       end

    endmodule