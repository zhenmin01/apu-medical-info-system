use MedicalInfoSystem;
-- perform permission management for doctors

-- - Ensure doctors do not have direct access to the tables
DENY SELECT, INSERT, UPDATE, DELETE ON Patient TO Doctors;
DENY SELECT, INSERT, UPDATE, DELETE ON Diagnosis TO Doctors;
DENY SELECT, INSERT, UPDATE, DELETE ON Doctor TO Doctors;

-- Views
GRANT SELECT ON V_DoctorPersonalDetail TO Doctors;
GRANT SELECT ON V_AllDiagnosis TO Doctors;

-- Stored Procedures
GRANT EXECUTE ON SP_UpdateDoctorPersonalDetail TO Doctors;
GRANT EXECUTE ON SP_ManageDiagnosis TO Doctors;


-- perform permission management for patients

-- - Ensure patients do not have direct access to the tables
DENY SELECT, INSERT, UPDATE, DELETE ON Patient TO Patients;
DENY SELECT, INSERT, UPDATE, DELETE ON Diagnosis TO Patients;
DENY SELECT, INSERT, UPDATE, DELETE ON Doctor TO Patients;

-- - Views
GRANT SELECT ON V_PatientPersonalDetails TO Patients;
GRANT SELECT ON V_PatientDiagnosis TO Patients;


-- - Stored Procedures
GRANT EXECUTE ON SP_UpdatePatientPersonalDetail TO Patients;
GRANT EXECUTE ON SP_CheckPaymentDetail TO Patients;




-- create login for user as an SQL login
EXECUTE AS LOGIN='MISAdmin'
-- require ALTER ANY LOGIN permission
CREATE LOGIN P00001 WITH PASSWORD='P00001@medical'
CREATE LOGIN P00002 WITH PASSWORD='P00002@medical'
CREATE LOGIN D00001 WITH PASSWORD='D00001@medical'
CREATE LOGIN D00002 WITH PASSWORD='D00002@medical'
REVERT

-- Creating Users and add to Doctors and Patients

CREATE USER D00001 FOR LOGIN D00001;
CREATE USER D00002 FOR LOGIN D00002;
CREATE USER P00001 FOR LOGIN P00001;
CREATE USER P00002 FOR LOGIN P00002;

ALTER ROLE Doctors ADD MEMBER D00001;
ALTER ROLE Doctors ADD MEMBER D00002;
ALTER ROLE Patients ADD MEMBER P00001;
ALTER ROLE Patients ADD MEMBER P00002;

-- (can) add patient and doctor
-- -- add first patient (third in Patient table)
EXECUTE SP_AddPatient @NewPName = 'xxxxxxxxxxx', @NewPPhone= '+60000000000';
EXECUTE AS LOGIN='MISAdmin'
CREATE LOGIN P00003 WITH PASSWORD='P00003@medical'
REVERT
CREATE USER P00003 FOR LOGIN P00003;
ALTER ROLE Patients ADD MEMBER P00003;
-- -- add second patient (fourth in Patient table)
EXECUTE SP_AddPatient @NewPName = 'xxxxxxxxxxx', @NewPPhone= '+60000000000';
EXECUTE AS LOGIN='MISAdmin'
CREATE LOGIN P00004 WITH PASSWORD='P00004@medical'
REVERT
CREATE USER P00004 FOR LOGIN P00004;
ALTER ROLE Patients ADD MEMBER P00004;
-- -- add first doctor (third in Doctor table)
EXECUTE SP_AddDoctor @NewDName = 'xxxxxxxxxxx', @NewDPhone= '+60000000000';
EXECUTE AS LOGIN='MISAdmin'
CREATE LOGIN D00003 WITH PASSWORD='D00003@medical'
REVERT
CREATE USER D00003 FOR LOGIN D00003;
ALTER ROLE Doctors ADD MEMBER D00003;
-- -- add second doctor (fourth in Doctor table)
EXECUTE SP_AddDoctor @NewDName = 'xxxxxxxxxxx', @NewDPhone= '+60000000000';
EXECUTE AS LOGIN='MISAdmin'
CREATE LOGIN D00004 WITH PASSWORD='D00004@medical'
REVERT
CREATE USER D00004 FOR LOGIN D00004;
ALTER ROLE Doctors ADD MEMBER D00004;

-- (can) read existing doctors or patients’ data without sensitive details
-- non-sensitive columns is granted to the data admin
SELECT PID, PName FROM Patient;
SELECT DrID, DName FROM Doctor;

-- (cannot) read existing doctors or patients’ sensitive details including diagnosis
-- some sensitive columns already blocked to the data admin
SELECT * FROM Doctor;
SELECT * FROM Patient;
SELECT * FROM Diagnosis;

-- (cannot) modify doctors or patients’ sensitive details including diagnosis
-- by default the data admin does not have permission to update any column
UPDATE Patient
SET PaymentCardNo=HASHBYTES('SHA2_256','123456')
WHERE PID='P00001';

-- should be failed because data_admin does not have access to the SymKey_Med and Certificate_Med
-- despite giving access to the SymKey_Med and Certificate_Med, however, the update permission is denied
OPEN SYMMETRIC KEY SymKey_Med
	DECRYPTION BY CERTIFICATE Certificate_Med;
UPDATE Diagnosis
SET Diagnosis=EncryptByKey(Key_GUID('SymKey_Med'), 'You have 42 meningioma brain tumours.')
WHERE DiagID=1;
CLOSE SYMMETRIC KEY SymKey_Med;
--==========================================================================================

-- (can) modify doctor name using SP_ManageDoctor
EXECUTE SP_ManageDoctor @DrID='D00002', @NewDName='xxxxxxxxxxxx';
EXECUTE SP_ManageDoctor @DrID='D00002', @NewDName='xxxxxxxxxxxx';

-- (can) modify patient name using SP_ManagePatient
EXECUTE SP_ManagePatient @PID='P00002', @NewPName='xxxxxxxxxxxx';
EXECUTE SP_ManagePatient @PID='P00002', @NewPName='xxxxxxxxxxxx';

-- (can) delete data
-- - if the data admin accidentally delete data, then perform immediate recovery

-- - delete, recover diagnosis of patient 1
DELETE FROM Diagnosis
WHERE PatientID='P00002';

-- the data recovery is done by the super admin (db_owner)

-- - delete and recover patient 4 from table
SELECT PID, PName FROM Patient;
DELETE FROM Patient
WHERE PID='P00004'

-- - - query delete results
SELECT PID, PName FROM Patient WHERE RowStatus=1;

-- - - the patient 4 still exists in the database
SELECT PID, PName FROM Patient;

-- - - recover patient 4
UPDATE Patient
SET RowStatus=1
WHERE PID='P00004'; 
-- - - query active patient results
SELECT PID, PName FROM Patient WHERE RowStatus=1;


-- - delete and recover doctor 4 from table
SELECT DrID, DName FROM Doctor;
DELETE FROM Doctor
WHERE DrID='D00004'


-- - - query delete results
SELECT DrID, DName FROM Doctor WHERE RowStatus=1;

-- - - the doctor 4 still exists in the database
SELECT DrID, DName FROM Doctor;

-- - - recover patient 4
UPDATE Doctor
SET RowStatus=1
WHERE DrID='D00004'; 
-- - - query active patient results
SELECT DrID, DName FROM Doctor WHERE RowStatus=1;


-- view all data admin permission
SELECT dp.NAME      AS SubjectName,
       dp.TYPE_DESC AS SubjectType,
       o.NAME       AS ObjectName,
       o.type_desc as ObjectType,
       p.PERMISSION_NAME as Permission,
       p.STATE_DESC AS PermissionType
FROM sys.database_permissions p
     LEFT OUTER JOIN sys.all_objects o
          ON p.MAJOR_ID = o.OBJECT_ID
     INNER JOIN sys.database_principals dp
          ON p.GRANTEE_PRINCIPAL_ID = dp.PRINCIPAL_ID
and dp.is_fixed_role=0
and dp.Name in ('DataAdmin')
and p.state_desc='GRANT';



-- check all users
SELECT roles.[name] as role_name, members.[name] as user_name
FROM sys.database_role_members 
INNER JOIN sys.database_principals roles 
ON database_role_members.role_principal_id = roles.principal_id
INNER JOIN sys.database_principals members 
ON database_role_members.member_principal_id = members.principal_id
WHERE roles.name in ('Patients','Doctors','DataAdmin');
GO