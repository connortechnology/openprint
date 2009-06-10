<!--
/* This script and many more are available free online at
The JavaScript Source!! http://javascript.internet.com
Created by: Jim Stiles | www.jdstiles.com */
function startCalc(){
  interval = setInterval("calc()",1);
}
function calc(){
  xch = document.autoSumForm.xchange.value;
  tft = document.autoSumForm.tfifty.value;
  qty = document.autoSumForm.quantity.value;
  pap = document.autoSumForm.paper1.options[document.autoSumForm.paper1.selectedIndex].value; 
  ico = document.autoSumForm.icolor1.options[document.autoSumForm.icolor1.selectedIndex].value;
  nop = document.autoSumForm.nofpages1.options[document.autoSumForm.nofpages1.selectedIndex].value;
  bpz = document.autoSumForm.bprice.options[document.autoSumForm.bprice.selectedIndex].value;
  clr = document.autoSumForm.color1.value; 
  cpa = document.autoSumForm.cpaper1.options[document.autoSumForm.cpaper1.selectedIndex].value;
  bin = document.autoSumForm.binder1.options[document.autoSumForm.binder1.selectedIndex].value;
  trn = document.autoSumForm.turnaround1.options[document.autoSumForm.turnaround1.selectedIndex].value;
  dis = document.autoSumForm.insdiscount.value;


  Singolo1 = ((((qty / tft) * (pap * 1)) + ((qty / tft) * (cpa * 1)) + ((qty / tft) * (bin * 1)) + ((qty / tft) * (ico * 1)) + (trn * 1) + (nop * 1) + (clr * 1) + (bpz * 1)) / (qty * 1)); 
  
  stotale1 = (((qty / tft) * (pap * 1)) + ((qty / tft) * (cpa * 1)) + ((qty / tft) * (bin * 1)) + ((qty / tft) * (ico * 1)) + (trn * 1) + (nop * 1) + (clr * 1) + (bpz * 1)); 
  
  Singolo = (Singolo1 * xch);
  
  stotale = (stotale1 * xch);	  

  disctot = (stotale - ((stotale * dis)/100));
  
  document.autoSumForm.discount.value = disctot.toFixed(2);
  document.autoSumForm.subtotal.value = stotale.toFixed(2);
  document.autoSumForm.rate.value = Singolo.toFixed(2); 	
	
}
function stopCalc(){
  clearInterval(interval);
}
//-->
<!--
function setForm1Value() {
    var selectedItem      = document.autoSumForm.bprice.selectedIndex;
    var selectedItemText  = document.autoSumForm.bprice.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.quantity.value = selectedItemText;
    }
    else {
        document.autoSumForm.quantity.value = "";
      
    }
}
//-->
<!--
function setForm3Value() {
    var selectedItem      = document.autoSumForm.paper1.selectedIndex;
    var selectedItemText  = document.autoSumForm.paper1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.paper.value = selectedItemText;
    }
    else {
        document.autoSumForm.paper.value = "";
      
    }
}
//-->
<!--
function setForm4Value() {
    var selectedItem      = document.autoSumForm.turnaround1.selectedIndex;
    var selectedItemText  = document.autoSumForm.turnaround1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.turnaround.value = selectedItemText;
    }
    else {
        document.autoSumForm.turnaround.value = "";
      
    }
}
//-->
<!--
function setForm17Value() {
    var selectedItem      = document.autoSumForm.nofpages1.selectedIndex;
    var selectedItemText  = document.autoSumForm.nofpages1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.nofpages.value = selectedItemText;
    }
    else {
        document.autoSumForm.nofpages.value = "";
      
    }
}
//-->
<!--
function setForm18Value() {
    var selectedItem      = document.autoSumForm.cpaper1.selectedIndex;
    var selectedItemText  = document.autoSumForm.cpaper1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.cpaper.value = selectedItemText;
    }
    else {
        document.autoSumForm.cpaper.value = "";
      
    }
}
//-->
<!--
function setForm19Value() {
    var selectedItem      = document.autoSumForm.binder1.selectedIndex;
    var selectedItemText  = document.autoSumForm.binder1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.binder.value = selectedItemText;
    }
    else {
        document.autoSumForm.binder.value = "";
      
    }
}
//-->
<!--
function setForm20Value() {
    var selectedItem      = document.autoSumForm.color1.selectedIndex;
    var selectedItemText  = document.autoSumForm.color1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.color.value = selectedItemText;
    }
    else {
        document.autoSumForm.color.value = "";
      
    }
}
//-->