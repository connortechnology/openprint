<%

dim conn17x, strConn17x

strConn17x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn17x = Server.CreateObject("ADODB.Connection")
conn17x.Open StrConn17x 


SQL = "SELECT * FROM coverpaper"

Set rs17x = Server.CreateObject("ADODB.Recordset")

rs17x.Open SQL, Conn17x

%>
