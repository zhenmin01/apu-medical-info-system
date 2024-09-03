-- create database
create Database MedicalInfoSystem;
go;

-- create master key encryption, asymmetric key, certificate, and symmetric key
Use MedicalInfoSystem;
go;
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'QwErTy12345!@#$%';
CREATE ASYMMETRIC KEY MedicalAsymKey 
	WITH ALGORITHM = RSA_2048;
CREATE CERTIFICATE Certificate_Med 
	WITH SUBJECT = 'Protect With Symmetric';
CREATE SYMMETRIC KEY SymKey_Med 
	WITH ALGORITHM = AES_256 
	ENCRYPTION BY CERTIFICATE Certificate_Med;
go;
-- activate symmetric key
OPEN SYMMETRIC KEY SymKey_Med
	DECRYPTION BY CERTIFICATE Certificate_Med;
go;

-- create tables
CREATE TABLE Doctor(
	DrID varchar(6) DEFAULT('D00000') primary key,
	DName varchar(100) DEFAULT('Please Enter Your Full Name.') NOT NULL,
	DPhone Varbinary(max) DEFAULT(EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'),'+60000000000')) NOT NULL
)
CREATE TABLE Patient(
	PID varchar(6) DEFAULT('P00000') primary key,
	PName varchar(100) DEFAULT('Please Enter Your Full Name.') NOT NULL,
	PPhone Varbinary(max) DEFAULT(EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'),'+60000000000')) NOT NULL,
	PaymentCardNo Varbinary(max) DEFAULT(EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'),'0000000000000000')) NOT NULL,
	PaymentCardPin Varbinary(max) DEFAULT(HASHBYTES('SHA2_256','000000')) NOT NULL
)
CREATE TABLE Diagnosis(
	DiagID int identity(1,1) primary key,
	PatientID varchar(6) DEFAULT('P00000') references Patient(PID) NOT NULL,
	DoctorID varchar(6) DEFAULT('D00000') references Doctor(DrID) NOT NULL,
	DiagnosisDate datetime NOT NULL,
	Diagnosis Varbinary(max) NOT NULL
)
go;

-- enable system versioning for diagnosis
ALTER TABLE Diagnosis
ADD ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START DEFAULT SYSUTCDATETIME(),
    ValidTo DATETIME2 GENERATED ALWAYS AS ROW END DEFAULT CONVERT(DATETIME2, '9999-12-31 23:59:59.9999999'),
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);

ALTER TABLE Diagnosis
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.DiagnosisHistory));
GO;

-- create instead of triggers on patient and doctor table
-- soft delete on patient data
-- -- add a status column
ALTER TABLE Patient
ADD [RowStatus] INT DEFAULT 1;
GO;
-- set row status to 1 for existing data
UPDATE Patient SET [RowStatus]=1;
GO;

-- -- create a soft delete trigger on patient table
CREATE OR ALTER TRIGGER SoftDeletePatientTable
ON Patient 
INSTEAD OF  
DELETE
AS 
Begin
    UPDATE Patient
    Set [RowStatus]=0
    FROM Patient p
    INNER JOIN deleted d ON p.PID = d.PID;
End;

-- soft delete on doctor data
-- -- add a status column
ALTER TABLE Doctor
ADD [RowStatus] INT DEFAULT 1;
GO;
-- set row status to 1 for existing data
UPDATE Doctor SET [RowStatus]=1;
GO;

-- -- create a soft delete trigger on doctor table
CREATE OR ALTER TRIGGER SoftDeleteDoctorTable
ON Doctor 
INSTEAD OF
DELETE
AS 
Begin
    UPDATE Doctor
    Set [RowStatus]=0
    FROM Doctor p
    INNER JOIN deleted d ON p.DrID = d.DrID;
End;

-- create views
-- -- V_DoctorPersonalDetail (Doctor)
CREATE VIEW V_DoctorPersonalDetail As
	Select DrID, DName,
	CONVERT(varchar(20), DECRYPTBYASYMKEY(AsymKey_ID('MedicalAsymKey'),DPhone)) As
	DPhone
	From Doctor
	Where DrID = USER_NAME();
go;

-- -- V_AllDiagnosis (Doctor)
CREATE VIEW V_AllDiagnosis As
	Select D.DiagID, P.PID, P.PName, Dr.DrID, Dr.DName, D.DiagnosisDate,
	CONVERT(varchar(max), DECRYPTBYKEY(D.Diagnosis)) As Diagnosis
	From Diagnosis D
	INNER JOIN Patient P ON D.PatientID=P.PID
	INNER JOIN Doctor Dr ON D.DoctorID=Dr.DrID;
go;

-- -- V_PatientPersonalDetails (Patient)
CREATE VIEW V_PatientPersonalDetails AS
	SELECT 
		PID,
		PName, -- PName is not encrypted
		CONVERT(varchar(20), DecryptByAsymKey(AsymKey_ID('MedicalAsymKey'), PPhone)) AS PPhone,
		CONVERT(varchar(20), DecryptByAsymKey(AsymKey_ID('MedicalAsymKey'), PaymentCardNo)) AS PaymentCardNo
	FROM 
		Patient
	WHERE 
		PID = USER_NAME();
GO

-- -- V_PatientPersonalDetails (Patient)
CREATE VIEW V_PatientDiagnosis AS
	SELECT 
		P.PName, 
		Dr.DName, 
		D.DiagnosisDate, 
		CONVERT(varchar(max), DECRYPTBYKEY(D.Diagnosis)) As Diagnosis
	FROM Diagnosis D
		INNER JOIN Patient P ON D.PatientID=P.PID
		INNER JOIN Doctor Dr ON D.DoctorID=Dr.DrID
	WHERE D.PatientID = USER_NAME();
GO;

-- create SPs

-- -- SP_AddPatient (data_admin)
CREATE PROCEDURE SP_AddPatient
    @NewPName varchar(100) = NULL,
    @NewPPhone varchar(20) = NULL
AS
BEGIN
	--Check PName is not NULL
	IF @NewPName IS NOT NULL
	BEGIN
		--Check PPhone is not NULL
		IF @NewPPhone IS NOT NULL
		BEGIN
			-- Check phone number format: start with '+' sign and contains only numbers
			IF @NewPPhone LIKE '[+]%' AND ISNUMERIC(SUBSTRING(@NewPPhone,2,LEN(@NewPPhone)-1))=1
			BEGIN
				--Auto generate ID
				DECLARE @PID varchar(6);
				DECLARE @latestPID VARCHAR(6), @NBR INT
				IF NOT EXISTS (SELECT TOP 1 PID FROM Patient ORDER BY PID DESC)
				BEGIN 
					SET @PID = 'P00001';
				END
				ELSE 
				BEGIN
					SELECT TOP 1 @latestPID = PID FROM Patient ORDER BY PID DESC
					SELECT @NBR = CAST(RIGHT(@latestPID, LEN(@latestPID) - 1) AS INT)
					SET @PID = 'P' + REPLACE(STR(@NBR+1,5),' ', '0')
				END
				INSERT INTO Patient (PID, PName, PPhone)
				VALUES (@PID, @NewPName, EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'), @NewPPhone));
			END
			ELSE
			BEGIN
				PRINT ('Invalid phone number.');
			END
		END
		ELSE
		BEGIN
			PRINT ('Error, patient phone number must not be empty!')
		END
	END
	ELSE
	BEGIN 
		PRINT ('Error, patient name must not be empty!')
	END
END;
GO;

-- -- SP_ManagePatient (data_admin)
CREATE PROCEDURE SP_ManagePatient
    @PID varchar(6),
    @NewPName varchar(100) = NULL
AS
BEGIN
	-- Check PID is not NULL
	IF @PID IS NULL
	BEGIN
		RAISERROR ('PID cannot be empty.', 16, 1);
		RETURN;
	END
	ELSE
	BEGIN
		--Check if PID exist or not
		IF NOT EXISTS (SELECT * FROM Patient WHERE PID = @PID)
		BEGIN
			RAISERROR ('Please provide existing PID.', 16, 1);
			RETURN;
		END
		ELSE
		BEGIN
			-- Check PName is not NULL
			IF @NewPName IS NULL
			BEGIN
				RAISERROR ('Empty patient name. Please fill in patient name.', 16, 1);
				RETURN;
			END
			ELSE
			BEGIN
				--Update PName if @NewPName is not NULL
				IF @NewPName IS NOT NULL
				BEGIN
					UPDATE Patient
					SET PName = @NewPName
					WHERE PID = @PID;
				END
			END
		END
	END
END;
GO;

-- -- SP_AddDoctor (data_admin)
CREATE PROCEDURE SP_AddDoctor
    @NewDName varchar(100) = NULL,
    @NewDPhone varchar(20) = NULL
AS
BEGIN
	--Check DName is not NULL
	IF @NewDName IS NOT NULL
	BEGIN
		--Check DPhone is not NULL
		IF @NewDPhone IS NOT NULL
		BEGIN
			-- Check phone number format: start with '+' sign and contains only numbers
			IF @NewDPhone LIKE '[+]%' AND ISNUMERIC(SUBSTRING(@NewDPhone,2,LEN(@NewDPhone)-1))=1
			BEGIN
				--Auto generate ID
				DECLARE @DrID varchar(6);
				DECLARE @latestDrID VARCHAR(6), @NBR INT
				IF NOT EXISTS (SELECT TOP 1 DrID FROM Doctor ORDER BY DrID DESC)
				BEGIN 
					SET @DrID = 'D00001';
				END
				ELSE 
				BEGIN
					SELECT TOP 1 @latestDrID = DrID FROM Doctor ORDER BY DrID DESC
					SELECT @NBR = CAST(RIGHT(@latestDrID, LEN(@latestDrID) - 1) AS INT)
					SET @DrID = 'D' + REPLACE(STR(@NBR+1,5),' ', '0')
				END
				INSERT INTO Doctor (DrID, DName, DPhone)
				VALUES (@DrID, @NewDName, EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'), @NewDPhone))
			END
			ELSE
			BEGIN
				PRINT ('Invalid phone number.');
			END
		END
		ELSE
		BEGIN
			PRINT ('Error, doctor phone number must not be empty!')
		END
	END
	ELSE
	BEGIN 
		PRINT ('Error, doctor name must not be empty!')
	END
END;
GO;

-- -- SP_ManageDoctor (data_admin)
CREATE PROCEDURE SP_ManageDoctor
    @DrID varchar(6),
    @NewDName varchar(100) = NULL
AS
BEGIN
	-- Check DrID is not NULL
	IF @DrID IS NULL
	BEGIN
		RAISERROR ('DrID cannot be empty.', 16, 1);
		RETURN;
	END
	ELSE
	BEGIN
		--Check DrID exist or not
		IF NOT EXISTS (SELECT * FROM Doctor WHERE DrID = @DrID)
		BEGIN
			RAISERROR ('Please provide existing DrID.', 16, 1);
			RETURN;
		END
		ELSE
		BEGIN
			-- Check DName is not NULL
			IF @NewDName IS NULL
			BEGIN
				RAISERROR ('Empty doctor name. Please fill in doctor name.', 16, 1);
				RETURN;
			END
			ELSE
			BEGIN
				--Update DName if @NewDName is not NULL
				IF @NewDName IS NOT NULL
				BEGIN
					UPDATE Doctor
					SET DName = @NewDName
					WHERE DrID = @DrID;
				END
			END
		END
	END
END;
GO;

-- -- SP_RecoverDiagnosis
ALTER PROCEDURE SP_RecoverDiagnosis
	@StartDeletionDateTime varchar(100),
	@EndDeletionDateTime varchar(100)
AS
BEGIN
	SET IDENTITY_INSERT Diagnosis ON;
	INSERT INTO Diagnosis (DiagID,PatientID,DoctorID,DiagnosisDate,Diagnosis)
	SELECT DiagID,PatientID,DoctorID,DiagnosisDate,Diagnosis
	FROM (
		SELECT 
			*,
			ROW_NUMBER() OVER (PARTITION BY diagID ORDER BY ValidTo DESC, ValidFrom DESC) AS rn
		FROM Diagnosis FOR SYSTEM_TIME ALL
		WHERE ValidTo < SYSDATETIME()  -- This filters for rows that are no longer valid
		AND ValidFrom < CONVERT(DATETIME2, @StartDeletionDateTime) AND ValidFrom > CONVERT(DATETIME2, @EndDeletionDateTime) 
	) AS subquery
	WHERE rn = 1;
	SET IDENTITY_INSERT Diagnosis OFF;
END
go;

-- -- SP_UpdateDoctorPersonalDetail (Doctor)
CREATE PROCEDURE SP_UpdateDoctorPersonalDetail
    @DrID varchar(6),
    @NewDName varchar(100) = NULL,
    @NewDPhone varchar(20) = NULL
AS
BEGIN
    -- Ensure that the @DrID matches the current user's DrID
    IF @DrID != USER_NAME()
    BEGIN
        RAISERROR ('Update failed. You do not have permission to update this record.', 16, 1);
        RETURN;
    END

    -- Update DName if @NewDName is not NULL
    IF @NewDName IS NOT NULL
    BEGIN
        UPDATE Doctor
        SET DName = CONVERT(varbinary(max), @NewDName)
        WHERE DrID = @DrID;
    END

	-- Update PPhone if @NewPPhone is not NULL
    IF @NewDPhone IS NOT NULL
    BEGIN
		-- Check phone number format: start with '+' sign and contains only numbers
		IF @NewDPhone LIKE '[+]%' AND ISNUMERIC(SUBSTRING(@NewDPhone,2,LEN(@NewDPhone)-1))=1
		BEGIN
			UPDATE Doctor
			SET DPhone = EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'), @NewDPhone)
			WHERE DrID = @DrID;
		END
		ELSE
		BEGIN
			PRINT ('Invalid phone number.');
		END
    END

    -- Check if any updates were performed
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR ('Update failed. No changes were made.', 16, 1);
    END
END;
go;

-- -- SP_ManageDiagnosis (Doctor)
CREATE PROCEDURE SP_ManageDiagnosis
    @DiagID int = NULL,
    @PatientID varchar(6) = NULL,
    @Diagnosis varchar(max) = NULL
AS
BEGIN
    -- Check if PatientID exists
    IF NOT EXISTS (SELECT PID FROM Patient WHERE PID = @PatientID)
    BEGIN
        RAISERROR ('Operation failed. Patient ID does not exist.', 16, 1);
        RETURN;
    END

    -- Check if Diagnosis is not null
    IF @Diagnosis IS NULL
    BEGIN
        RAISERROR ('Operation failed. Diagnosis cannot be null.', 16, 1);
        RETURN;
    END

	-- Open the symmetric key
	OPEN SYMMETRIC KEY SymKey_Med
	DECRYPTION BY CERTIFICATE Certificate_Med;

	-- Check if DiagID is provided
	IF @DiagID IS NULL
	BEGIN
	-- Insert new diagnosis record
		INSERT INTO Diagnosis (PatientID,DoctorID,DiagnosisDate,Diagnosis) 
		VALUES (@PatientID, USER_NAME(), GETDATE(), EncryptByKey(Key_GUID('SymKey_Med'), @Diagnosis));
	END
	ELSE
	BEGIN
		-- Check if DiagID exists
		IF NOT EXISTS (SELECT DiagID FROM Diagnosis WHERE DiagID = @DiagID)
		BEGIN
			RAISERROR ('Update failed. Diagnosis ID does not exist.', 16, 1);
			CLOSE SYMMETRIC KEY SymKey_Med;
			RETURN;
		END

		-- Update the Diagnosis and DiagnosisDate if the record exists
		UPDATE Diagnosis
		SET Diagnosis = EncryptByKey(Key_GUID('SymKey_Med'), @Diagnosis),
		DiagnosisDate = GETDATE()
		WHERE DoctorID = USER_NAME() AND PatientID = @PatientID AND DiagID = @DiagID;

		-- Check if any updates were performed
		IF @@ROWCOUNT = 0
		BEGIN
			RAISERROR ('Update failed. No changes were made.', 16, 1);
		END
	END
	-- Close the symmetric key
	CLOSE SYMMETRIC KEY SymKey_Med;
END
go;

-- -- SP_UpdatePatientPersonalDetail (Patient)
CREATE PROCEDURE SP_UpdatePatientPersonalDetail
    @PID varchar(6),
    @NewPName varchar(100) = NULL,
    @NewPPhone varchar(20) = NULL,
    @NewPaymentCardNo varchar(20) = NULL,
	@NewPaymentCardPin varchar(6) = NULL
AS
BEGIN
    -- Ensure that the @PID matches the current user's PID
    IF @PID != USER_NAME()
    BEGIN
        RAISERROR ('Update failed. You do not have permission to update this record.', 16, 1);
        RETURN;
    END

    -- Update PName if @NewPName is not NULL
    IF @NewPName IS NOT NULL
    BEGIN
        UPDATE Patient
        SET PName = CONVERT(varbinary(max), @NewPName)
        WHERE PID = @PID;
    END

    -- Update PPhone if @NewPPhone is not NULL
    IF @NewPPhone IS NOT NULL
    BEGIN
		-- Check phone number format: start with '+' sign and contains only numbers
		IF @NewPPhone LIKE '[+]%' AND ISNUMERIC(SUBSTRING(@NewPPhone,2,LEN(@NewPPhone)-1))=1
		BEGIN
			UPDATE Patient
			SET PPhone = EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'), @NewPPhone)
			WHERE PID = @PID;
		END
		ELSE
		BEGIN
			PRINT ('Invalid phone number.');
		END
    END

    -- Update PaymentCardNo if @NewPaymentCardNo is not NULL
    IF @NewPaymentCardNo IS NOT NULL
    BEGIN
		-- Check payment card number format: contains only numbers
		IF ISNUMERIC(@NewPaymentCardNo)=1
		BEGIN
			UPDATE Patient
			SET PaymentCardNo = EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'), @NewPaymentCardNo)
			WHERE PID = @PID;
		END
		ELSE
		BEGIN
			PRINT ('Invalid payment card number.');
		END
    END

	-- Update PaymentCardPin if @NewPaymentCardPin is not NULL
    IF @NewPaymentCardPin IS NOT NULL
    BEGIN
		-- Check payment card number format: contains only numbers
		IF ISNUMERIC(@NewPaymentCardPin)=1
		BEGIN
		    UPDATE Patient
			SET PaymentCardPin = HASHBYTES('SHA2_256',@NewPaymentCardPin)
			WHERE PID = @PID;
		END
		ELSE
		BEGIN
			PRINT ('Invalid payment card PIN.');
		END
    END

    -- Check if any updates were performed
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR ('Update failed. No changes were made.', 16, 1);
    END
END;
GO;

-- -- SP_CheckPaymentDetail (Patient)
CREATE PROCEDURE SP_CheckPaymentDetail
	@PID varchar(6) = NULL, 
	@paymentCardNo varchar(20) = NULL, 
	@paymentCardPin varchar(6) = NULL
AS
BEGIN
	-- Ensure that the @PID matches the current user's PID
    IF @PID != USER_NAME()
    BEGIN
        RAISERROR ('Retrieve failed. You do not have permission to retrieve this record.', 16, 1);
        RETURN;
    END
	IF @paymentCardNo IS NULL OR @paymentCardPin IS NULL
	BEGIN
		RAISERROR ('Empty payment card number or payment card PIN. Please fill in both details.', 16, 1);
        RETURN;
	END
	ELSE
	BEGIN 
		-- validate paymentCardNo format
		IF ISNUMERIC(@paymentCardNo)!=1 OR ISNUMERIC(@paymentCardPin)!=1
		BEGIN
			RAISERROR ('Please enter only numbers.', 16, 1);
		END
		ELSE
		BEGIN
			DECLARE @StoredCardNo VARCHAR(16)
			DECLARE @StoredCardPin VARBINARY(MAX)
			SELECT @StoredCardNo = CONVERT(VARCHAR(20), DECRYPTBYASYMKEY(ASYMKEY_ID('MedicalAsymKey'),paymentCardNo)) 
				FROM Patient
				WHERE PID = @PID;
			SELECT @StoredCardPin = paymentCardPin 
				FROM Patient
				WHERE PID = @PID;
			IF @paymentCardNo = @StoredCardNo AND @StoredCardPin = HASHBYTES('SHA2_256',@paymentCardPin)
			BEGIN
				PRINT ('Your payment information is correct.');
				RETURN
			END
			ELSE
			BEGIN
				RAISERROR('Incorrect payment information.', 16, 1);
				RETURN
			END
		END
	END
END;
GO;


-- create role data_admin
use MedicalInfoSystem;
CREATE ROLE DataAdmin;
CREATE ROLE Doctors;
CREATE ROLE Patients;

-- create login, user MISAdmin, add user to DataAdmin
CREATE LOGIN MISAdmin WITH PASSWORD='MISAdmin@123';
CREATE USER MISAdmin FOR LOGIN MISAdmin;
ALTER ROLE DataAdmin ADD MEMBER MISAdmin;

USE master;
GRANT ALTER ANY LOGIN TO MISAdmin; -- this is login MISAdmin (server level)

-- data admin
-- -- create user, add user to role
-- -- cannot create login as database user of role DataAdmin
-- -- because creating login is server-level action, which is cannot be performed by a database user at database level.
USE MedicalInfoSystem;
GRANT ALTER ON ROLE::Doctors TO DataAdmin; -- can alter role doctors add/remove user
GRANT ALTER ON ROLE::Patients TO DataAdmin; -- can alter role patients add/remove user
GRANT ALTER ANY USER TO DataAdmin; -- can create/alter/remove any user


USE MedicalInfoSystem;
-- permission management on asymmetric and symmetric key, and certificate
-- grant DataAdmin, Patients and Doctors.
GRANT CONTROL ON ASYMMETRIC KEY ::MedicalAsymKey TO DataAdmin;
GRANT CONTROL ON CERTIFICATE ::Certificate_Med TO DataAdmin;
GRANT CONTROL ON SYMMETRIC KEY ::SymKey_Med TO DataAdmin;

GRANT CONTROL ON ASYMMETRIC KEY ::MedicalAsymKey TO Doctors;
GRANT CONTROL ON CERTIFICATE ::Certificate_Med TO Doctors;
GRANT CONTROL ON SYMMETRIC KEY ::SymKey_Med TO Doctors;

GRANT CONTROL ON ASYMMETRIC KEY ::MedicalAsymKey TO Patients;
GRANT CONTROL ON CERTIFICATE ::Certificate_Med TO Patients;
GRANT CONTROL ON SYMMETRIC KEY ::SymKey_Med TO Patients;

-- permission management for DataAdmin

-- -- DataAdmin can perform permission management
GRANT CONTROL ON Patient TO DataAdmin;
GRANT CONTROL ON Diagnosis TO DataAdmin;
GRANT CONTROL ON Doctor TO DataAdmin;

GRANT CONTROL ON V_DoctorPersonalDetail TO DataAdmin;
GRANT CONTROL ON V_AllDiagnosis TO DataAdmin;
GRANT CONTROL ON V_PatientPersonalDetails TO DataAdmin;
GRANT CONTROL ON V_PatientDiagnosis TO DataAdmin;

GRANT CONTROL ON SP_ManageDoctor TO DataAdmin;
GRANT CONTROL ON SP_ManagePatient TO DataAdmin;
GRANT CONTROL ON SP_UpdateDoctorPersonalDetail TO DataAdmin;
GRANT CONTROL ON SP_ManageDiagnosis TO DataAdmin;
GRANT CONTROL ON SP_UpdatePatientPersonalDetail TO DataAdmin;
GRANT CONTROL ON SP_CheckPaymentDetail TO DataAdmin;

-- -- grant delete on tables
GRANT DELETE ON Patient TO DataAdmin;
GRANT DELETE ON Diagnosis TO DataAdmin;
GRANT DELETE ON Doctor TO DataAdmin;

-- data admin can add new user to table, no access to the diagnosis
GRANT INSERT ON Patient to DataAdmin;
GRANT INSERT ON Doctor to DataAdmin;
DENY INSERT, UPDATE ON Diagnosis TO DataAdmin;

GRANT SELECT ON DiagnosisHistory TO DataAdmin;

-- -- deny select, update to sensitive data
DENY SELECT, UPDATE ON Patient(PPhone,PaymentCardNo,PaymentCardPin) TO DataAdmin;
DENY SELECT, UPDATE ON Diagnosis(Diagnosis) TO DataAdmin;
DENY SELECT, UPDATE ON Doctor(DPhone) TO DataAdmin;

-- -- deny select from patients' and doctors' views
DENY SELECT ON V_DoctorPersonalDetail TO DataAdmin;
DENY SELECT ON V_AllDiagnosis TO DataAdmin;
DENY SELECT ON V_PatientPersonalDetails TO DataAdmin;
DENY SELECT ON V_PatientPersonalDetails TO DataAdmin;

-- -- grant execute admin's SPs, deny execute patients' and doctors' SPs
GRANT EXECUTE ON SP_AddDoctor TO DataAdmin;
GRANT EXECUTE ON SP_AddPatient TO DataAdmin;
GRANT EXECUTE ON SP_ManageDoctor TO DataAdmin;
GRANT EXECUTE ON SP_ManagePatient TO DataAdmin;
DENY EXECUTE ON SP_UpdateDoctorPersonalDetail TO DataAdmin;
DENY EXECUTE ON SP_ManageDiagnosis TO DataAdmin;
DENY EXECUTE ON SP_UpdatePatientPersonalDetail TO DataAdmin;
DENY EXECUTE ON SP_CheckPaymentDetail TO DataAdmin;

-- deny create, alter, drop on view, sp
-- Deny create, alter, and drop permissions on tables
DENY CREATE TABLE TO DataAdmin;
DENY CREATE VIEW TO DataAdmin;
DENY CREATE PROCEDURE TO DataAdmin;

DENY ALTER ON SCHEMA::dbo TO DataAdmin;

-- inserting testing data
-- just insert these data if you are not creating new user
INSERT INTO Patient (PID,PName,PPhone,PaymentCardNo) 
VALUES ('P00001',
	'Lee Dongxuan',
	EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'),'+60194378943'),
	EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'),'1234432112344321')),
	('P00002',
	'Tan Zhen Min',
	EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'),'+60123456789'),
	EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'),'1432123443211234'));

 INSERT INTO Doctor (DrID,DName,DPhone) 
VALUES ('D00001',
	'Koh Wing Xin',
	EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'),'+60120900098')),
	('D00002',
	'Siew Zhen Xiong',
	EncryptByAsymKey(AsymKey_ID('MedicalAsymKey'),'+60129547483'));


INSERT INTO Diagnosis (PatientID,DoctorID,DiagnosisDate,Diagnosis) 
VALUES ('P00001',
	'D00001',
	GETDATE(),
	EncryptByKey(Key_GUID('SymKey_Med'), 'This patient is diagnosed as having Alzheimer disease.')),

	('P00001',
	'D00002',
	GETDATE(),
	EncryptByKey(Key_GUID('SymKey_Med'), 'This patient is diagnosed as having skin allergy.')),

	('P00002',
	'D00001',
	GETDATE(),
	EncryptByKey(Key_GUID('SymKey_Med'), 'This patient is diagnosed as having sore throat.')),

	('P00002',
	'D00002',
	GETDATE(),
	EncryptByKey(Key_GUID('SymKey_Med'), 'This patient is diagnosed as having brain tumour.'));

-- show test data
SELECT * FROM Doctor;
SELECT * FROM Patient;
SELECT * FROM Diagnosis;
SELECT * FROM DiagnosisHistory;

SELECT * FROM V_AllDiagnosis;

-- - data owner is required to recover diagnosis when the data admin delete diagnosis data
--EXEC SP_RecoverDiagnosis @StartDeletionDateTime = '2024-08-11 10:27:00', @EndDeletionDateTime = '2024-08-11 10:27:00';

-- the data admin need to manually select the rows to be reinserted into the live table
SET IDENTITY_INSERT Diagnosis ON;
INSERT INTO Diagnosis (DiagID,PatientID,DoctorID,DiagnosisDate,Diagnosis)
SELECT DiagID,PatientID,DoctorID,DiagnosisDate,Diagnosis
FROM (
	SELECT 
		*,
		ROW_NUMBER() OVER (PARTITION BY diagID ORDER BY ValidTo DESC, ValidFrom DESC) AS rn
	FROM DiagnosisHistory
	-- filter the deleted rows between the deletion timestamp and the current timestamp in GMT+0 timezone
	WHERE ValidTo < SYSDATETIME() -- current timestamp
	AND ValidTo > CONVERT(DATETIME2, '2024-08-12 06:23:00') -- deletion timestamp
) AS subquery
WHERE rn = 1 -- prevent duplicate result
	AND DiagID IN (3,4); -- specify which deleted rows want to be recovered
SET IDENTITY_INSERT Diagnosis OFF;

SELECT * FROM DiagnosisHistory;

-- close symmetric key
CLOSE SYMMETRIC KEY SymKey_Med;


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
and dp.Name in ('DataAdmin');

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

-- view all doctors permission
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
and dp.Name in ('Doctors');