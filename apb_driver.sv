// driverul preia datele de la generator, la nivel abstract, si le trimite DUT-ului
// conform protocolului APB
// Acces direct la semnalele interfetei (fara clocking block - compatibil Vivado xsim)

class apb_driver;

  int no_transactions;

  virtual apb_interface apb_vif;
  mailbox gen2driv;

  function new(virtual apb_interface apb_viff, mailbox gen2driv);
    this.apb_vif  = apb_viff;
    this.gen2driv = gen2driv;
  endfunction

  task reset;
    wait(!apb_vif.reset);
    $display("--------- [DRIVER] Reset Started ---------");
    apb_vif.PADDR  <= 0;
    apb_vif.PWRITE <= 0;
    apb_vif.PWDATA <= 0;
    apb_vif.PSEL   <= 0;
    apb_vif.PENABLE<= 0;
    wait(apb_vif.reset);
    $display("--------- [DRIVER] Reset Ended ---------");
  endtask

  task drive_read(apb_transaction trans);
    repeat(trans.delay) @(posedge apb_vif.clk);
    apb_vif.PADDR   <= trans.paddr;
    apb_vif.PWRITE  <= 0;
    apb_vif.PSEL    <= 1;
    apb_vif.PENABLE <= 0;
    @(posedge apb_vif.clk);
    apb_vif.PENABLE <= 1;
    @(posedge apb_vif.clk);
    trans.prdata = apb_vif.PRDATA;
    apb_vif.PSEL    <= 0;
    apb_vif.PENABLE <= 0;
    apb_vif.PADDR   <= 0;
    apb_vif.PWRITE  <= 0;
  endtask

  task drive_write(apb_transaction trans);
    repeat(trans.delay) @(posedge apb_vif.clk);
    apb_vif.PADDR   <= trans.paddr;
    apb_vif.PWDATA  <= trans.pwdata;
    apb_vif.PWRITE  <= 1;
    apb_vif.PSEL    <= 1;
    apb_vif.PENABLE <= 0;
    @(posedge apb_vif.clk);
    apb_vif.PENABLE <= 1;
    // asteapta PREADY (inlocuieste iff - nesuportat de Vivado)
    forever begin
      @(posedge apb_vif.clk);
      if (apb_vif.PREADY == 1) break;
    end
    apb_vif.PSEL    <= 0;
    apb_vif.PENABLE <= 0;
    apb_vif.PADDR   <= 0;
    apb_vif.PWDATA  <= 0;
    apb_vif.PWRITE  <= 0;
  endtask

  task drive;
    apb_transaction trans;
    $display("%0t DRIVER APB: se asteapta dezactivarea resetului", $time);
    wait(apb_vif.reset);
    $display("%0t DRIVER APB: resetul s-a dezactivat", $time);
    gen2driv.get(trans);
    $display("%0t DRIVER APB: s-a primit un item de la generator", $time);
    if (trans.pwrite)
      drive_write(trans);
    else
      drive_read(trans);
    $display("--------- [DRIVER-TRANSFER: %0d] ---------", no_transactions);
    $display("-----------------------------------------");
    no_transactions++;
  endtask

  task main;
    forever begin
      fork
        begin wait(!apb_vif.reset); end
        begin forever drive(); end
      join_any
      disable fork;
    end
  endtask

endclass
