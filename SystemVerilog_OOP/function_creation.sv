module tb();

     int unsigned a[32];

      function automatic void init_arr(ref int unsigned arr[32]) 
        for (int i = 0; i < 32; i++) begin 
            arr[i] = 8 * i;
        end 
    endfunction 

        initial begin 
            init_arr(a); 
            $display("Array Values: %0p", a) 
        end 

    endmodule