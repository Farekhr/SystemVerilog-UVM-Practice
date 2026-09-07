//AUTHOR: RYAN FAREKH
`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

//TRANSACTION
class transaction extends uvm_sequence_item;
  rand bit din;
  bit      dout;

  function new(input string path = "transaction");
    super.new(path);
  endfunction

  `uvm_object_utils_begin(transaction)
  `uvm_field_int(din, UVM_DEFAULT)
  `uvm_field_int(dout, UVM_DEFAULT)
  `uvm_object_utils_end
  bit      prev_din;
  rand bit toggle;

  constraint c_toggle_rate {
    toggle dist { 1'b1 := 60, 1'b0 := 40 };
  }

  constraint c_din_follows_toggle {
    din == (toggle ? ~prev_din : prev_din);
  }

endclass

//SEQUENCE
class generator extends uvm_sequence#(transaction);
  `uvm_object_utils(generator)
  transaction t;

  rand int unsigned n_txn;
  constraint c_n { n_txn inside {[30:50]}; }

  bit last_din;

  function new(input string path = "generator");
    super.new(path);
  endfunction

  virtual task body();
    repeat(n_txn) begin
      t = transaction::type_id::create("t");
      start_item(t);
      t.prev_din = last_din;
      if(!t.randomize())
        `uvm_error("GEN", "Randomization failed")
      last_din = t.din;
      `uvm_info("GEN", $sformatf("Data sent to Driver din: %0b", t.din), UVM_NONE);
      finish_item(t);
    end
  endtask

endclass

// Directed walk guaranteeing all four transitions: 0->0, 0->1, 1->1, 1->0.
class toggle_seq extends uvm_sequence#(transaction);
  `uvm_object_utils(toggle_seq)
  transaction t;

  function new(input string path = "toggle_seq");
    super.new(path);
  endfunction

  virtual task body();
    bit pattern [] = '{1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0};
    foreach (pattern[i]) begin
      t = transaction::type_id::create("t");
      start_item(t);
      if(!t.randomize() with { din == pattern[i]; })
        `uvm_error("TOGGLE", "Randomization failed")
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
    `uvm_info("DRV", "Reset Done", UVM_LOW);
  endtask

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
      data = transaction::type_id::create("data");

      if(!uvm_config_db #(virtual dff_if)::get(this, "","dff",dff))
        `uvm_fatal("DRV", "Unable to access uvm_config_db");
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

    virtual dff_if dff;

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

      if(!uvm_config_db #(virtual dff_if)::get(this, "","dff", dff))
        `uvm_fatal("MON", "Unable to access uvm_config_db");
    endfunction

    virtual task run_phase(uvm_phase phase);
      @(negedge dff.rst);
    forever begin
      repeat(2)@(posedge dff.clk);
        // Fresh object each sample so the scoreboard and the coverage subscriber are not handed the same aliased handle.
        begin
          transaction t = transaction::type_id::create("t");
          t.din  = dff.din;
          t.dout = dff.dout;
          `uvm_info("MON", $sformatf("Data sent to Scoreboard din: %0b dout: %0b",
                                     t.din, t.dout), UVM_NONE);
          send.write(t);
        end
    end

    endtask
endclass

//SCOREBOARD
class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp #(transaction, scoreboard) recv;

    int unsigned n_checked;
    int unsigned n_failed;

    function new(input string path = "scoreboard", uvm_component parent = null);
    super.new(path, parent);
    recv = new("recv", this);
    endfunction

    virtual function void write(input transaction t);
      if ($isunknown({t.din, t.dout})) begin
        `uvm_info("SCO", "Skipping sample with unknown values", UVM_NONE)
        return;
      end

      n_checked++;

      // The driver holds din for two clocks before the next item, so by the sampling point the flop has captured it and dout should match.
      if (t.dout !== t.din) begin
        n_failed++;
        `uvm_error("SCO", $sformatf("MISMATCH: expected dout=%0b, observed dout=%0b",
                                    t.din, t.dout))
      end
      else begin
        `uvm_info("SCO", $sformatf("Match: din=%0b dout=%0b", t.din, t.dout), UVM_NONE)
      end
    endfunction

    virtual function void report_phase(uvm_phase phase);
      `uvm_info("SCO", $sformatf(
        "\n------------- SCOREBOARD SUMMARY -------------\n  comparisons : %0d\n  mismatches  : %0d\n----------------------------------------------",
        n_checked, n_failed), UVM_NONE)

      if (n_checked == 0)
        `uvm_error("SCO", "No comparisons were performed -- stimulus never reached the DUT")
    endfunction
endclass

//COVERAGE
class coverage extends uvm_subscriber #(transaction);
    `uvm_component_utils(coverage)

    transaction cg_t;

    covergroup cg_dff;
      option.per_instance = 1;

      cp_din : coverpoint cg_t.din {
        bins low  = {1'b0};
        bins high = {1'b1};
        bins rise  = (1'b0 => 1'b1);
        bins fall  = (1'b1 => 1'b0);
        bins hold0 = (1'b0 => 1'b0);
        bins hold1 = (1'b1 => 1'b1);
      }

      cp_dout : coverpoint cg_t.dout {
        bins low  = {1'b0};
        bins high = {1'b1};
      }

      x_din_dout : cross cp_din, cp_dout;
    endgroup

    function new(input string path = "coverage", uvm_component parent = null);
      super.new(path, parent);
      cg_dff = new();
    endfunction

    virtual function void write(transaction t);
      if ($isunknown({t.din, t.dout})) return;
      cg_t = t;
      cg_dff.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
      `uvm_info("COV", $sformatf("Functional coverage: %0.2f%%", cg_dff.get_coverage()), UVM_NONE)
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
    if (get_is_active() == UVM_ACTIVE) begin
      d = driver::type_id::create("d", this);
      seqr = uvm_sequencer #(transaction)::type_id::create("seqr", this);
    end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
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
    coverage   cov;
    agent      a;

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    s   = scoreboard::type_id::create("s", this);
    cov = coverage::type_id::create("cov", this);
    a   = agent::type_id::create("a", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    a.m.send.connect(s.recv);
    a.m.send.connect(cov.analysis_export);
    endfunction
endclass

//TEST
class test extends uvm_test;
    `uvm_component_utils(test)

    function new(input string inst = "TEST", uvm_component c);
    super.new(inst, c);
    endfunction

    generator  gen;
    toggle_seq toggles;
    env e;

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    gen     = generator::type_id::create("gen", this);
    toggles = toggle_seq::type_id::create("toggles", this);
    e       = env::type_id::create("e", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
      toggles.start(e.a.seqr);    
      if(!gen.randomize()) `uvm_error("TEST", "Sequence randomization failed")
      gen.start(e.a.seqr);        
      #100;
    phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
      uvm_report_server svr = uvm_report_server::get_server();
      if (svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL) == 0)
        `uvm_info("RESULT", "\n\n*** TEST PASSED ***\n", UVM_NONE)
      else
        `uvm_info("RESULT", "\n\n*** TEST FAILED ***\n", UVM_NONE)
    endfunction
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
      uvm_config_db #(virtual dff_if)::set(null, "uvm_test_top.e.a*", "dff", dff);
    run_test("test");
    end
endmodule