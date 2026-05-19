`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_driver
`define __apb_driver

class driver_agent_apb extends uvm_driver #(tranzactie_apb);
  `uvm_component_utils(driver_agent_apb)

  virtual apb_interface_dut interfata_driverului_pentru_apb;

  function new(string name = "driver_agent_apb", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_interface_dut)::get(this, "", "apb_interface_dut", interfata_driverului_pentru_apb))
      `uvm_fatal("DRIVER_AGENT_APB", "Nu s-a putut accesa interfata APB")
  endfunction

  virtual task run_phase(uvm_phase phase);
    #100; // VIVADO ZERO-DELAY LOOP KILLER
    wait(interfata_driverului_pentru_apb.rst_n === 1'b1);
    
    @(posedge interfata_driverului_pentru_apb.pclk);
    interfata_driverului_pentru_apb.psel    <= 1'b0;
    interfata_driverului_pentru_apb.penable <= 1'b0;
    interfata_driverului_pentru_apb.pwrite  <= 1'b0;
    interfata_driverului_pentru_apb.paddr   <= 8'h00;
    interfata_driverului_pentru_apb.pwdata  <= 8'h00;

    forever begin
      seq_item_port.get_next_item(req);
      trimiterea_tranzactiei(req);
      seq_item_port.item_done();
    end
  endtask

  task trimiterea_tranzactiei(tranzactie_apb informatia_de_transmis);
    @(posedge interfata_driverului_pentru_apb.pclk);
    interfata_driverului_pentru_apb.psel    <= 1'b1;
    interfata_driverului_pentru_apb.penable <= 1'b0;
    interfata_driverului_pentru_apb.paddr   <= informatia_de_transmis.addr;
    interfata_driverului_pentru_apb.pwrite  <= informatia_de_transmis.rw;
    if (informatia_de_transmis.rw)
      interfata_driverului_pentru_apb.pwdata <= informatia_de_transmis.data;

    @(posedge interfata_driverului_pentru_apb.pclk);
    interfata_driverului_pentru_apb.penable <= 1'b1;

    while (!interfata_driverului_pentru_apb.pready) begin
      @(posedge interfata_driverului_pentru_apb.pclk);
    end

    if (!informatia_de_transmis.rw) begin
      informatia_de_transmis.data = interfata_driverului_pentru_apb.prdata;
    end

    @(posedge interfata_driverului_pentru_apb.pclk);
    interfata_driverului_pentru_apb.psel    <= 1'b0;
    interfata_driverului_pentru_apb.penable <= 1'b0;
    interfata_driverului_pentru_apb.pwrite  <= 1'b0;
    interfata_driverului_pentru_apb.paddr   <= 8'h00;
    interfata_driverului_pentru_apb.pwdata  <= 8'h00;
  endtask
endclass
`endif