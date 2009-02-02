<%

dim conny, strConny

strConny = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conny = Server.CreateObject("ADODB.Connection")
conny.Open StrConny 


SQL = "SELECT * FROM usacurrency"

Set rsy = Server.CreateObject("ADODB.Recordset")

rsy.Open SQL, Conny

%>
