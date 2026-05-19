//modificat
`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_agent
`define __apb_agent

// Dependente agent APB — ordinea de includere rezolva dependentele:
// tranzactie → coverage (refera tranzactia) → driver → monitor (refera coverage)
// typedef class monitor_apb a fost eliminat: era sursa FATAL_ERROR in xsim
// (covergroup-ul din coverage_apb evalua campuri dintr-un tip incomplet definit)
`include "tranzactie_apb.sv"
`include "coverage_apb.sv"
`include "driver_agent_apb.sv"
`include "monitor_apb.sv"


class agent_apb extends uvm_agent;
  
  `uvm_component_utils (agent_apb)//se adauga agentul la baza de date a acestui proiect; de acolo, acelasi agent se va prelua ulterior spre a putea fi folosit
  
  
  //se instantiaza componentele de baza ale agentului: driverul, monitorul si sequencer-ul; driverul si monitorul sunt create de catre noi, pe cand sequencerul se ia direct din biblioteca UVM
  driver_agent_apb driver_agent_apb_inst0;
  
  monitor_apb  monitor_apb_inst0;
  
  uvm_sequencer #(tranzactie_apb) sequencer_agent_apb_inst0;
  
  
  //se declara portul de comunicare al agentului cu scoreboardul/mediul de referinta; prin acest port agentul trimite spre verificare datele preluate de la monitor; a se observa ca intre monitor si agent (practic in interiorul agentului) comunicarea se face la nivel de tranzactie
  uvm_analysis_port #(tranzactie_apb) de_la_monitor_apb; //de_la_monitor_agent_semafoare;
  
  
  //se declara un camp in care spunem daca agentul este activ sau pasiv; un agent activ contine in plus, fata de agentul pasiv, driver si sequencer
  local int is_active = 1;  //0 inseamna agent pasiv; 1 inseamna agent activ
  
  
  //se declara constructorul clasei; acesta este un cod standard pentru toate componentele
  function new (string name = "agent_apb", uvm_component parent = null);
      super.new (name, parent);
  endfunction
  
  
  //rularea unui mediu de verificare cuprinde mai multe faze; in faza "build", se "asambleaza" agentul, tinandu-se cont daca acesta este activ sau pasiv
  virtual function void build_phase (uvm_phase phase);

    super.build_phase(phase);

    monitor_apb_inst0 = monitor_apb::type_id::create ("monitor_apb_inst0", this);
    if (is_active==1) begin
      sequencer_agent_apb_inst0 = uvm_sequencer#(tranzactie_apb)::type_id::create ("sequencer_agent_apb_inst0", this);
      driver_agent_apb_inst0 = driver_agent_apb::type_id::create ("driver_agent_apb_inst0", this);
    end

  endfunction
  
  
  //rularea unui mediu de verificare cuprinde mai multe faze; in faza "connect", se realizeaza conexiunile intre componente; in cazul agentului, se realizeaza conexiunile intre sub-componentele agentului
  virtual function void connect_phase (uvm_phase phase);

    super.connect_phase(phase);

    // Acelasi pattern ca agent_req_ack si agent_iesire (dovedit functional in xsim)
    de_la_monitor_apb = monitor_apb_inst0.port_date_monitor_apb;

    if (is_active==1) begin
      driver_agent_apb_inst0.seq_item_port.connect(sequencer_agent_apb_inst0.seq_item_export);
    end

  endfunction
  
endclass

`endif