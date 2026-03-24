// Coverage Output - covergroup dezactivat pentru compatibilitate Vivado xsim
// (covergroup inside class cauzeaza EXCEPTION_ACCESS_VIOLATION in Vivado xsim)
class coverage_out;

  transaction_out trans_covered;

  function new();
  endfunction

  task sample(transaction_out trans_covered);
    this.trans_covered = trans_covered;
  endtask

  function void print_coverage();
    $display("Output coverage: dezactivat (incompatibil Vivado xsim)");
  endfunction

endclass
