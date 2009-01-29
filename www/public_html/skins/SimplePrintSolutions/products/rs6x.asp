<%

dim conn6x, strConn6x

strConn6x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn6x = Server.CreateObject("ADODB.Connection")
conn6x.Open StrConn6x 


SQL = "SELECT * FROM folding"

Set rs6x = Server.CreateObject("ADODB.Recordset")

rs6x.Open SQL, Conn6x

%>