<%

dim conn7x, strConn7x

strConn7x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn7x = Server.CreateObject("ADODB.Connection")
conn7x.Open StrConn7x 


SQL = "SELECT * FROM secondsheet"

Set rs7x = Server.CreateObject("ADODB.Recordset")

rs7x.Open SQL, Conn7x

%>