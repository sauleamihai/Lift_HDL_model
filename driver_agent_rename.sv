`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __rename_driver
`define __rename_driver

//driverul va prelua date de tip "tranzactie", pe care le va trimite DUT-ului, conform protocolul de comunicatie de pe interfata
class driver_agent_rename extends uvm_driver #(tranzactie_rename);
  
  //driverul se adauga in baza de date UVM
  `uvm_component_utils (driver_agent_rename)
  
  //este declarata interfata pe care driverul va trimite datele
  virtual rename_interface_dut interfata_driverului_pentru_rename;
  
  //constructorul clasei
  function new(string name = "driver_agent_rename", uvm_component parent = null);
    //este apelat constructorul clasei parinte
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    //este apelata mai intai functia build_phase din clasa parinte
    super.build_phase(phase);
    if (!uvm_config_db#(virtual rename_interface_dut)::get(this, "", "rename_interface_dut", interfata_driverului_pentru_rename))begin
      `uvm_fatal("DRIVER_AGENT_rename", "Nu s-a putut accesa interfata_rename")
    end
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    forever begin
      `uvm_info("DRIVER_AGENT_rename", $sformatf("Se asteapta o tranzactie de la sequencer"), UVM_LOW)
      seq_item_port.get_next_item(req);
      `uvm_info("DRIVER_AGENT_rename", $sformatf("S-a primit o tranzactie de la sequencer"), UVM_LOW)
      trimiterea_tranzactiei(req);
      `uvm_info("DRIVER_AGENT_rename", $sformatf("Tranzactia a fost transmisa pe interfata"), UVM_LOW)
      seq_item_port.item_done();
    end
  endtask
  
  task trimiterea_tranzactiei(tranzactie_rename informatia_de_transmis);
    $timeformat(-9, 2, " ns", 20);//cand se va afisa in consola timpul, folosind directiva %t timpul va fi afisat in nanosecunde (-9), cu 2 zecimale, iar dupa valoare se va afisa abrevierea " ns"
    
    interfata_driverului_pentru_rename.valid = 'b1;
    interfata_driverului_pentru_rename.addr = informatia_de_transmis.addr;
	 @(posedge interfata_driverului_pentru_rename.clk);
   interfata_driverului_pentru_rename.valid = 'b0;

    
    `ifdef DEBUG
    $display("DRIVER_AGENT_rename, dupa transmisie; [T=%0t]", $realtime);
    `endif;
  endtask
  
endclass
`endif