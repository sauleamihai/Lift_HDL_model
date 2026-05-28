`timescale 1ns/1ps
`ifndef __test_lift_ocupat
`define __test_lift_ocupat

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "mediu_verificare.sv"
`include "secventa_apb.sv"
`include "secventa_req_ack.sv"

// -------------------------------------------------------------------------
// 1. Definim secventa de stres (timpi de asteptare corectati)
// -------------------------------------------------------------------------
class secventa_apb_stres extends secventa_apb;
  `uvm_object_utils(secventa_apb_stres)

  function new(string name = "secventa_apb_stres");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("SEQ_STRES", "PAS 1: Trimitem liftul la ultimul etaj (7)", UVM_LOW)
    scrie_buton_lift(7);
    // Un delay de 15000 ofera destul timp pentru tranzitia tuturor celor 7 etaje
    #15000; 

    `uvm_info("SEQ_STRES", "PAS 2: Trimitem liftul inapoi la etajul 1", UVM_LOW)
    scrie_buton_lift(1);
    #15000;

    `uvm_info("SEQ_STRES", "PAS 3: Generam o avalansa de cereri (Stres pe FSM)", UVM_LOW)
    scrie_buton_lift(5);
    #100;
    scrie_buton_lift(2);
    #100;
    scrie_buton_lift(4);
    #100;
    scrie_buton_lift(3);
    
    // Acordam un timp urias pentru ca FSM-ul sa deserveasca toata coada
    #30000;

    `uvm_info("SEQ_STRES", "PAS 4: Revenim la parter (etajul 0) pentru finalizare", UVM_LOW)
    scrie_buton_lift(0);
    #15000;
    
    `uvm_info("SEQ_STRES", "Secventa de stres s-a incheiat cu succes.", UVM_LOW)
  endtask
endclass

// -------------------------------------------------------------------------
// 2. Definim testul integrat
// -------------------------------------------------------------------------
class test_lift_ocupat extends uvm_test;
  `uvm_component_utils(test_lift_ocupat)

  mediu_verificare mediu_de_verificare;
  secventa_apb_stres apb_seq_stres;

  virtual apb_interface_dut     vif_apb;
  virtual req_ack_interface_dut vif_req_ack;
  virtual iesire_interface_dut  vif_iesire;

  function new(string name = "test_lift_ocupat", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    mediu_de_verificare = mediu_verificare::type_id::create("mediu_de_verificare", this);
    
    if (!uvm_config_db#(virtual apb_interface_dut)::get(this, "", "apb_interface_dut", vif_apb))
      `uvm_fatal("TEST", "Nu s-a obtinut apb_interface_dut")
    if (!uvm_config_db#(virtual req_ack_interface_dut)::get(this, "", "req_ack_interface_dut", vif_req_ack))
      `uvm_fatal("TEST", "Nu s-a obtinut req_ack_interface_dut")
    if (!uvm_config_db#(virtual iesire_interface_dut)::get(this, "", "iesire_interface_dut", vif_iesire))
      `uvm_fatal("TEST", "Nu s-a obtinut iesire_interface_dut")

    uvm_config_db#(virtual apb_interface_dut)::set(this, "mediu_de_verificare.agent_apb_din_mediu.driver_agent_apb_inst0", "apb_interface_dut", vif_apb);
    uvm_config_db#(virtual apb_interface_dut)::set(this, "mediu_de_verificare.agent_apb_din_mediu.monitor_apb_inst0", "apb_interface_dut", vif_apb);
    uvm_config_db#(virtual req_ack_interface_dut)::set(this, "mediu_de_verificare.agent_req_ack_din_mediu.driver_req_ack_inst", "req_ack_interface_dut", vif_req_ack);
    uvm_config_db#(virtual req_ack_interface_dut)::set(this, "mediu_de_verificare.agent_req_ack_din_mediu.monitor_req_ack_inst", "req_ack_interface_dut", vif_req_ack);
    uvm_config_db#(virtual iesire_interface_dut)::set(this, "mediu_de_verificare.agent_iesire_din_mediu.monitor_iesire_inst", "iesire_interface_dut", vif_iesire);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    
    phase.raise_objection(this);
    
    #10;
    apply_reset();
    #10;

    @(posedge vif_apb.rst_n);
    repeat(5) @(posedge vif_apb.pclk);

    apb_seq_stres = secventa_apb_stres::type_id::create("apb_seq_stres");
    apb_seq_stres.start(mediu_de_verificare.agent_apb_din_mediu.sequencer_agent_apb_inst0);

    #1000;
    phase.drop_objection(this);
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    $display("╔══════════════════════════════════════════╗");
    $display("║      RAPORT FINAL TEST LIFT OCUPAT       ║");
    $display("╠══════════════════════════════════════════╣");

    $display("║  Coverage APB     : %6.2f%%             ║",
      mediu_de_verificare.agent_apb_din_mediu.monitor_apb_inst0.colector_coverage_apb.stari_apb_cg.get_inst_coverage());
    $display("║  Coverage REQ/ACK : %6.2f%%             ║",
      mediu_de_verificare.agent_req_ack_din_mediu.monitor_req_ack_inst.colector_coverage_req_ack.stari_req_ack_cg.get_inst_coverage());
    $display("║  Coverage Iesire  : %6.2f%%             ║",
      mediu_de_verificare.agent_iesire_din_mediu.monitor_iesire_inst.colector_coverage_iesire.stari_iesire_cg.get_inst_coverage());
    $display("╠══════════════════════════════════════════╣");

    svr = uvm_report_server::get_server();
    $display("║  Erori UVM        : %4d                ║", svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR));
    $display("║  Avertismente UVM : %4d                ║", svr.get_severity_count(UVM_WARNING));
    $display("╠══════════════════════════════════════════╣");
    
    // Fix: Un test pica doar daca are UVM_ERROR sau UVM_FATAL.
    // Warning-urile de la Scoreboard ("poate inca in tranzit") nu trebuie sa opreasca testul.
    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0) begin
      $display("║  STATUS : **** TEST PASS   **** ║");
    end else begin
      $display("║  STATUS : !!!!   TEST FAIL   !!!!        ║");
    end
    $display("╚══════════════════════════════════════════╝");
  endfunction

   task apply_reset();
    vif_apb.paddr    <= 0;
    vif_apb.penable  <= 0;
    vif_apb.psel     <= 0;
    vif_apb.pwrite   <= 0;
    vif_apb.pwdata   <= 0;
    vif_req_ack.obstacle_req <= 0;
   endtask

endclass

`endif