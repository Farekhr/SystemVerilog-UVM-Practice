class generator;

 

  rand bit [3:0] addr;

  rand bit wr;

  constraint approx {

    (wr==1) -> addr inside {[0:7]};

    (wr==0) -> addr inside {[8:15]};

 

  }

endclass

   module tb;

     generator k;

     int i=0;

     initial begin

       k=new();

       for(i=0; i<20; i++)begin

         k.randomize();

         $display ("values are wr=%0d, addr=%0d", k.wr, k.addr);

         

       end

       end

    endmodule