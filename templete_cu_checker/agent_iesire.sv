`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __iesire_agent
`define __iesire_agent

// Agent PASIV — doar monitorizeaza iesirile DUT-ului
// Nu contine driver sau sequencer deoarece iesirile nu pot fi drivate

// Dependente agent iesire — ordinea de includere rezolva dependentele:
// tranzactie → coverage (refera tranzactia) → monitor (refera coverage)
// typedef class monitor_iesire a fost eliminat: era sursa FATAL_ERROR in xsim
`include "tranzactie_iesire.sv"
`include "coverage_iesire.sv"
`include "monitor_iesire.sv"

class agent_iesire extends uvm_agent;

  `uvm_component_utils(agent_iesire)

  monitor_iesire                         monitor_iesire_inst;
  uvm_analysis_port #(tranzactie_iesire) de_la_monitor_iesire;

  // Agent intotdeauna pasiv (is_active = 0)
  // Iesirile DUT-ului nu pot fi drivate din testbench
  local int is_active = 0;

  function new(string name = "agent_iesire", uvm_component parent = null);
    super.new(name, parent);
    // de_la_monitor_iesire NU se creeaza aici — ar ramane inregistrat ca
    // uvm_component orfan in ierarhie dupa ce handle-ul e suprascris in connect_phase,
    // provocand FATAL_ERROR in Vivado xsim la execute_phase.
    // Handle-ul e asignat in connect_phase de la portul monitorului.
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor_iesire_inst =
      monitor_iesire::type_id::create("monitor_iesire_inst", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    de_la_monitor_iesire = monitor_iesire_inst.port_date_monitor_iesire;
  endfunction

endclass

`endif
