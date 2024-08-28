CREATE TABLE Skid_Verifications (
  id  SERIAL,
 skid_id    integer not null, foreign key (skid_id) references skids (id),  
 code       text,
 created_on timestamp with time zone not null default now(),
 user_id    integer, foreign key (user_id) references users (id),
PRIMARY KEY (id)
)

    CREATE INDEX skid_verifications_code_idx on skid_verifications (code);

