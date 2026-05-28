`timescale 1ns/1ps
`ifndef __test_simplu
`define __test_simplu

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "mediu_verificare.sv"
`include "secventa_apb.sv"
`include "secventa_req_ack.sv"

// -------------------------------------------------------------------------
// 1. Definim secventa care extinde clasa voastra (folosim task-urile deja facute)
// -------------------------------------------------------------------------
class secventa_apb_simplu extends secventa_apb;
  `uvm_object_utils(secventa_apb_simplu)

  function new(string name = "secventa_apb_simplu");
    super.new(name);
  endfunction

  virtual task body();
    bit [7:0] valoare_citita;
    
    `uvm_info("SEQ_SIMPLU", "Incepem testul de baza: chemare la etajul 3", UVM_LOW)
    
    // 1. Scriem pe APB cererea folosind task-ul vostru
    scrie_buton_lift(3); 
    
    // 2. Citim de pe APB registrul de stare (0x03)
    citeste_registru(8'h03, valoare_citita);
    
    `uvm_info("SEQ_SIMPLU", "Tranzactiile de scriere si citire au fost trimise cu succes.", UVM_LOW)
  endtask
endclass

// -------------------------------------------------------------------------
// 2. Definim testul integrat pe structura din test_exemplu.sv
// -------------------------------------------------------------------------
class test_simplu extends uvm_test;
  `uvm_component_utils(test_simplu)

  mediu_verificare mediu_de_verificare;
  secventa_apb_simplu apb_seq_simplu;

  virtual apb_interface_dut     vif_apb;
  virtual req_ack_interface_dut vif_req_ack;
  virtual iesire_interface_dut  vif_iesire;

  function new(string name = "test_simplu", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    mediu_de_verificare = mediu_verificare::type_id::create("mediu_de_verificare", this);
    
    if (!uvm_config_db#(virtual apb_interface_dut)::get(this, "", "apb_interface_dut", vif_apb))
      `uvm_fatal("TEST", "Nu s-a putut obtine apb_interface_dut din config_db")
    if (!uvm_config_db#(virtual req_ack_interface_dut)::get(this, "", "req_ack_interface_dut", vif_req_ack))
      `uvm_fatal("TEST", "Nu s-a putut obtine req_ack_interface_dut din config_db")
    if (!uvm_config_db#(virtual iesire_interface_dut)::get(this, "", "iesire_interface_dut", vif_iesire))
      `uvm_fatal("TEST", "Nu s-a putut obtine iesire_interface_dut din config_db")

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
    `uvm_info("TEST", "Asteptam eliberarea resetului hardware...", UVM_NONE)

    @(posedge vif_apb.rst_n);
    repeat(5) @(posedge vif_apb.pclk);
    `uvm_info("TEST", "Reset eliberat. Initializam secventa simpla.", UVM_NONE)

    apb_seq_simplu = secventa_apb_simplu::type_id::create("apb_seq_simplu");

    // Pornim secventa specific pe instanta corecta din mediul vostru
    apb_seq_simplu.start(mediu_de_verificare.agent_apb_din_mediu.sequencer_agent_apb_inst0);

    // Lasam suficient timp pentru miscare si usi
    #1500;
    
    phase.drop_objection(this);
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    $display("╔══════════════════════════════════════════╗");
    $display("║          RAPORT FINAL TEST SIMPLU        ║");
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
    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0 && svr.get_severity_count(UVM_WARNING) == 0) begin
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