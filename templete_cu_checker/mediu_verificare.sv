import uvm_pkg::*;
`include "uvm_macros.svh"

`ifndef __verification_environment
`define __verification_environment

`include "agent_apb.sv"
`include "agent_req_ack.sv"
`include "agent_iesire.sv"
`include "scoreboard.sv"

class mediu_verificare extends uvm_env;

  `uvm_component_utils(mediu_verificare)

  // ── Interfete virtuale ───────────────────────────────────────────────
  virtual apb_interface_dut     interfata_monitor_apb;
  virtual req_ack_interface_dut interfata_monitor_req_ack;
  virtual iesire_interface_dut  interfata_monitor_iesire;

  // ── Agenti ──────────────────────────────────────────────────────────
  agent_apb     agent_apb_din_mediu;
  agent_req_ack agent_req_ack_din_mediu;
  agent_iesire  agent_iesire_din_mediu;

  // ── Scoreboard ──────────────────────────────────────────────────────
  scoreboard IO_scoreboard;

  // ── Constructor ─────────────────────────────────────────────────────
  function new(string name, uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // ── Build phase ─────────────────────────────────────────────────────
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent_apb_din_mediu     = agent_apb::type_id::create("agent_apb_din_mediu",     this);
    agent_req_ack_din_mediu = agent_req_ack::type_id::create("agent_req_ack_din_mediu", this);
    agent_iesire_din_mediu  = agent_iesire::type_id::create("agent_iesire_din_mediu",  this);
    IO_scoreboard           = scoreboard::type_id::create("IO_scoreboard",           this);
  endfunction

  // ── Connect phase ────────────────────────────────────────────────────
  function void connect_phase(uvm_phase phase);
    `uvm_info("MEDIU DE VERIFICARE", "A inceput faza de realizare a conexiunilor", UVM_NONE)

    if (!uvm_config_db#(virtual apb_interface_dut)::get(this, "", "apb_interface_dut", interfata_monitor_apb))
      `uvm_fatal("MEDIU DE VERIFICARE", "Nu s-a putut prelua: apb_interface_dut")

    if (!uvm_config_db#(virtual req_ack_interface_dut)::get(this, "", "req_ack_interface_dut", interfata_monitor_req_ack))
      `uvm_fatal("MEDIU DE VERIFICARE", "Nu s-a putut prelua: req_ack_interface_dut")

    if (!uvm_config_db#(virtual iesire_interface_dut)::get(this, "", "iesire_interface_dut", interfata_monitor_iesire))
      `uvm_fatal("MEDIU DE VERIFICARE", "Nu s-a putut prelua: iesire_interface_dut")

    uvm_config_db#(virtual apb_interface_dut)::set(this, "agent_apb_din_mediu.*", "apb_interface_dut", interfata_monitor_apb);
    uvm_config_db#(virtual req_ack_interface_dut)::set(this, "agent_req_ack_din_mediu.*", "req_ack_interface_dut", interfata_monitor_req_ack);
    uvm_config_db#(virtual iesire_interface_dut)::set(this, "agent_iesire_din_mediu.*", "iesire_interface_dut", interfata_monitor_iesire);

    agent_apb_din_mediu.de_la_monitor_apb.connect(IO_scoreboard.port_pentru_datele_de_la_apb);
    agent_req_ack_din_mediu.de_la_monitor_req_ack.connect(IO_scoreboard.port_pentru_datele_de_la_req_ack);
    agent_iesire_din_mediu.de_la_monitor_iesire.connect(IO_scoreboard.port_pentru_datele_de_la_iesire);

    `uvm_info("MEDIU DE VERIFICARE", "Faza de realizare a conexiunilor s-a terminat", UVM_HIGH)
  endfunction 

  // RUN PHASE A FOST STERS COMPLET PENTRU A PREVENI BUCLELE VIVADO TIME-0

endclass
`endif