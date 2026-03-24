// monitorul urmareste traficul de pe interfata APB si trimite tranzactiile
// extrase catre scoreboard si colectorul de coverage
// Acces direct la semnalele interfetei (fara clocking block - compatibil Vivado xsim)

class monitor_apb;

  virtual apb_interface apb_interf;
  mailbox  apb_mon2scb;
  int      delay;
  apb_coverage cov_apb;

  event stop_mon;

  function new(virtual apb_interface apb_interf, mailbox apb_mon2scb);
    this.apb_interf  = apb_interf;
    this.apb_mon2scb = apb_mon2scb;
    cov_apb = new();
  endfunction

  task main;
    apb_transaction trans;
    forever begin
      if (stop_mon.triggered) break;

      // asteapta PREADY = 1 si calculeaza delay
      delay = 0;
      @(posedge apb_interf.clk);
      while (apb_interf.PREADY == 0) begin
        delay++;
        @(posedge apb_interf.clk);
        if (stop_mon.triggered) break;
      end
      if (stop_mon.triggered) break;

      // creeaza tranzactia si copiaza semnalele
      trans = new();
      trans.paddr  = apb_interf.PADDR;
      $display("%0t valoarea adresei este %0h", $time, trans.paddr);
      trans.pwrite = apb_interf.PWRITE;
      trans.pwdata = apb_interf.PWDATA;
      trans.delay  = delay;

      // trimite spre scoreboard
      apb_mon2scb.put(trans);

      // colecteaza coverage
      cov_apb.sample(trans);
    end
  endtask
endclass
