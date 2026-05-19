`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __req_ack_driver
`define __req_ack_driver

class driver_agent_req_ack extends uvm_driver #(tranzactie_req_ack);
  `uvm_component_utils(driver_agent_req_ack)

  virtual req_ack_interface_dut interfata_driverului_pentru_req_ack;

  function new(string name = "driver_agent_req_ack", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual req_ack_interface_dut)::get(this, "", "req_ack_interface_dut", interfata_driverului_pentru_req_ack))
      `uvm_fatal("DRIVER_REQ_ACK", "Nu s-a putut accesa interfata REQ/ACK")
  endfunction

  virtual task run_phase(uvm_phase phase);
    #100; // VIVADO ZERO-DELAY LOOP KILLER
    wait(interfata_driverului_pentru_req_ack.rst_n === 1'b1);

    @(posedge interfata_driverului_pentru_req_ack.clk);
    interfata_driverului_pentru_req_ack.obstacle_req <= 1'b0;

    forever begin
      seq_item_port.get_next_item(req);
      trimiterea_tranzactiei(req);
      seq_item_port.item_done();
    end
  endtask
  
  task trimiterea_tranzactiei(tranzactie_req_ack informatia_de_transmis);
    @(posedge interfata_driverului_pentru_req_ack.clk);
    interfata_driverului_pentru_req_ack.obstacle_req <= 1'b1;

    @(posedge interfata_driverului_pentru_req_ack.clk);
    
    repeat(informatia_de_transmis.durata_obstacol - 1)
      @(posedge interfata_driverului_pentru_req_ack.clk);

    interfata_driverului_pentru_req_ack.obstacle_req <= 1'b0;

    repeat(5) @(posedge interfata_driverului_pentru_req_ack.clk);
  endtask
endclass
`endif