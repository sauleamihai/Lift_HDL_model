`timescale 1ns/1ps
`ifndef __test_req_ack
`define __test_req_ack

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "mediu_verificare.sv"
`include "secventa_apb.sv"
`include "secventa_req_ack.sv"

// -------------------------------------------------------------------------
// 1. Secventa APB pentru a aduce liftul la un etaj (deschidem usa)
// -------------------------------------------------------------------------
class secventa_apb_chemare extends secventa_apb;
  `uvm_object_utils(secventa_apb_chemare)

  function new(string name = "secventa_apb_chemare");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("SEQ_APB", "Chemam liftul la etajul 2 pentru a-i deschide usa...", UVM_LOW)
    scrie_buton_lift(2); 
  endtask
endclass

// -------------------------------------------------------------------------
// 2. Secventa REQ_ACK derivata pentru a testa senzorul
// -------------------------------------------------------------------------
class secventa_obstacol_test extends secventa_req_ack;
  `uvm_object_utils(secventa_obstacol_test)

  function new(string name = "secventa_obstacol_test");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("SEQ_REQ_ACK", "PAS 1: Generam un obstacol LUNG in usa deschisa!", UVM_LOW)
    // Folosim task-ul gata facut de voi in secventa de baza
    obstacol_lung();

    `uvm_info("SEQ_REQ_ACK", "PAS 2: Asteptam putin si generam un obstacol SCURT!", UVM_LOW)
    #200;
    obstacol_scurt();
    
    `uvm_info("SEQ_REQ_ACK", "Secventa hardware pentru obstacole s-a incheiat.", UVM_LOW)
  endtask
endclass

// -------------------------------------------------------------------------
// 3. Testul integrat care ruleaza secventele in paralel/secvential
// -------------------------------------------------------------------------
class test_req_ack extends uvm_test;
  `uvm_component_utils(test_req_ack)

  mediu_verificare mediu_de_verificare;
  secventa_apb_chemare apb_seq_chemare;
  secventa_obstacol_test req_ack_seq_obstacol;

  virtual apb_interface_dut     vif_apb;
  virtual req_ack_interface_dut vif_req_ack;
  virtual iesire_interface_dut  vif_iesire;

  function new(string name = "test_req_ack", uvm_component parent = null);
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

    // Initializam ambele secvente
    apb_seq_chemare = secventa_apb_chemare::type_id::create("apb_seq_chemare");
    req_ack_seq_obstacol = secventa_obstacol_test::type_id::create("req_ack_seq_obstacol");

    // 1. Chemam liftul la etajul 2 si asteptam sa ajunga si sa deschida usa
    apb_seq_chemare.start(mediu_de_verificare.agent_apb_din_mediu.sequencer_agent_apb_inst0);
    
    // Asteptam 1000 de unitati ca liftul sa ajunga fizic la etajul 2 si sa intre in STATE_DOOR_OPEN
    #1000; 

    // 2. Acum usa este deschisa. Lansam secventa de simulare a obstacolelor
    req_ack_seq_obstacol.start(mediu_de_verificare.agent_req_ack_din_mediu.sequencer_req_ack_inst);

    // Asteptam inchiderea finala a usilor
    #1000;
    
    phase.drop_objection(this);
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    $display("╔══════════════════════════════════════════╗");
    $display("║       RAPORT FINAL TEST REQ/ACK          ║");
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