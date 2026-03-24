class scoreboard;

  mailbox apb_mon2scb;
  mailbox button_mon2scb;
  mailbox out_mon2scb;

  // opțional, pentru verificări de așteptări
  bit [7:0] expected_stop_order[$];
  bit       expect_no_pending_after_stop;

  function new(mailbox apb_mon2scb, mailbox button_mon2scb, mailbox out_mon2scb);
    this.apb_mon2scb     = apb_mon2scb;
    this.button_mon2scb  = button_mon2scb;
    this.out_mon2scb     = out_mon2scb;
  endfunction

  task main();
    fork
      monitor_apb_stream();
      monitor_button_stream();
      monitor_output_stream();
    join_none
  endtask

  // Extragere și afișare simple — poți extinde cu verificări
  task monitor_apb_stream();
    apb_transaction trans;
    forever begin
      apb_mon2scb.get(trans);
      $display("[SCB] Tranzactie APB: addr=%0h write=%0b data=%0h", trans.paddr, trans.pwrite, trans.pwdata);
    end
  endtask

  task monitor_button_stream();
    button_transaction trans;
    forever begin
      button_mon2scb.get(trans);
      $display("[SCB] Tranzactie Butoane: scara=%0h lift=%0h", trans.buton_scara, trans.buton_lift);
    end
  endtask

  task monitor_output_stream();
    transaction_out trans;
    forever begin
      out_mon2scb.get(trans);
      $display("[SCB] Output: various=%0h floor_mgmt=%0h", trans.various_signals, trans.floor_management);

      // Ex: verificare dacă liftul oprește conform așteptărilor
      if (expected_stop_order.size() > 0) begin
        bit [2:0] floor = trans.floor_management[7:5];
        if (floor == expected_stop_order[0]) begin
          $display("[SCB] STOP OK la etajul %0d", floor);
          expected_stop_order.pop_front();
        end
      end
    end
  endtask

endclass
