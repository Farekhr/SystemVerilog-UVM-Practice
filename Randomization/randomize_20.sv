class prob;

    randc bit  [7:0] x,y,z;

endclass



module tb;

  prob k;

  int i=0;

  initial

    begin

      k=new();

    for(i=0; i<=20; i++)

      begin

        k.randomize();

       

   

      $display ("the values are x=%d, y=%d,z=%d", k.x,k.y, k.z);

        #20;

      end

  end

endmodule