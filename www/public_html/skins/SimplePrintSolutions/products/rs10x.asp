<%

dim conn10x, strConn10x

strConn10x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn10x = Server.CreateObject("ADODB.Connection")
conn10x.Open StrConn10x 


SQL = "SELECT * FROM slotorientation"

Set rs10x = Server.CreateObject("ADODB.Recordset")

Rs10x.Open SQL, Conn10x

%>