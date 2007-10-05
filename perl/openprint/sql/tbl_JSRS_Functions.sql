CREATE TABLE tbl_JSRS_Functions (
	strName	TEXT,
	PRIMARY KEY (strName)
);

INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::paper::select_finish' );
INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::paper::select_colour' );
INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::paper::select_weight' );
INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::paper::select_sheetsize' );
INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::paper::select_paper_names' );
INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::paper::get_paper_object' );
INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::paper::select_by_weight' );
INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::paper::select_by_finish' );
INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::paper::select_by_colour' );
INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::paper::select_by_name' );
INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::print::get_imposition_array' );
INSERT INTO tbl_JSRS_Functions VALUES ( 'eprint::print_pricing::get_project_price' );
