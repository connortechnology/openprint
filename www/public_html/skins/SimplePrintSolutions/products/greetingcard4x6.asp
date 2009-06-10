<%@ Language="VBScript"%>
<%Title="Produts/Greeting Card"%>
<% Dim step, insdiscount
	step = "fase1"
	insdiscount = 100 
	choosescript= "greetingcard" 
%>
<!--#include file="rsy.asp" -->
<!--#include file="rs.asp" -->
<!--#include file="rsx.asp" -->
<!--#include file="rsxx.asp" -->
<%

dim conn5x, strConn5x

strConn5x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn5x = Server.CreateObject("ADODB.Connection")
conn5x.Open StrConn5x 


SQL = "SELECT * FROM GreetingCPrice"

Set rs5x = Server.CreateObject("ADODB.Recordset")

rs5x.Open SQL, Conn5x

%>
<!--#include file="../headerpro.asp" -->
<table border="0" cellpadding="10" cellspacing="0"  width="584" height="470">
  <tr>
    <td valign="top" class=text>
<form name="autoSumForm" action=../shoppingcart/review_order.asp method="post">
<input type=hidden name=product value="Greeting Card">
<input name="sizep" type=hidden value="4 x 6" size="10">
<input type=hidden name=xchange onFocus="startCalc();" onBlur="stopCalc();" value="<%=rsy("price1")%>">
<input type=hidden name=tfifty onFocus="startCalc();" onBlur="stopCalc();" value="250">
<input type=hidden onFocus="startCalc();" onBlur="stopCalc();" size=1 name=paper1 value="<%=rs("price1")%>">
<input name="paper" type=hidden value="<%=rs("desc1")%>" size="10">
 <table border="0" cellspacing="1" width="560">
  <tr>
    <td width="260" valign="top">
      <table border="0" cellpadding="10" cellspacing="0" width="100%" height="1">
        <tr>
          <td width="100%" height="153">
            <p align="center"><img border="0" src="images/GreetingCardsico.jpg"></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><b>Greeting Card Size:<br>
            </b>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
            <font class=textsize>4 x 6 Fold | <a href="greetingcard5x7.asp" class="linksize">5 x 7
            Fold </a> |
            <a href="greetingcard8x5.asp" class="linksize"> 8 x 5  Fold</a> <br> </font>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
          </td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><hr></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><b>File Preparation:<br>
            </b>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
            <a href="../templates/greetingc.asp" class="linksize">Download templates</a><br>
</td>
        </tr>

      </table>
    </td>
    <td bgcolor="#c9c9c9" width="300">
 
<table border="0" cellspacing="1" width="100%" height="293">
  <tr>
    <td width="100%" height="45">
      <table border="0" cellspacing="5" width="100%" cellpadding="5">
        <tr>
          <td width="100%" class=subtext><b>INSTANT PRICING</b></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td width="100%" bgcolor="#FFFFFF" height="1">
      <table border="0" cellpadding="5" cellspacing="5" width="100%" class=back3 height="1">
        <tr>
          <td width="100%" height="1">
          <!-- FIRST BOX -->
          <table border="0" cellspacing="0" width="100%" height="1">
  <tr>
    <td width="100%" height="1" class=textorange>Quantity<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
      <SELECT onChange="startCalc(); setForm1Value()" onBlur="stopCalc();" size=1 name=bprice>
         <OPTION value='<%=rs5x("price3")%>'><%=rs5x("desc3")%></OPTION>  
      <OPTION value='<%=rs5x("price4")%>'><%=rs5x("desc4")%></OPTION>
      <OPTION value='<%=rs5x("price5")%>'><%=rs5x("desc5")%></OPTION>
      <OPTION value='<%=rs5x("price6")%>'><%=rs5x("desc6")%></OPTION>
      <OPTION value='<%=rs5x("price7")%>'><%=rs5x("desc7")%></OPTION>
      <OPTION value='<%=rs5x("price8")%>'><%=rs5x("desc8")%></OPTION></SELECT><br>
      <input onChange="startCalc();" onBlur="stopCalc();" type=hidden name="quantity" value="<%=rs5x("desc3")%>" size="10">
    </td>
  </tr>
  <tr>
    <td width="100%" height="2" valign="top"><hr size="1" color="#DADADA">
</td>
  </tr>
  <tr>
    <td width="100%" height="55" valign="top" class=textorange>Colors&nbsp;<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
      <SELECT onChange="startCalc(); setForm2Value()" onBlur="stopCalc();" size=1 name=color1>
      	<option  value='<%=rsx("price1")%>'><%=rsx("desc1")%>
		<option  value='<%=rsx("price2")%>'><%=rsx("desc2")%>
		<option  value='<%=rsx("price3")%>'><%=rsx("desc3")%>
		</SELECT><br>
      <input name="color" type=hidden value="<%=rsx("desc1")%>" size="10">
     </td>
  </tr>
</table>

          <!-- END FIRST BOX --></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td width="100%" bgcolor="#FFFFFF" height="1">
    <table border="0" cellpadding="5" cellspacing="5" width="100%" class=back3 height="1">
        <tr>
          <td width="100%" height="1">
          <!-- SECOND BOX -->
             <img border="0" src="../images/spaziatore.gif" height=5 width="15"><br>
   <font class=textorange>Turnaround</font><br>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
   <select onChange="startCalc(); setForm4Value()" onBlur="stopCalc();" name="turnaround1">
					<option selected="selected" value='<%=rsxx("price1")%>'><%=rsxx("desc1")%></option>
					<option value='<%=rsxx("price2")%>'><%=rsxx("desc2")%></option>
					<option value='<%=rsxx("price3")%>'><%=rsxx("desc3")%></option>
				</select>
   <br><input name="turnaround" type=hidden value="<%=rsxx("desc1")%>" size="10">
   <img border="0" src="../images/spaziatore.gif" height=5 width="15"><!-- END SECOND BOX --></td>
        </tr>
      </table>

    </td>
  </tr>
  <tr>
    <td width="100%" bgcolor="#FFFFFF" height="1">
    
   <table border="0" cellpadding="5" cellspacing="5" width="100%" class=back3>
        <tr>
          <td width="100%">
          <!-- THIRD BOX -->
           <table border="0" cellspacing="0" width="100%" height="1">
      <tr>
    <td width="100%" colspan="2" height="21" valign="top" class=textorange>
 	Each<br>
    <img border="0" src="../images/spaziatore.gif" height=4 width="15"><br>
 <input class="right" type=text name="rate" size="20">
    </td>
  </tr>
  <tr>
    <td width="100%" colspan="2" height="1" valign="top"><img border="0" src="../images/spaziatore.gif" height=4 width="15"></td>
  </tr>
  <tr>
    <td width="100%" colspan="2" height="21" valign="top" class=textorange>Subtotal <br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
      <input class="right" type=text name="subtotal" size="20">
        <input onChange="startCalc(); " onBlur="stopCalc();" value='100' type=hidden name="insdiscount" size="20">
      <input type=hidden name="discount" size="20">
     	</td>
  </tr>
</table>
          <!-- END THIRD BOX --></td>
        </tr>
      </table>
    
    </td>
  </tr>
  <tr>
    <td width="100%" bgcolor="#FFFFFF" height="1">
    
   <table border="0" cellpadding="5" cellspacing="5" width="100%" class=back3>
        <tr>
          <td width="100%">
          <!-- FOURTH BOX -->
          <table border="0" cellpadding="0" cellspacing="0" width="100%" height="1">
  	<tr>
    <td width="100%" height="1">
    <p align="right">
 	<input type=submit name=b value="Continue">
    </p>
	 </td>
  	</tr>
	</table>

          <!-- END FOUTH BOX --></td>
        </tr>
      </table>
    
    </td>
  </tr>
</table>
 
</td>
  </tr>
</table>
</form></td>
  </tr>
</table>
<!--#include file="../bottom.asp" -->
<%

rsy.Close
set rsy = Nothing

conny.Close
Set conny = Nothing

%>
<%

rs.Close
set rs = Nothing

conn.Close
Set conn = Nothing

%>
<%

rsx.Close
set rsx = Nothing

connx.Close
Set connx = Nothing

%>
<%

rsxx.Close
set rsxx = Nothing

connxx.Close
Set connxx = Nothing

%>
<%

rs5x.Close
set rs5x = Nothing

conn5x.Close
Set conn5x = Nothing

%>