DROP TABLE tbl_Testing;
DROP SEQUENCE lngTestID_seq;
CREATE SEQUENCE lngTestID_seq;

CREATE TABLE tbl_Testing (
	lngTestID						INT4 NOT NULL DEFAULT nextval('lngTestID_seq'),
	lngCaseNo						INT4,
	txtBusinessFunction				TEXT,
	txtUserLevel					TEXT,
	txtTestVersion					TEXT,
	txtCycle						TEXT,
	txtPath							TEXT,
	txtDescription					TEXT,
	txtOperatorAction				TEXT,
	txtExpectedResults				TEXT,
	txtDateTested					TEXT,
	txtTestedBy						TEXT,
	txtTestResults					TEXT,
	txtTesterComments				TEXT,
    txtPriority						TEXT,
	txtDeveloper					TEXT,
    txtDeveloperDateAssigned		TEXT,
	txtDeveloperComments			TEXT,	
	txtDeveloperRetestConditions	TEXT,	
	txtDeveloperRetestDate			TEXT,
	txtRetestedBy					TEXT,
	txtRetestResults				TEXT,
	txtRetesterComments				TEXT,
	txtRetestPriority				TEXT,
	txtCompletionDate				TEXT,
	txtRetestVersion				TEXT,
	PRIMARY KEY (lngTestID)
);

CREATE TABLE tbl_Test_People (
	chrType	char(1),
	txtName	TEXT
);

INSERT INTO tbl_Test_People VALUES ( 'T', 'anagy' );
INSERT INTO tbl_Test_People VALUES ( 'D', 'iconnor' );
INSERT INTO tbl_Test_People VALUES ( 'D', 'wcober' );
INSERT INTO tbl_Test_People VALUES ( 'D', 'classo' );
INSERT INTO tbl_Test_People VALUES ( 'D', 'rlee' );

CREATE TABLE tbl_User_Levels (
	txtName	TEXT
);

INSERT INTO tbl_User_Levels VALUES ( 'General Visitor' );
INSERT INTO tbl_User_Levels VALUES ( 'Account Holder' );
INSERT INTO tbl_User_Levels VALUES ( 'Employee' );
INSERT INTO tbl_User_Levels VALUES ( 'Administrator' );
INSERT INTO tbl_User_Levels VALUES ( 'Supplier' );

