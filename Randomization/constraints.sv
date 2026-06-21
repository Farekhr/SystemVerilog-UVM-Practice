class generator;

 

  rand bit [4:0] a;

  rand bit [5:0] b;

  constraint race {

    a inside {[0:8]};

    b inside {[0:5]};

  }


 

endclass



module tb;

  generator k;

 

  int i =0;

 

  int err_cnt=0;

  initial begin

    k=new(); 

    for (i=0; i<20; i++) begin

      if (!k.randomize())begin

        err_cnt++;

        $display("Randomization failed");

      end

        else

          begin

            $display("values are : a=%0d,b=%0", k.a,k.b);

          end

    end

    $display("Error Count = %0d", err_cnt);

  end

endmodule