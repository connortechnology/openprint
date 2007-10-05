DROP	TABLE tbl_Paper_Recommendations;
CREATE	TABLE tbl_Paper_Recommendations (
		lngPaperIndex	INT4, FOREIGN KEY (lngPaperIndex) REFERENCES tbl_Paper (lngIndex),
		lngProjectTypeIndex	INT4,FOREIGN KEY (lngProjectTypeIndex) REFERENCES Project_Types (lngIndex)
);

CREATE INDEX Paper_Recommendations_Index ON tbl_Paper_Recommendations (lngPaperIndex ) ;
CREATE INDEX PR_ProjectType_Index ON tbl_Paper_recommendations (lngProjectTypeIndex);

