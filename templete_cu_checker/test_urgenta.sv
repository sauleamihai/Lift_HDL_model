`timescale 1ns/1ps
`ifndef __test_urgenta
`define __test_urgenta

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "mediu_verificare.sv"
`include "secventa_apb_urgenta.sv"
`include "secventa_req_ack.sv"

// Test pentru scenariul de urgenta:
//   - Trimite cereri de etaj
//   - Declanseaza emergency_stop (scriere 0x80 la 0x01)
//   - Verifica (prin assertion p_emergency_clears_pending si scoreboard):
//       * liftul coboara la etaj 0
//       * pending_count devine 0
//       * emergency_stop se elibereaza singur
class test_urgenta extends uvm_test;

  `uvm_component_utils(test_urgenta)

  mediu_verificare           mediu_de_verificare;
  secventa_apb_urgenta       apb_seq;
  secventa_req_ack           req_ack_seq;

  virtual apb_interface_dut     vif_apb;
  virtual req_ack_interface_dut vif_req_ack;
  virtual iesire_interface_dut  vif_iesire;

  function new(string name = "test_urgenta", uvm_component parent = null);
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

    `uvm_info("TEST", "Reset eliberat. Initializam secventa de urgenta.", UVM_NONE)

    apb_seq     = secventa_apb_urgenta::type_id::create("apb_seq");
    req_ack_seq = secventa_req_ack::type_id::create("req_ack_seq");
    if (!req_ack_seq.randomize()) `uvm_warning("TEST", "req_ack_seq.randomize() a esuat")

    `uvm_info("TEST", "Pornim secventele URGENTA si REQ/ACK in paralel", UVM_NONE)

    fork
      begin
        apb_seq.start(mediu_de_verificare.agent_apb_din_mediu.sequencer_agent_apb_inst0);
      end
      begin
        req_ack_seq.start(mediu_de_verificare.agent_req_ack_din_mediu.sequencer_req_ack_inst);
      end
    join

    #1000;
    phase.drop_objection(this);
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    $display("╔══════════════════════════════════════════╗");
    $display("║       RAPORT FINAL TEST_URGENTA          ║");
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
    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0) begin
      $display("║  STATUS : ****   TEST PASS   ****        ║");
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
