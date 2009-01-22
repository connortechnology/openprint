<%@ Language="VBScript"%>
<%Title="Produts/Flyer"%>
<% Dim step, insdiscount
	step = "fase1"
	insdiscount = 100 
   choosescript= "flyer" 
%>
<!--#include file="rsy.asp" -->
<!--#include file="rs.asp" -->
<!--#include file="rsx.asp" -->
<!--#include file="rsxx.asp" -->
<!--#include file="rs3x.asp" -->
<!--#include file="rs4x.asp" -->
<!--#include file="rs8x.asp" -->
<%

dim conn5x, strConn5x

strConn5x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn5x = Server.CreateObject("ADODB.Connection")
conn5x.Open StrConn5x 


SQL = "SELECT * FROM FlyerPrice"

Set rs5x = Server.CreateObject("ADODB.Recordset")

rs5x.Open SQL, Conn5x

%>
<!--#include file="../headerpro.asp" -->
<table border="0" cellpadding="10" cellspacing="0"  width="584" height="470">
  <tr>
    <td valign="top" class=text>
<form name="autoSumForm" action=../shoppingcart/review_order.asp method="post">
<input type=hidden name=product value="Flyer">
<input name="sizep" type=hidden value="" size="10">
<input type=hidden name=xchange onFocus="startCalc();" onBlur="stopCalc();" value="<%=rsy("price1")%>">
<input type=hidden name=tfifty onFocus="startCalc();" onBlur="stopCalc();" value="50">
<input type=hidden onFocus="startCalc();" onBlur="stopCalc();" size=1 name=paper1 value="<%=rs("price1")%>">
<input name="paper" type=hidden value="<%=rs("desc1")%>" size="10">
 <table border="0" cellspacing="1" width="560">
  <tr>
    <td width="260" valign="top">
      <table border="0" cellpadding="10" cellspacing="0" width="100%" height="25">
        <tr>
          <td width="100%" height="260">
            <p align="center"><img border="0" src="images/flyerico.jpg" width="200" height="283"></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><b>Flyer<br>
            </b>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><!--<b>File Preparation:<br>
            </b>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
            <a href="../templates/flyer.asp" class="linksize">Download templates</a><br>-->
</td>
        </tr>
      </table>
    </td>
    <td bgcolor="#c9c9c9" width="300">
 
<table border="0" cellspacing="1" width="100%">
  <tr>
    <td width="100%">
      <table border="0" cellspacing="5" width="100%" cellpadding="5">
        <tr>
          <td width="100%" class=subtext><b>INSTANT PRICING</b></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td width="100%" bgcolor="#FFFFFF">
      <table border="0" cellpadding="5" cellspacing="5" width="100%" class=back3>
        <tr>
          <td width="100%">
          <!-- FIRST BOX -->
          <table border="0" cellspacing="0" width="100%" height="1">
  <tr>
    <td width="100%" colspan="2" height="1" class=textorange>Quantity<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
      <SELECT onChange="startCalc(); setForm1Value()" onBlur="stopCalc();" size=1 name=bprice>
     <OPTION value='<%=rs5x("price1")%>'><%=rs5x("desc1")%>
      <OPTION value='<%=rs5x("price2")%>'><%=rs5x("desc2")%>
      <OPTION value='<%=rs5x("price3")%>'><%=rs5x("desc3")%>
      <OPTION value='<%=rs5x("price4")%>'><%=rs5x("desc4")%>
      <OPTION value='<%=rs5x("price5")%>'><%=rs5x("desc5")%>
      <OPTION value='<%=rs5x("price6")%>'><%=rs5x("desc6")%>
      <OPTION value='<%=rs5x("price7")%>'><%=rs5x("desc7")%>
      <OPTION value='<%=rs5x("price8")%>'><%=rs5x("desc8")%>
      <OPTION value='<%=rs5x("price9")%>'><%=rs5x("desc9")%>
      <OPTION value='<%=rs5x("price10")%>'><%=rs5x("desc10")%></SELECT><br>
      <input onChange="startCalc();" onBlur="stopCalc();" type=hidden name="quantity" value="<%=rs5x("desc1")%>" size="10">
    </td>
  </tr>
  <tr>
    <td width="100%" height="2" valign="top" colspan="2"><hr size="1" color="#DADADA">
</td>
  </tr>
  <tr>
    <td width="100%" height="55" valign="top" class=textorange colspan="2">Colors&nbsp;<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
      <SELECT onChange="startCalc(); setForm2Value()" onBlur="stopCalc();" size=1 name=color1>
      	<option value='<%=rsx("price1")%>'><%=rsx("desc1")%>
		<option value='<%=rsx("price2")%>'><%=rsx("desc2")%>
		</SELECT><br>
      <input name="color" type=hidden value="<%=rsx("desc1")%>" size="10">
</td>
  </tr>
  <tr>
    <td width="100%" colspan="2" height="21" valign="top"><hr size="1" color="#DADADA">
    </td>
  </tr>
  <tr>
    <td width="100%" height="21" valign="top" class=textorange colspan="2">Height (Inches)<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
 	<SELECT onChange="startCalc();" onBlur="stopCalc();" size=1 name=height>
<option  value='2'>2
<option  value='2.25'>2.25
<option  value='2.5'>2.5
<option  value='2.75'>2.75
<option  value='3'>3
<option  value='3.25'>3.25
<option  value='3.5'>3.5
<option  value='3.75'>3.75
<option  value='4'>4
<option  value='4.25'>4.25
<option  value='4.5'>4.5
<option  value='4.75'>4.75
<option  value='5'>5
<option  value='5.25'>5.25
<option  value='5.5'>5.5
<option  value='5.75'>5.75
<option  value='6'>6
<option  value='6.25'>6.25
<option  value='6.5'>6.5
<option  value='6.75'>6.75
<option  value='7'>7
<option  value='7.25'>7.25
<option  value='7.5'>7.5
<option  value='7.75'>7.75
<option  value='8'>8
<option  value='8.25'>8.25
<option  value='8.5'>8.5
<option  value='8.75'>8.75
<option  value='9'>9
<option  value='9.25'>9.25
<option  value='9.5'>9.5
<option  value='9.75'>9.75
<option  value='10'>10
<option  value='10.25'>10.25
<option  value='10.5'>10.5
<option  value='10.75'>10.75
<option  value='11'>11
<option  value='11.25'>11.25
<option  value='11.5'>11.5
<option  value='11.75'>11.75
<option  value='12'>12
<option  value='12.25'>12.25
<option  value='12.5'>12.5
<option  value='12.75'>12.75
<option  value='13'>13
<option  value='13.25'>13.25
<option  value='13.5'>13.5
<option  value='13.75'>13.75
<option  value='14'>14
<option  value='14.25'>14.25
<option  value='14.5'>14.5
<option  value='14.75'>14.75
<option  value='15'>15
<option  value='15.25'>15.25
<option  value='15.5'>15.5
<option  value='15.75'>15.75
<option  value='16'>16
<option  value='16.25'>16.25
<option  value='16.5'>16.5
<option  value='16.75'>16.75
<option  value='17'>17</SELECT>
<br>
</td>
  </tr>
  <tr>
    <td width="46%" height="21" valign="top" class=textorange>&nbsp;
</td>
    <td width="54%" height="21" valign="top">

    </td>
  </tr>
  <tr>
    <td width="100%" height="21" valign="top" class=textorange colspan="2">Width (Inches)<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
 	<SELECT onChange="startCalc();" onBlur="stopCalc();" size=1 name=width>
<option  value='2'>2
<option  value='2.25'>2.25
<option  value='2.5'>2.5
<option  value='2.75'>2.75
<option  value='3'>3
<option  value='3.25'>3.25
<option  value='3.5'>3.5
<option  value='3.75'>3.75
<option  value='4'>4
<option  value='4.25'>4.25
<option  value='4.5'>4.5
<option  value='4.75'>4.75
<option  value='5'>5
<option  value='5.25'>5.25
<option  value='5.5'>5.5
<option  value='5.75'>5.75
<option  value='6'>6
<option  value='6.25'>6.25
<option  value='6.5'>6.5
<option  value='6.75'>6.75
<option  value='7'>7
<option  value='7.25'>7.25
<option  value='7.5'>7.5
<option  value='7.75'>7.75
<option  value='8'>8
<option  value='8.25'>8.25
<option  value='8.5'>8.5
<option  value='8.75'>8.75
<option  value='9'>9
<option  value='9.25'>9.25
<option  value='9.5'>9.5
<option  value='9.75'>9.75
<option  value='10'>10
<option  value='10.25'>10.25
<option  value='10.5'>10.5
<option  value='10.75'>10.75
<option  value='11'>11
<option  value='11.25'>11.25
<option  value='11.5'>11.5
<option  value='11.75'>11.75
<option  value='12'>12
<option  value='12.25'>12.25
<option  value='12.5'>12.5
<option  value='12.75'>12.75
<option  value='13'>13</SELECT>
<br>
</td>
  </tr>
  <tr>
    <td width="100%" colspan="2" height="21" valign="top"><hr size="1" color="#DADADA">
    </td>
  </tr>
</table>

          <table border="0" cellspacing="0" width="100%" height="1">
          </table>
          <table border="0" cellspacing="0" width="100%" height="1">
            <tr>
              <td width="100%" height="21" valign="top" class="textorange">Hole
                Drilling<br>
                <img border="0" src="../images/spaziatore.gif" height="6" width="15"><br>
                <select onChange="startCalc(); setForm9Value()" onBlur="stopCalc();" size="1" name="holedrilling1">
                  <option value="<%=rs8x("price2")%>"><%=rs8x("desc2")%></option>
                  <option value="<%=rs8x("price1")%>"><%=rs8x("desc1")%></option>
                </select><br><input name="holedrilling" type=hidden value="<%=rs8x("desc2")%>" size="10">
              </td>
            </tr>
            <tr>
              <td width="100%" height="21" valign="top">
                <hr size="1" color="#DADADA">
              </td>
            </tr>
            <tr>
              <td width="100%" height="21" valign="top" class="textorange">Scoring<br>
                <img border="0" src="../images/spaziatore.gif" height="6" width="15"><br>
                <select onChange="startCalc(); setForm6Value()" onBlur="stopCalc();" size="1" name="scoring1">
                  <option value="<%=rs4x("price2")%>"><%=rs4x("desc2")%></option>
                  <option value="<%=rs4x("price1")%>"><%=rs4x("desc1")%></option>
                </select><input name="scoring" type=hidden value="<%=rs4x("desc2")%>" size="10"></td>
            </tr>
          </table>
          <table border="0" cellspacing="0" width="100%" height="1">
            <tr>
              <td width="100%" height="21" valign="top">
                <hr size="1" color="#DADADA">
              </td>
            </tr>
            <tr>
              <td width="100%" height="21" valign="top" class="textorange">Perforation<br>
                <img border="0" src="../images/spaziatore.gif" height="6" width="15"><br>
                <select onChange="startCalc(); setForm5Value()" onBlur="stopCalc();" size="1" name="perforation1">
                  <option value="<%=rs3x("price2")%>"><%=rs3x("desc2")%></option>
                  <option value="<%=rs3x("price1")%>"><%=rs3x("desc1")%></option>
                </select><input name="perforation" type=hidden value="<%=rs3x("desc2")%>" size="10"></td>
            </tr>
          </table>
          <table border="0" cellspacing="0" width="100%" height="1">
</table>

          <!-- END FIRST BOX --></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td width="100%" bgcolor="#FFFFFF">
    <table border="0" cellpadding="5" cellspacing="5" width="100%" class=back3>
        <tr>
          <td width="100%">
          <!-- SECOND BOX -->
             <img border="0" src="../images/spaziatore.gif" height=5 width="15"><br>
   <font class=textorange>Turnaround</font><br>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
   <select onChange="startCalc(); setForm4Value()" onBlur="stopCalc();" name="turnaround1">
					<option selected="selected" value='<%=rsxx("price1")%>'><%=rsxx("desc1")%></option>
					<option value='<%=rsxx("price2")%>'><%=rsxx("desc2")%>
					<option value='<%=rsxx("price3")%>'><%=rsxx("desc3")%>
				</select>
   <br><input name="turnaround" type=hidden value="<%=rsxx("desc1")%>" size="10">
   <img border="0" src="../images/spaziatore.gif" height=5 width="15"><!-- END SECOND BOX --></td>
        </tr>
      </table>

    </td>
  </tr>
  <tr>
    <td width="100%" bgcolor="#FFFFFF">
    
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
    <td width="100%" bgcolor="#FFFFFF">
    
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

rs3x.Close
set rs3x = Nothing

conn3x.Close
Set conn3x = Nothing

%>

<%

rs5x.Close
set rs5x = Nothing

conn5x.Close
Set conn5x = Nothing

%>
<%

rs4x.Close
set rs4x = Nothing

conn4x.Close
Set conn4x = Nothing

%>
<%

rs8x.Close
set rs8x = Nothing

conn8x.Close
Set conn8x = Nothing

%>