<%

dim conn4x, strConn4x

strConn4x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn4x = Server.CreateObject("ADODB.Connection")
conn4x.Open StrConn4x 


SQL = "SELECT * FROM scoring"

Set rs4x = Server.CreateObject("ADODB.Recordset")

rs4x.Open SQL, Conn4x

%>