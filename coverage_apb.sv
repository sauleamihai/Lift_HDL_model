`include "uvm_macros.svh"
import uvm_pkg::*;

`ifndef __apb_coverage_collector
`define __apb_coverage_collector

//aceasta clasa este folosita pentru a se vedea cate combinatii de intrari au fost trimise DUT-ului; aceasta clasa este doar de model, si probabil va fi modificata, deoarece in general nu ne intereseaza sa obtinem in simulare toate combinatiile posibile de intrari ale unui DUT
class coverage_apb extends uvm_component;
  
  //componenta se adauga in baza de date
  `uvm_component_utils(coverage_apb)
  
  //se declara pointerul catre monitorul care da datele asupra carora se vor face masuratorile de coverage
  monitor_apb p_monitor;
  
  covergroup stari_apb_cg;
    option.per_instance = 1;
    coverpoint p_monitor.starea_preluata_a_apb.addr{
        bins min_addr = {0};
        bins random_addr = {[1:3]};
      	bins max_addr = {4};
    }
  endgroup
  
  //se creeaza grupul de coverage; ATENTIE! Fara functia de mai jos, grupul de coverage nu va putea esantiona niciodata date deoarece pana acum el a fost doar declarat, nu si creat
  function new(string name, uvm_component parent);
    super.new(name, parent);
    $cast(p_monitor, parent);//with the use of $cast, type check will occur during runtime
    stari_apb_cg = new();
  endfunction
  
endclass


`endif