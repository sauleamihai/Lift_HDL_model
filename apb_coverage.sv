// Coverage APB - covergroup dezactivat pentru compatibilitate Vivado xsim
// (covergroup inside class cauzeaza EXCEPTION_ACCESS_VIOLATION in Vivado xsim)
class apb_coverage;

  apb_transaction trans_covered;

  function new();
  endfunction

  task sample(apb_transaction trans_covered);
    this.trans_covered = trans_covered;
  endtask

  function void print_coverage();
    $display("APB coverage: dezactivat (incompatibil Vivado xsim)");
  endfunction

endclass : apb_coverage
