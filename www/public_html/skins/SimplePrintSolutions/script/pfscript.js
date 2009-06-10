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
  bpz = document.autoSumForm.bprice.options[document.autoSumForm.bprice.selectedIndex].value;
  clr = document.autoSumForm.color1.value;
  slo = document.autoSumForm.slotorientation1.options[document.autoSumForm.slotorientation1.selectedIndex].value;  
  bcs = document.autoSumForm.businesscardslot1.options[document.autoSumForm.businesscardslot1.selectedIndex].value; 
  coa = document.autoSumForm.coating1.options[document.autoSumForm.coating1.selectedIndex].value; 
  pap = document.autoSumForm.paper1.value;
  trn = document.autoSumForm.turnaround1.options[document.autoSumForm.turnaround1.selectedIndex].value;
  dis = document.autoSumForm.insdiscount.value;


  Singolo1 = ((((qty / tft) * (pap * 1)) + ((qty / tft) * (slo * 1)) + ((qty / tft) * (coa * 1)) + ((qty / tft) * (bcs * 1)) + (trn * 1) + (clr * 1) + (bpz * 1)) / (qty * 1)); 
  
  stotale1 = (((qty / tft) * (pap * 1)) + ((qty / tft) * (slo * 1)) + ((qty / tft) * (coa * 1)) + ((qty / tft) * (bcs * 1)) + (trn * 1) + (clr * 1) + (bpz * 1)); 
  
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
function setForm2Value() {
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
function setForm11Value() {
    var selectedItem      = document.autoSumForm.slotorientation1.selectedIndex;
    var selectedItemText  = document.autoSumForm.slotorientation1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.slotorientation.value = selectedItemText;
    }
    else {
        document.autoSumForm.slotorientation.value = "";
      
    }
}
//-->
<!--
function setForm12Value() {
    var selectedItem      = document.autoSumForm.businesscardslot1.selectedIndex;
    var selectedItemText  = document.autoSumForm.businesscardslot1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.businesscardslot.value = selectedItemText;
    }
    else {
        document.autoSumForm.businesscardslot.value = "";
      
    }
}
//-->
<!--
function setForm13Value() {
    var selectedItem      = document.autoSumForm.coating1.selectedIndex;
    var selectedItemText  = document.autoSumForm.coating1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.coating.value = selectedItemText;
    }
    else {
        document.autoSumForm.coating.value = "";
      
    }
}
//-->