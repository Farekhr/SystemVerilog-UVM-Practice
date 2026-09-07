//AUTHOR: RYAN FAREKH
`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

//TRANSACTION
class transaction extends uvm_sequence_item;
  rand bit din;
  bit dout;
  
  function new(input string path = "transaction");
    super.new(path);
  endfunction
  
  `uvm_object_utils_begin(transaction)
  `uvm_field_int(din, UVM_DEFAULT)
  `uvm_field_int(dout, UVM_DEFAULT)
  `uvm_object_utils_end
  
endclass

//SEQUENCE
class generator extends uvm_sequence#(transaction);
  `uvm_object_utils(generator)
  transaction t;
  
  function new(input string path = "generator");
    super.new(path);
  endfunction
  
 
  virtual task body();
    
    repeat(10) begin
      t = transaction::type_id::create("t");
      start_item(t);
      assert(t.randomize());
      `uvm_info("GEN", $sformatf("Data sent to Driver din: %0b", t.din), UVM_NONE);
      finish_item(t);
    end
  endtask
  
endclass

//DRIVER
class driver extends uvm_driver#(transaction);
    `uvm_component_utils(driver)

    function new(input string path = "driver", uvm_component parent = null);
    super.new(path, parent);
    endfunction

    transaction data;
    virtual dff_if dff;
  
    ///////reset dut
  task reset_dut();
    dff.rst <= 1'b1;
    dff.din <= 0;
    repeat(5) @(posedge dff.clk);
    dff.rst <= 1'b0;
    `uvm_info("DRV", "Reset Done", UVM_NONE);
  endtask

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
      data = transaction::type_id::create("data");

      if(!uvm_config_db #(virtual dff_if)::get(this, "","dff",dff))
        `uvm_error("DRV", "Unable to access uvm_config_db");
    endfunction

    virtual task run_phase(uvm_phase phase);
      reset_dut();
    forever begin
      seq_item_port.get_next_item(data);
        dff.din <= data.din;
      `uvm_info("DRV", $sformatf("Trigger DUT din: %0b", data.din), UVM_NONE);
        seq_item_port.item_done();
      repeat(2)@(posedge dff.clk);
    end
    endtask
endclass

//MONITOR             
class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)
    
    uvm_analysis_port #(transaction) send;
    
    function new(input string path = "monitor", uvm_component parent = null);
    super.new(path, parent);
    send = new ("send", this);
    endfunction
    
    transaction t;
    virtual dff_if dff;
    
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    t = transaction::type_id::create("t");

      if(!uvm_config_db #(virtual dff_if)::get(this, "","dff", dff))
        `uvm_error("MON", "Unable to access uvm_config_db");
    endfunction
    
    virtual task run_phase(uvm_phase phase);
      @(negedge dff.rst);
    forever begin 
      repeat(2)@(posedge dff.clk);
        t.din = dff.din;
        t.dout = dff.dout;
      `uvm_info("MON", $sformatf("Data sent to Scoreboard dout: %0b", t.dout), UVM_NONE);
        send.write(t);
    end
    
    endtask
endclass

//SCOREBOARD
class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)
    
    uvm_analysis_imp #(transaction, scoreboard) recv;
    transaction data;
    
    function new(input string path = "scoreboard", uvm_component parent = null);
    super.new(path, parent);
    recv = new("Read", this);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
      data = transaction::type_id::create("data");
    endfunction
    
    virtual function void write(input transaction t);
    data = t;
      `uvm_info("SCO", $sformatf("Data recieved from monitor din: %0b, dout: %0b", data.din, data.dout), UVM_NONE);
    
      if(data.dout == data.din)
        `uvm_info("SCO", "Test Passed", UVM_NONE)
    else 
        `uvm_info("SCO", "Test Failed", UVM_NONE)
    endfunction
endclass
    
//AGENT
class agent extends uvm_agent;
    `uvm_component_utils(agent)
    
    function new(input string inst = "AGENT", uvm_component c);
    super.new(inst, c);
    endfunction
    
    monitor m;
    driver d;
    uvm_sequencer #(transaction) seqr;
    
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m = monitor::type_id::create("m", this);
    d = driver::type_id::create("d", this);
    seqr = uvm_sequencer #(transaction)::type_id::create("seqr", this);
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    d.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

//ENVIRONMENT
class env extends uvm_env;
    `uvm_component_utils(env)
    
    function new(input string inst = "ENV", uvm_component c);
    super.new(inst, c);
    endfunction
    
    scoreboard s;
    agent a;
    
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    s = scoreboard::type_id::create("s", this);
    a = agent::type_id::create("a", this);
    
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    a.m.send.connect(s.recv);
    endfunction
endclass

//TEST
class test extends uvm_test;
    `uvm_component_utils(test)          
                    
    function new(input string inst = "TEST", uvm_component c);
    super.new(inst, c);
    endfunction         
    
    generator gen;
    env e;
                    
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    gen = generator::type_id::create("gen", this);
    e = env::type_id::create("e", this);
    
    endfunction                
                
    virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
      gen.start(e.a.seqr);
      #60;
    phase.drop_objection(this);
    endtask
endclass
    

//TB TOP
module dff_tb();
    
    dff_if dff();
  
  initial begin
    dff.clk = 0;
    dff.rst = 0;
  end
  
  always #10 dff.clk = ~dff.clk;
    
  dff dut (.din(dff.din), .clk(dff.clk), .rst(dff.rst), .dout(dff.dout));
    
    initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    end
    
    initial begin
      uvm_config_db #(virtual dff_if)::set(null, "*", "dff", dff);
    run_test("test");
    end
endmodule