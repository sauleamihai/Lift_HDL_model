// Interfata APB cu assertiuni corecte (compatibil Vivado xsim)
interface apb_interface(input logic clk, input logic reset);

  logic          PCLK;
  logic          PRESETn;
  logic    [7:0] PADDR;
  logic          PWRITE;
  logic          PSEL;
  logic          PENABLE;
  logic    [7:0] PWDATA;
  logic    [7:0] PRDATA;
  logic          PREADY;
  logic          PSLVERR;

  // =====================================================================
  // Assertiuni protocl APB
  // =====================================================================

  // 1. Dupa faza SETUP (PSEL=1, PENABLE=0), PENABLE trebuie sa devina 1 in ciclul urmator
  property p_setup_to_access;
    @(posedge clk) disable iff (!reset)
    (PSEL && !PENABLE) |=> PENABLE;
  endproperty
  a_setup_to_access: assert property(p_setup_to_access)
    else $error("APB VIOLATION: PENABLE nu a urmat PSEL in ciclul urmator");
  c_setup_to_access: cover property(p_setup_to_access);

  // 2. PENABLE poate fi activ DOAR cand PSEL este activ
  property p_penable_needs_psel;
    @(posedge clk) disable iff (!reset)
    PENABLE |-> PSEL;
  endproperty
  a_penable_needs_psel: assert property(p_penable_needs_psel)
    else $error("APB VIOLATION: PENABLE activ fara PSEL");

  // 3. PWRITE trebuie sa fie stabil pe toata durata fazei ACCESS
  property p_pwrite_stable;
    @(posedge clk) disable iff (!reset)
    (PSEL && PENABLE) |-> $stable(PWRITE);
  endproperty
  a_pwrite_stable: assert property(p_pwrite_stable)
    else $error("APB VIOLATION: PWRITE s-a schimbat in timpul transferului");

  // 4. PADDR trebuie sa fie stabil pe toata durata fazei ACCESS
  property p_paddr_stable;
    @(posedge clk) disable iff (!reset)
    (PSEL && PENABLE) |-> $stable(PADDR);
  endproperty
  a_paddr_stable: assert property(p_paddr_stable)
    else $error("APB VIOLATION: PADDR s-a schimbat in timpul transferului");

  // 5. Dupa finalizarea transferului (PSEL && PENABLE && PREADY), PENABLE trebuie sa se dezactiveze
  property p_penable_clears_after_ready;
    @(posedge clk) disable iff (!reset)
    (PSEL && PENABLE && PREADY) |=> !PENABLE;
  endproperty
  a_penable_clears: assert property(p_penable_clears_after_ready)
    else $error("APB VIOLATION: PENABLE nu s-a dezactivat dupa PREADY");
  c_penable_clears: cover property(p_penable_clears_after_ready);

endinterface
