<%@ Language="VBScript"%>
<%Title="Produts/Letterhead"%>
<% Dim step, insdiscount
	step = "fase1"
	insdiscount = 100 
	choosescript= "letterhead" 
%>
<!--#include file="rsy.asp" -->
<!--#include file="rs.asp" -->
<!--#include file="rsx.asp" -->
<!--#include file="rsxx.asp" -->
<!--#include file="rs7x.asp" -->
<%

dim conn5x, strConn5x

strConn5x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn5x = Server.CreateObject("ADODB.Connection")
conn5x.Open StrConn5x 


SQL = "SELECT * FROM letterheadPrice"

Set rs5x = Server.CreateObject("ADODB.Recordset")

rs5x.Open SQL, Conn5x

%>
<!--#include file="../headerpro.asp" -->
<table border="0" cellpadding="10" cellspacing="0"  width="584" height="470">
  <tr>
    <td valign="top" class=text>
<form name="autoSumForm" action=../shoppingcart/review_order.asp method="post">
<input type=hidden name=product value="Letterhead">
<input name="sizep" type=hidden value="8.5 x 11" size="10">
<input type=hidden name=xchange onFocus="startCalc();" onBlur="stopCalc();" value="<%=rsy("price1")%>">
<input type=hidden name=tfifty onFocus="startCalc();" onBlur="stopCalc();" value="50">
<input type=hidden onFocus="startCalc();" onBlur="stopCalc();" size=1 name=paper1 value="<%=rs("price1")%>">
<input name="paper" type=hidden value="<%=rs("desc1")%>" size="10">
<input type=hidden onFocus="startCalc();" onBlur="stopCalc();" size=1 name=color1 value="<%=rsx("price2")%>">
<input name="color" type=hidden value="<%=rsx("desc2")%>" size="10">
 <table border="0" cellspacing="1" width="560">
  <tr>
    <td width="260" valign="top">
      <table border="0" cellpadding="10" cellspacing="0" width="100%" height="1">
        <tr>
          <td width="100%" height="153">
            <p align="center"><img border="0" src="images/Letterheadico.jpg"></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><b>Letterhead Size:<br>
            </b>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
            <font class="textsize">8.5 x 11 <br> </font>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
            <font class=textsize> Printed on 24lb</font></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><hr></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><b>File Preparation:<br>
            </b>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
            <a href="../templates/letterh.asp" class="linksize">Download templates</a><br>
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
      <OPTION value='<%=rs5x("price4")%>'><%=rs5x("desc4")%></OPTION>
      <OPTION value='<%=rs5x("price5")%>'><%=rs5x("desc5")%></OPTION>
      <OPTION value='<%=rs5x("price6")%>'><%=rs5x("desc6")%></OPTION>
      <OPTION value='<%=rs5x("price7")%>'><%=rs5x("desc7")%></OPTION>
      <OPTION value='<%=rs5x("price8")%>'><%=rs5x("desc8")%></OPTION>
      <OPTION value='<%=rs5x("price9")%>'><%=rs5x("desc9")%></OPTION>
      <OPTION value='<%=rs5x("price10")%>'><%=rs5x("desc10")%></OPTION></SELECT><br>
      <input onChange="startCalc();" onBlur="stopCalc();" type=hidden name="quantity" value="<%=rs5x("desc4")%>" size="10">
    </td>
  </tr>
</table>
 <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
 <table border="0" cellpadding="0" cellspacing="0" width="100%" height="1">
        <tr>
          <td width="100%" height="1">

          <table border="0" cellspacing="0" width="100%" height="1">
  <tr>
    <td width="100%" height="1" class=textorange>Second Sheets<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
      <SELECT onChange="startCalc(); setForm8Value()" onBlur="stopCalc();" size=1 name=secondsheets1>
     <OPTION value='<%=rs7x("price1")%>'><%=rs7x("desc1")%>
      <OPTION value='<%=rs7x("price2")%>'><%=rs7x("desc2")%>
      <OPTION value='<%=rs7x("price3")%>'><%=rs7x("desc3")%>
      <OPTION value='<%=rs7x("price4")%>'><%=rs7x("desc4")%>
       <OPTION value='<%=rs7x("price5")%>'><%=rs7x("desc5")%></SELECT><br>
          <input type=hidden name="secondsheets" value="<%=rs7x("desc1")%>" size="10">
    </td>
  </tr>
</table>
          <!-- END FIRST BOX --></td>
        </tr>
      </table>

</td>
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
   <br><input type=hidden name="turnaround" value="<%=rsxx("desc1")%>" size="10">
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
<%

rs7x.Close
set rs7x = Nothing

conn7x.Close
Set conn7x = Nothing

%>