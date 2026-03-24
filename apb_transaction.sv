class apb_transaction;
  // Randomizable fields
  rand bit [7:0] paddr;    // APB address
  rand bit       pwrite;   // APB write (1 = write, 0 = read)
  rand bit [7:0] pwdata;   // APB write data
  rand bit [7:0] prdata;   // APB read data
  rand int       delay;    // Delay carried over from original class


  // Keep the original constraint name and usage
  constraint wr_rd_c {
    delay >= 0;
    delay < 50;
  }

  // This function is called after randomization
  function void post_randomize();
    $display("--------- [Trans] post_randomize ------");

    if (pwrite) begin
      $display("\t paddr = %0h\t pwrite = %0b\t delay = %0d\t pwdata = %0h",
               paddr, pwrite, delay, pwdata);
    end
    else begin
      $display("\t paddr = %0h\t pwrite = %0b\t delay = %0d\t prdata = %0h",
               paddr, pwrite, delay, prdata);
    end
    $display("-----------------------------------------");
  endfunction

  // Deep copy
  function apb_transaction do_copy();
    apb_transaction trans;
    trans = new();
    trans.paddr   = this.paddr;
    trans.pwrite  = this.pwrite;
    trans.pwdata  = this.pwdata;
    trans.prdata  = this.prdata;
    trans.delay   = this.delay;
     return trans;
  endfunction
endclass
