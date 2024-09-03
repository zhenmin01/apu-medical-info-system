USE MedicalInfoSystem;
-- Testing Views and Stored Procedures
-- this time use SQL login to connect with the SQL server instance.


--(can) read or update personal details. If there is any encryption done, then those values must be decrypted automatically.
OPEN SYMMETRIC KEY SymKey_Med
 DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_DoctorPersonalDetail;
CLOSE SYMMETRIC KEY SymKey_Med;

SELECT * FROM V_DoctorPersonalDetail;
EXEC SP_UpdateDoctorPersonalDetail 
 @DrID='D00002', 
 @NewDName = 'xxxxxxxxxxxx', 
 @NewDPhone = '+60000000000';
SELECT * FROM V_DoctorPersonalDetail;

--(can) to add or modify a few diagnosis data for a few patients (can be existing or new) – this step may be repeated for another doctor
--insert new diagnosis
OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_AllDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;
DECLARE @MyUsername VARCHAR(6);
DECLARE @NewDiagID int;
SET @MyUsername = USER_NAME();

EXEC SP_ManageDiagnosis
@PatientID = 'P00001',
@Diagnosis = 'Sore throat.';

OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;

SELECT TOP 1 @NewDiagID = DiagID
FROM V_AllDiagnosis
WHERE PID = 'P00001' AND DrID = @MyUsername
ORDER BY DiagnosisDate DESC;

CLOSE SYMMETRIC KEY SymKey_Med;

-- All diagnosis after insert
OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_AllDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;

-- Update diagnosis
EXEC SP_ManageDiagnosis
@DiagID = 4,
@PatientID = 'P00002',
@Diagnosis = 'This patient diagnosed as having heart attack.';

EXEC SP_ManageDiagnosis
@DiagID = 6,
@PatientID = 'P00001',
@Diagnosis = 'Updated Diagnosis.';

-- All diagnosis after update
OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_AllDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;

--(can) read diagnosis details for any patient including those added by another doctor
OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_AllDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;
--(cannot) modify diagnosis details entered by another doctor
OPEN SYMMETRIC KEY SymKey_Med 
DECRYPTION BY CERTIFICATE Certificate_Med;
EXEC SP_ManageDiagnosis
@DiagID = 1,
@PatientID = 'P00002',
@Diagnosis = 'This patient diagnosed as having diabetes.';

OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_AllDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;

--(cannot) read or modify another user's (doctor or  patient) sensitive details
OPEN SYMMETRIC KEY SymKey_Med
 DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_DoctorPersonalDetail;
CLOSE SYMMETRIC KEY SymKey_Med;

EXEC SP_UpdateDoctorPersonalDetail 
@DrID='D00001', 
@NewDName = 'xxxxxxxxxxxx', 
@NewDPhone = '+60000000000';
--(cannot) delete any diagnosis details
OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_AllDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;

OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;
DECLARE @DiagIDToDelete INT;
SELECT TOP 1 @DiagIDToDelete = DiagID
FROM V_AllDiagnosis;
DELETE FROM Diagnosis WHERE DiagID = 4;
CLOSE SYMMETRIC KEY SymKey_Med;

OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_AllDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;
------------------------------------------------------------------------
 -- Validation for V_DoctorPersonalDetail (1st Doctor)
EXECUTE AS USER = 'D00001'
SELECT * FROM V_DoctorPersonalDetail;
REVERT

 -- Validation for V_DoctorPersonalDetail (2nd Doctor)
EXECUTE AS USER = 'D00002'
SELECT * FROM V_DoctorPersonalDetail;
REVERT

  -- Validation for V_AllDiagnosis (1st Doctor)
EXECUTE AS USER = 'D00001'
SELECT * FROM V_AllDiagnosis;
REVERT

  -- Validation for V_AllDiagnosis (2nd Doctor)
EXECUTE AS USER = 'D00002'
SELECT * FROM V_AllDiagnosis;
REVERT

 -- Validation for SP_UpdateDoctorPersonalDetail
EXECUTE AS USER = 'D00001'
SELECT * FROM V_DoctorPersonalDetail;
EXEC SP_UpdateDoctorPersonalDetail @DrID = 'D00001', @NewDName = 'xxxxxxxxxxxx',
@NewDPhone = '+60000000000';
SELECT * FROM V_DoctorPersonalDetail;
REVERT

-- Validation for SP_ManageDiagnosis
EXECUTE AS USER = 'D00002'

-- All Diagnosis before update
OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_AllDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;
DECLARE @MyUsername VARCHAR(6);
DECLARE @NewDiagID int;
SET @MyUsername = USER_NAME();

-- Scenario: inserting new diagnosis
EXEC SP_ManageDiagnosis
@PatientID = 'P00001',
@Diagnosis = 'Mild skin allergy.';
  
-- Retrieve new diagnosis ID for validation
OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;

SELECT TOP 1 @NewDiagID = DiagID
FROM V_AllDiagnosis
WHERE PID = 'P00001' AND DrID = @MyUsername
ORDER BY DiagnosisDate DESC;

CLOSE SYMMETRIC KEY SymKey_Med;

-- Update diagnosis
EXEC SP_ManageDiagnosis
@DiagID = @NewDiagID,
@PatientID = 'P00002',
@Diagnosis = 'This patient diagnosed as having sore throat.';

-- All Diagnosis After update
OPEN SYMMETRIC KEY SymKey_Med
DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_AllDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;
REVERT

 -- Check the permission
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
and dp.Name in ('Doctors')