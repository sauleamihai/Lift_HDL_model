`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __req_ack_agent
`define __req_ack_agent

// Dependente agent REQ/ACK — ordinea de includere rezolva dependentele:
// tranzactie → coverage (refera tranzactia) → driver → monitor (refera coverage)
// typedef class monitor_req_ack a fost eliminat: era sursa FATAL_ERROR in xsim
`include "tranzactie_req_ack.sv"
`include "coverage_req_ack.sv"
`include "driver_agent_req_ack.sv"
`include "monitor_req_ack.sv"

class agent_req_ack extends uvm_agent;

  `uvm_component_utils(agent_req_ack)

  driver_agent_req_ack                    driver_req_ack_inst;
  monitor_req_ack                         monitor_req_ack_inst;
  uvm_sequencer #(tranzactie_req_ack)     sequencer_req_ack_inst;

  uvm_analysis_port #(tranzactie_req_ack) de_la_monitor_req_ack;

  local int is_active = 1;

  function new(string name = "agent_req_ack", uvm_component parent = null);
    super.new(name, parent);
    // Handle-ul e asignat in connect_phase de la portul monitorului.
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor_req_ack_inst =
      monitor_req_ack::type_id::create("monitor_req_ack_inst", this);
    if (is_active == 1) begin
      sequencer_req_ack_inst =
        uvm_sequencer#(tranzactie_req_ack)::type_id::create(
          "sequencer_req_ack_inst", this);
      driver_req_ack_inst =
        driver_agent_req_ack::type_id::create("driver_req_ack_inst", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    de_la_monitor_req_ack = monitor_req_ack_inst.port_date_monitor_req_ack;
    if (is_active == 1)
      driver_req_ack_inst.seq_item_port.connect(
        sequencer_req_ack_inst.seq_item_export);
  endfunction

endclass

`endif
