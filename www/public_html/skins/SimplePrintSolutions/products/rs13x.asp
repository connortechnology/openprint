 <%

dim conn13x, strConn13x

strConn13x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn13x = Server.CreateObject("ADODB.Connection")
conn13x.Open StrConn13x 


SQL = "SELECT * FROM material"

Set rs13x = Server.CreateObject("ADODB.Recordset")

Rs13x.Open SQL, Conn13x

%>
