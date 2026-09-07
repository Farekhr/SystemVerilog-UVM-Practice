// Code your testbench here
// or browse Examples
//AUTHOR: RYAN FAREKH
`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

//TRANSACTION
class transaction extends uvm_sequence_item;
  rand bit [3:0] a;
  rand bit [3:0] b;
  rand bit [3:0] c;
  rand bit [3:0] d;
  rand bit [1:0] sel;
  bit [3:0] y;

  function new(input string path = "transaction");
    super.new(path);
  endfunction

  `uvm_object_utils_begin(transaction)
  `uvm_field_int(a, UVM_DEFAULT)
  `uvm_field_int(b, UVM_DEFAULT)
  `uvm_field_int(c, UVM_DEFAULT)
  `uvm_field_int(d, UVM_DEFAULT)
  `uvm_field_int(y, UVM_DEFAULT)
  `uvm_field_int(sel, UVM_DEFAULT)
  `uvm_object_utils_end

  // Even weighting across all four select values so no channel is under-exercised in a short run.
  constraint c_sel_dist {
    sel dist { 2'b00 := 25, 2'b01 := 25, 2'b10 := 25, 2'b11 := 25 };
  }

  // Bias the data buses toward the all-zeros and all-ones corners, which are where a stuck bit on a channel would show up.
  constraint c_data_corners {
    a dist { 4'h0 := 15, 4'hF := 15, [4'h1:4'hE] := 70 };
    b dist { 4'h0 := 15, 4'hF := 15, [4'h1:4'hE] := 70 };
    c dist { 4'h0 := 15, 4'hF := 15, [4'h1:4'hE] := 70 };
    d dist { 4'h0 := 15, 4'hF := 15, [4'h1:4'hE] := 70 };
  }

  // The four channels differ on at least one bit, so a mux that routes the wrong input cannot pass by coincidence.
  constraint c_channels_distinct {
    a != b; a != c; a != d;
    b != c; b != d;
    c != d;
  }

endclass

//SEQUENCE
class generator extends uvm_sequence#(transaction);
  `uvm_object_utils(generator)
  transaction t;

  rand int unsigned n_txn;
  constraint c_n { n_txn inside {[40:60]}; }

  function new(input string path = "generator");
    super.new(path);
  endfunction

  virtual task body();
    repeat(n_txn) begin
      t = transaction::type_id::create("t");
      start_item(t);
      if(!t.randomize())
        `uvm_error("GEN", "Randomization failed")
      `uvm_info("GEN", $sformatf("Data sent to Driver a: %0h, b: %0h, c: %0h, d: %0h, sel: %0b",
                                 t.a, t.b, t.c, t.d, t.sel), UVM_NONE);
      finish_item(t);
    end
  endtask

endclass

// Directed sweep: walks every select value in order so all four channels are guaranteed covered regardless of the random seed.
class sel_sweep_seq extends uvm_sequence#(transaction);
  `uvm_object_utils(sel_sweep_seq)
  transaction t;

  function new(input string path = "sel_sweep_seq");
    super.new(path);
  endfunction

  virtual task body();
    for (int s = 0; s < 4; s++) begin
      repeat(3) begin
        t = transaction::type_id::create("t");
        start_item(t);
        if(!t.randomize() with { sel == s; })
          `uvm_error("SWEEP", "Randomization failed")
        finish_item(t);
      end
    end
  endtask
endclass

// Drives every channel to the all-zeros / all-ones corners under each select.
class corner_seq extends uvm_sequence#(transaction);
  `uvm_object_utils(corner_seq)
  transaction t;

  function new(input string path = "corner_seq");
    super.new(path);
  endfunction

  virtual task body();
    for (int s = 0; s < 4; s++) begin
      t = transaction::type_id::create("t");
      start_item(t);
      if(!t.randomize() with {
           sel == s;
           (s == 0) -> (a == 4'h0);
           (s == 1) -> (b == 4'h0);
           (s == 2) -> (c == 4'h0);
           (s == 3) -> (d == 4'h0);
         })
        `uvm_error("CORNER", "Randomization failed")
      finish_item(t);
      t = transaction::type_id::create("t");
      start_item(t);
      if(!t.randomize() with {
           sel == s;
           (s == 0) -> (a == 4'hF);
           (s == 1) -> (b == 4'hF);
           (s == 2) -> (c == 4'hF);
           (s == 3) -> (d == 4'hF);
         })
        `uvm_error("CORNER", "Randomization failed")
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

    transaction tc;
    virtual mux_if mif;

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tc = transaction::type_id::create("tc");

    if(!uvm_config_db #(virtual mux_if)::get(this, "","mif",mif))
        `uvm_fatal("DRV", "Unable to access uvm_config_db");
    endfunction

    virtual task run_phase(uvm_phase phase);
    forever begin
        seq_item_port.get_next_item(tc);
        mif.a <= tc.a;
        mif.b <= tc.b;
        mif.c <= tc.c;
        mif.d <= tc.d;
        mif.sel <= tc.sel;
        `uvm_info("DRV", $sformatf("Trigger DUT a: %0h, b: %0h, c: %0h, d: %0h, sel: %0b",
                                   tc.a, tc.b, tc.c, tc.d, tc.sel), UVM_NONE);
        seq_item_port.item_done();
        #10;
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

    virtual mux_if mif;

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db #(virtual mux_if)::get(this, "","mif", mif))
        `uvm_fatal("MON", "Unable to access uvm_config_db");
    endfunction

    virtual task run_phase(uvm_phase phase);
    forever begin
        #10;
        begin
          transaction t = transaction::type_id::create("t");
          t.a   = mif.a;
          t.b   = mif.b;
          t.c   = mif.c;
          t.d   = mif.d;
          t.y   = mif.y;
          t.sel = mif.sel;
          `uvm_info("MON", $sformatf("Data sent to Scoreboard sel: %0b, y: %0h",
                                     t.sel, t.y), UVM_NONE);
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

    function bit [3:0] predict(input transaction t);
      case (t.sel)
        2'b00: return t.a;
        2'b01: return t.b;
        2'b10: return t.c;
        2'b11: return t.d;
        default: return 'x;
      endcase
    endfunction

    virtual function void write(input transaction t);
      bit [3:0] expected;

      if ($isunknown({t.sel, t.y})) begin
        `uvm_info("SCO", "Skipping sample with unknown values (pre-stimulus)", UVM_NONE)
        return;
      end

      expected = predict(t);
      n_checked++;

      if (t.y !== expected) begin
        n_failed++;
        `uvm_error("SCO", $sformatf("MISMATCH: sel=%0b expected y=%0h, observed y=%0h (a=%0h b=%0h c=%0h d=%0h)",
                                    t.sel, expected, t.y, t.a, t.b, t.c, t.d))
      end
      else begin
        `uvm_info("SCO", $sformatf("Match: sel=%0b y=%0h", t.sel, t.y), UVM_NONE)
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

    covergroup cg_mux;
      option.per_instance = 1;

      cp_sel : coverpoint cg_t.sel {
        bins sel_a = {2'b00};
        bins sel_b = {2'b01};
        bins sel_c = {2'b10};
        bins sel_d = {2'b11};
        bins transitions[] = (2'b00, 2'b01, 2'b10, 2'b11 =>
                              2'b00, 2'b01, 2'b10, 2'b11);
      }

      cp_y : coverpoint cg_t.y {
        bins all_zero = {4'h0};
        bins all_ones = {4'hF};
        bins mid      = {[4'h1:4'hE]};
      }

      cp_a : coverpoint cg_t.a { bins zero = {4'h0}; bins ones = {4'hF}; bins mid = {[4'h1:4'hE]}; }
      cp_b : coverpoint cg_t.b { bins zero = {4'h0}; bins ones = {4'hF}; bins mid = {[4'h1:4'hE]}; }
      cp_c : coverpoint cg_t.c { bins zero = {4'h0}; bins ones = {4'hF}; bins mid = {[4'h1:4'hE]}; }
      cp_d : coverpoint cg_t.d { bins zero = {4'h0}; bins ones = {4'hF}; bins mid = {[4'h1:4'hE]}; }

      x_sel_vs_y : cross cp_sel, cp_y;
      x_sel_vs_a : cross cp_sel, cp_a { ignore_bins other = ! binsof(cp_sel.sel_a); }
      x_sel_vs_b : cross cp_sel, cp_b { ignore_bins other = ! binsof(cp_sel.sel_b); }
      x_sel_vs_c : cross cp_sel, cp_c { ignore_bins other = ! binsof(cp_sel.sel_c); }
      x_sel_vs_d : cross cp_sel, cp_d { ignore_bins other = ! binsof(cp_sel.sel_d); }
    endgroup

    function new(input string path = "coverage", uvm_component parent = null);
      super.new(path, parent);
      cg_mux = new();
    endfunction

    virtual function void write(transaction t);
      if ($isunknown({t.sel, t.y})) return;
      cg_t = t;
      cg_mux.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
      `uvm_info("COV", $sformatf("Functional coverage: %0.2f%%", cg_mux.get_coverage()), UVM_NONE)
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

    generator     gen;
    sel_sweep_seq sweep;
    corner_seq    corners;
    env e;

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    gen     = generator::type_id::create("gen", this);
    sweep   = sel_sweep_seq::type_id::create("sweep", this);
    corners = corner_seq::type_id::create("corners", this);
    e       = env::type_id::create("e", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
      sweep.start(e.a.seqr);      
      corners.start(e.a.seqr);   
      if(!gen.randomize()) `uvm_error("TEST", "Sequence randomization failed")
      gen.start(e.a.seqr);        
      #50;
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
module mux_tb();

    mux_if mif();

    mux dut (.a(mif.a), .b(mif.b), .c(mif.c), .d(mif.d), .sel(mif.sel), .y(mif.y));

    initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    end

    initial begin
    uvm_config_db #(virtual mux_if)::set(null, "uvm_test_top.e.a*", "mif", mif);
    run_test("test");
    end
endmodule