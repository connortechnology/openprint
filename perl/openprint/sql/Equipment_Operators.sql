CREATE TABLE Equipment_Operators (
    user_id INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
    equipment_id INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (id)
);
CREATE INDEX Equipment_Operators_idx on Equipment_Operators (equipment_id,user_id);
