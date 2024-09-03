use MedicalInfoSystem;
-- Testing Views and Stored Procedures
-- this time use SQL login to connect with the SQL server instance.

--(can) to check their personal details and diagnosis details (this step may be repeated for another patient). If there is any encryption done, then those values must be decrypted automatically.
SELECT * FROM V_PatientPersonalDetails;

OPEN SYMMETRIC KEY SymKey_Med DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_PatientDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;

--(can) to update their personal details
SELECT * FROM V_PatientPersonalDetails;
EXEC SP_UpdatePatientPersonalDetail 
	@PID='P00001', 
	@NewPName = 'xxxxxxxxxxxx', 
	@NewPPhone = '+60000000000', 
	@NewPaymentCardNo='9999888877776666',
	@NewPaymentCardPin='999999';
SELECT * FROM V_PatientPersonalDetails;

--(cannot) modify their own diagnosis details.
OPEN SYMMETRIC KEY SymKey_Med DECRYPTION BY CERTIFICATE Certificate_Med;
UPDATE Diagnosis 
SET Diagnosis = EncryptByKey(Key_GUID('SymKey_Med'), 'This patient is diagnosed as having Diabetes Type-1 disease.')
WHERE PatientID = USER_NAME();
CLOSE SYMMETRIC KEY SymKey_Med;

--(cannot) modify another patient’s diagnosis details.
OPEN SYMMETRIC KEY SymKey_Med DECRYPTION BY CERTIFICATE Certificate_Med;
UPDATE Diagnosis 
SET Diagnosis = EncryptByKey(Key_GUID('SymKey_Med'), 'This patient is diagnosed as having Diabetes Type-1 disease.')
WHERE PatientID = 'P00002';
CLOSE SYMMETRIC KEY SymKey_Med;
------------------------------------------


-- - V_PatientPersonalDetails <1st Patient> (1st View)
EXECUTE AS USER = 'P00001'
SELECT * FROM V_PatientPersonalDetails;
REVERT

-- - V_PatientPersonalDetails <2nd Patient> (1st View)
EXECUTE AS USER = 'P00002'
SELECT * FROM V_PatientPersonalDetails;
REVERT

-- - V_PatientDiagnosis <1st Patient> (2nd View)
EXECUTE AS USER = 'P00001'
OPEN SYMMETRIC KEY SymKey_Med DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_PatientDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;
REVERT

-- - V_PatientDiagnosis <2nd Patient> (2nd View)
EXECUTE AS USER = 'P00002'
OPEN SYMMETRIC KEY SymKey_Med DECRYPTION BY CERTIFICATE Certificate_Med;
SELECT * FROM V_PatientDiagnosis;
CLOSE SYMMETRIC KEY SymKey_Med;
REVERT

-- - SP_UpdatePatientPersonalDetail <1st Patient>
-- -- should be successfull
EXECUTE AS USER = 'P00001'
SELECT * FROM V_PatientPersonalDetails;
EXEC SP_UpdatePatientPersonalDetail 
	@PID='P00001', 
	@NewPName = 'xxxxxxxxxxxx', 
	@NewPPhone = '+60000000000', 
	@NewPaymentCardNo='9999888877776666',
	@NewPaymentCardPin='999999';
SELECT * FROM V_PatientPersonalDetails;
REVERT

-- SP_CheckPaymentDetail
EXECUTE AS USER = 'P00001'
EXEC SP_CheckPaymentDetail
	@PID ='P00001', 
	@paymentCardNo ='9999888877776666', 
	@paymentCardPin = '999999'
REVERT

-- view all patients permission
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
and dp.Name in ('Patients');