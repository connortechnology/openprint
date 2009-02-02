 <%

dim conn3x, strConn3x

strConn3x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn3x = Server.CreateObject("ADODB.Connection")
conn3x.Open StrConn3x 


SQL = "SELECT * FROM perforation"

Set rs3x = Server.CreateObject("ADODB.Recordset")

Rs3x.Open SQL, Conn3x

%>