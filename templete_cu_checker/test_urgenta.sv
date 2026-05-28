`timescale 1ns/1ps
`ifndef __test_urgenta
`define __test_urgenta

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "mediu_verificare.sv"
`include "secventa_apb.sv"
`include "secventa_req_ack.sv"

// -------------------------------------------------------------------------
// 1. Definim secventa pentru testul de urgenta
// -------------------------------------------------------------------------
class secventa_apb_urgenta extends secventa_apb;
  `uvm_object_utils(secventa_apb_urgenta)

  function new(string name = "secventa_apb_urgenta");
    super.new(name);
  endfunction

  virtual task body();
    bit [7:0] valoare_citita;
    
    `uvm_info("SEQ_URGENTA", "Pas 1: Chemam liftul la etajul 6...", UVM_LOW)
    // Folosim task-ul din clasa de baza pentru a scrie pe APB
    scrie_buton_lift(6); 
    
    // Asteptam ca liftul sa proceseze comanda, sa treaca in STATE_MOVE 
    // si sa inceapa sa urce (estimam ca ajunge pe la etajul 2 sau 3)
    `uvm_info("SEQ_URGENTA", "Asteptam ca liftul sa se puna in miscare...", UVM_LOW)
    #300;
    
    `uvm_info("SEQ_URGENTA", "Pas 2: DECLANSAM OPRIREA DE URGENTA!", UVM_LOW)
    // Folosim task-ul dedicat care trimite data = 8'h80 la adresa 0x01
    scrie_urgenta();
    
    // Asteptam suficient timp ca logica interna sa stearga cererile (pending_count = 0),
    // sa coboare liftul la etajul 0 si sa deschida usa pentru evacuare.
    `uvm_info("SEQ_URGENTA", "Asteptam revenirea la parter si resetarea sistemului...", UVM_LOW)
    #1500;
    
    `uvm_info("SEQ_URGENTA", "Pas 3: Citim starea pentru a confirma oprirea si pozitia (etajul 0)", UVM_LOW)
    citeste_registru(8'h03, valoare_citita);
    
    `uvm_info("SEQ_URGENTA", "Secventa de urgenta s-a incheiat.", UVM_LOW)
  endtask
endclass

// -------------------------------------------------------------------------
// 2. Definim testul integrat in mediul de verificare
// -------------------------------------------------------------------------
class test_urgenta extends uvm_test;
  `uvm_component_utils(test_urgenta)

  mediu_verificare mediu_de_verificare;
  secventa_apb_urgenta apb_seq_urgenta;

  virtual apb_interface_dut     vif_apb;
  virtual req_ack_interface_dut vif_req_ack;
  virtual iesire_interface_dut  vif_iesire;

  function new(string name = "test_urgenta", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    mediu_de_verificare = mediu_verificare::type_id::create("mediu_de_verificare", this);
    
    // Conectam interfetele
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
    `uvm_info("TEST", "Reset eliberat. Initializam secventa de URGENTA.", UVM_NONE)

    apb_seq_urgenta = secventa_apb_urgenta::type_id::create("apb_seq_urgenta");

    // Pornim secventa pe agentul APB
    apb_seq_urgenta.start(mediu_de_verificare.agent_apb_din_mediu.sequencer_agent_apb_inst0);

    // Lasam un buffer suplimentar de siguranta inainte sa terminam simularea
    #500;
    
    phase.drop_objection(this);
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    $display("╔══════════════════════════════════════════╗");
    $display("║          RAPORT FINAL TEST URGENTA       ║");
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