CREATE	TABLE Paper_Recommendations (
		lngPaperIndex	INTEGER, FOREIGN KEY (lngPaperIndex) REFERENCES Papers (id),
		lngProjectTypeIndex	INTEGER, FOREIGN KEY (lngProjectTypeIndex) REFERENCES Project_Types (id)
);

CREATE INDEX PR_Paper_Index ON Paper_Recommendations (lngPaperIndex);
CREATE INDEX PR_ProjectType_Index ON Paper_recommendations (lngProjectTypeIndex);
