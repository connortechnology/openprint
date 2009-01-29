<%

dim conn18x, strConn18x

strConn18x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn18x = Server.CreateObject("ADODB.Connection")
conn18x.Open StrConn18x 


SQL = "SELECT * FROM binder"

Set rs18x = Server.CreateObject("ADODB.Recordset")

rs18x.Open SQL, Conn18x

%>