module tb;

 

int trigger_count;

 

task Task1;

  forever begin

    #20;

    $display("Task 1 Trigger");

    trigger_count++;

  end

endtask

 

task Task2;

  forever begin

    #40;

    $display("Task 2 Trigger");

    trigger_count++;

  end

endtask
 

task waiter;

  #200;

  #0;

  $display("PROCESS FINISHED, TRIGGER COUNT = %0d", trigger_count);

  $finish();

endtask


initial begin

trigger_count = 0;

   

   fork

     Task1;

     Task2;

     waiter;

   join_any

 

end