// aici se declara tipul de data folosit pentru a stoca datele vehiculate intre
// generator si driver; monitorul, de asemenea, preia datele de pe interfata,
// le recompune folosind un obiect al acestui tip de data, si numai apoi le proceseaza
class button_transaction;
  // se declara atributele clasei
  // campurile declarate cu cuvantul cheie rand vor primi valori aleatoare la aplicarea functiei randomize()
  rand bit [7:0] buton_scara;
  rand bit [7:0] buton_lift;
  rand int unsigned delay;

  // constrangerile reprezinta un tip de membru al claselor din SystemVerilog, pe langa atribute si metode
  constraint delay_c {delay inside {[1:400]};}

  constraint buton_lift_c {buton_lift inside {8'b0000_0000
                                                  ,8'b0000_0001
                                                    ,8'b0000_0010
                                                    ,8'b0000_0100
                                                    ,8'b0000_1000
                                                    ,8'b0001_0000
                                                    ,8'b0010_0000
                                                    ,8'b0100_0000
                                                  ,8'b1000_0000}; }


  // aceasta functie este apelata dupa aplicarea functiei randomize() asupra obiectelor apartinand acestei clase
  function void post_randomize();
    $display("--------- [Trans] post_randomize ------");
    $display("\t buton_scara  = %0h\t buton_lift = %0h",buton_scara,buton_lift);
    $display("-----------------------------------------");
  endfunction

  // operator de copiere a unui obiect intr-un alt obiect (deep copy)
  function button_transaction do_copy();
    button_transaction trans;
    trans = new();
    trans.buton_scara  = this.buton_scara;
    trans.buton_lift = this.buton_lift;
    trans.delay = this.delay;
    return trans;
  endfunction
endclass
