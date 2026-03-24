// monitorul urmareste traficul de pe interfetele DUT-ului si trimite
// tranzactiile catre scoreboard
// Acces direct la semnalele interfetei (fara clocking block - compatibil Vivado xsim)

class monitor_out;

  virtual output_interface out_interf;
  mailbox out_mon2scb;
  coverage_out coverage_collector;

  function new(virtual output_interface out_interf, mailbox out_mon2scb);
    this.out_interf  = out_interf;
    this.out_mon2scb = out_mon2scb;
    coverage_collector = new();
  endfunction

  task main;
    forever begin
      transaction_out trans;
      trans = new();

      @(posedge out_interf.clk);

      trans.various_signals  = out_interf.various_signals;
      trans.floor_management = out_interf.floor_management;
      out_mon2scb.put(trans);

      coverage_collector.sample(trans);
    end
  endtask

endclass
