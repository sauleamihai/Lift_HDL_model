`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __rename_monitor
`define __rename_monitor
//`include "tranzactie_semafoare.sv"

class monitor_rename extends uvm_monitor;
  
  //monitorul se adauga in baza de date UVM
  `uvm_component_utils (monitor_rename) 
  
  //se declara colectorul de coverage care va inregistra valorile semnalelor de pe interfata citite de monitor
  coverage_rename colector_coverage_rename; 
  
  //este creat portul prin care monitorul trimite spre exterior (la noi, informatia este accesata de scoreboard), prin intermediul agentului, tranzactiile extrase din traficul de pe interfata
  uvm_analysis_port #(tranzactie_rename) port_date_monitor_rename;
  
  //declaratia interfetei de unde monitorul isi colecteaza datele
  //virtual interfata_rename interfata_monitor_rename;
  virtual rename_interface_dut interfata_monitor_rename;
  
  tranzactie_rename starea_preluata_a_rename, aux_tr_rename;
  
  //constructorul clasei
  function new(string name = "monitor_rename", uvm_component parent = null);
    
    //prima data se apeleaza constructorul clasei parinte
    super.new(name, parent);
    
    //se creeaza portul prin care monitorul trimite in exterior, prin intermediul agentului, datele pe care le-a cules din traficul de pe interfata
    port_date_monitor_rename = new("port_date_monitor_rename",this);
    
    //se creeaza colectorul de coverage (la creare, se apeleaza constructorul colectorului de coverage)
    
    colector_coverage_rename = coverage_rename::type_id::create ("colector_coverage_rename", this);
    
    
    //se creeaza obiectul (tranzactia) in care se vor retine datele colectate de pe interfata la fiecare tact de ceas
    starea_preluata_a_rename = tranzactie_rename::type_id::create("date_noi");
    
    aux_tr_rename = tranzactie_rename::type_id::create("datee_noi");
  endfunction
  
  
  //se preia din baza de date interfata la care se va conecta monitorul pentru a citi date, si se "leaga" la interfata pe care deja monitorul o contine
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if (!uvm_config_db#(virtual rename_interface_dut)::get(this, "", "rename_interface_dut", interfata_monitor_rename))
        `uvm_fatal("MONITOR_rename", "Nu s-a putut accesa interfata monitorului")
  endfunction
        
  
  
  virtual function void connect_phase (uvm_phase phase);
    super.connect_phase(phase);
    
    //in faza UVM "connect", se face conexiunea intre pointerul catre monitor din instanta colectorului de coverage a acestui monitor si monitorul insusi 
	colector_coverage_rename.p_monitor = this;
    
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    
    forever begin
      
      //!!!!sa astept ca datele sa fie valide
      wait(interfata_monitor_rename.valid); 
      //vreau sa citesc semnalul valid_i doar pe fronturile descrescatoare de ceas
      @(negedge interfata_monitor_rename.clk); 
      //preiau datele de pe interfata de iesire a DUT-ului (interfata_semafoare)
      starea_preluata_a_rename.addr = interfata_monitor_rename.addr;
      starea_preluata_a_rename.irq = interfata_monitor_rename.irq;

      aux_tr_rename = starea_preluata_a_rename.copy();//nu vreau sa folosesc pointerul starea_preluata_a_rename pentru a trimite datele, deoarece continutul acestuia se schimba, iar scoreboardul va citi alte date 
      
       //tranzactia cuprinzand datele culese de pe interfata se pune la dispozitie pe portul monitorului, daca modulul nu este in reset
      port_date_monitor_rename.write(aux_tr_rename); 
      `uvm_info("MONITOR_rename", $sformatf("S-a receptionat tranzactia cu informatiile:"), UVM_NONE)
      aux_tr_rename.afiseaza_informatia_tranzactiei();
	  
      //se inregistreaza valorile de pe cele doua semnale de iesire
      colector_coverage_rename.stari_rename_cg.sample();
      
	  @(negedge interfata_monitor_rename.clk); //acest wait il adaug deoarece uneori o tranzactie este interpretata a fi doua tranzactii identice back to back (validul este citit ca fiind 1 pe doua fronturi consecutive de ceas); in implementarea curenta nu se poate sa vina doua tranzactii back to back
      
      
    end//forever begin
  endtask
  
  
endclass: monitor_rename

`endif