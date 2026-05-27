import uvm_pkg::*;

`include "uvm_macros.svh"

//modificat
`ifndef __apb_intf
`define __apb_intf

interface apb_interface_dut;

  // ── Semnale de control ─────────────────────────────────────────────
  logic        pclk;
  logic        rst_n;

  // ── Semnale APB ────────────────────────────────────────────────────
  logic [7:0]  paddr;     // adresa registrului (8 biti pentru lift)
  logic        psel;      // selectie slave
  logic        pwrite;    // 1=scriere, 0=citire
  logic        penable;   // faza ACCESS activa
  logic [7:0]  pwdata;    // date de scris catre DUT
  logic [7:0]  prdata;    // date citite din DUT
  logic        pready;    // DUT semnalizeaza ca transferul e gata
  logic        pslverr;   // eroare slave (0 mereu la liftul nostru)

  import uvm_pkg::*;

  // ── Assertiuni APB (compatibil UVM) ───────────────────────────────
  // Folosim "disable iff (rst_n !== 1'b1)" pentru a evita X-propagation:
  // la t=0 rst_n=X, !rst_n=X, iar "disable iff X" NU dezactiveaza asertiunea.

  // 1. Dupa SETUP (PSEL=1, PENABLE=0), PENABLE trebuie sa devina 1 in ciclul urmator
  property p_setup_to_access;
    @(posedge pclk) disable iff (rst_n !== 1'b1)
    (psel && !penable) |=> penable;
  endproperty
  a_setup_to_access: assert property(p_setup_to_access)
    else `uvm_error("APB_INTF", "PENABLE nu a urmat PSEL in ciclul urmator")

  // 2. PENABLE poate fi activ DOAR cand PSEL este activ
  property p_penable_needs_psel;
    @(posedge pclk) disable iff (rst_n !== 1'b1)
    penable |-> psel;
  endproperty
  a_penable_needs_psel: assert property(p_penable_needs_psel)
    else `uvm_error("APB_INTF", "PENABLE activ fara PSEL")

  // 3. PADDR trebuie sa fie stabil pe durata fazei ACCESS
  property p_paddr_stable;
    @(posedge pclk) disable iff (rst_n !== 1'b1)
    (psel && penable) |-> $stable(paddr);
  endproperty
  a_paddr_stable: assert property(p_paddr_stable)
    else `uvm_error("APB_INTF", "PADDR s-a schimbat in timpul transferului")

  // 4. PREADY poate fi activ DOAR in faza ACCESS
  property p_pready_only_in_access;
    @(posedge pclk) disable iff (rst_n !== 1'b1)
    pready |-> (psel && penable);
  endproperty
  a_pready_only_in_access: assert property(p_pready_only_in_access)
    else `uvm_error("APB_INTF", "PREADY activ in afara fazei ACCESS")

  // 5. Dupa finalizarea transferului, PENABLE trebuie sa se dezactiveze
  property p_penable_clears_after_ready;
    @(posedge pclk) disable iff (rst_n !== 1'b1)
    (psel && penable && pready) |=> !penable;
  endproperty
  a_penable_clears: assert property(p_penable_clears_after_ready)
    else `uvm_error("APB_INTF", "PENABLE nu s-a dezactivat dupa PREADY")

  // 6. PWDATA trebuie sa fie stabil in faza ACCESS la scrieri
  property p_pwdata_stable;
    @(posedge pclk) disable iff (rst_n !== 1'b1)
    (psel && penable && pwrite) |-> $stable(pwdata);
  endproperty
  a_pwdata_stable: assert property(p_pwdata_stable)
    else `uvm_error("APB_INTF", "PWDATA s-a schimbat in timpul fazei ACCESS la scriere")

  // 7. PWRITE trebuie sa fie stabil pe durata transferului
  //    (directia nu se schimba mid-transaction)
  property p_pwrite_stable;
    @(posedge pclk) disable iff (rst_n !== 1'b1)
    (psel && penable) |-> $stable(pwrite);
  endproperty
  a_pwrite_stable: assert property(p_pwrite_stable)
    else `uvm_error("APB_INTF", "PWRITE s-a schimbat in timpul transferului")

  // 8. PSLVERR trebuie sa fie mereu 0 — DUT-ul nostru nu genereaza erori
  //    (toate adresele 0x00-0x05 sunt valide, restul returneaza 0xFF la citire)
  property p_no_slverr;
    @(posedge pclk) disable iff (rst_n !== 1'b1)
    !pslverr;
  endproperty
  a_no_slverr: assert property(p_no_slverr)
    else `uvm_error("APB_INTF", "PSLVERR activ — DUT-ul nu ar trebui sa genereze erori")

  // 9. PRDATA trebuie sa fie cunoscut (fara X) la citiri valide
  property p_prdata_known;
    @(posedge pclk) disable iff (rst_n !== 1'b1)
    (psel && penable && pready && !pwrite) |-> !$isunknown(prdata);
  endproperty
  a_prdata_known: assert property(p_prdata_known)
    else `uvm_error("APB_INTF", "PRDATA contine X la o citire valida")

endinterface

`endif