 <%

dim conn, strConn

strConn = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn = Server.CreateObject("ADODB.Connection")
conn.Open StrConn 


SQL = "SELECT * FROM papertype"

Set rs = Server.CreateObject("ADODB.Recordset")

Rs.Open SQL, Conn

%>