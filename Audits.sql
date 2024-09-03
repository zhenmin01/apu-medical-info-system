CREATE DATABASE MedicalInfoSystem;


-- audit login/logout
-- -- create audit at external file location
CREATE SERVER AUDIT MIS_Login_Audit 
TO FILE ( FILEPATH = 'D:\Programs\Microsoft SQL Server\MSSQL16.MSSQLSERVER04\MSSQL\Audits' )
WITH ( QUEUE_DELAY = 1000,  ON_FAILURE = CONTINUE);

-- -- enable server audit
ALTER SERVER AUDIT MIS_Login_Audit WITH (STATE = ON) ;

-- -- create and enable server audit specification
CREATE SERVER AUDIT SPECIFICATION [MIS_Login_Audit_Specification]
FOR SERVER AUDIT [MIS_Login_Audit]
ADD (FAILED_LOGIN_GROUP), 
ADD (LOGIN_CHANGE_PASSWORD_GROUP),
ADD (LOGOUT_GROUP),
ADD (SUCCESSFUL_LOGIN_GROUP)
WITH (STATE=ON);

-- -- reading the audit file
DECLARE @AuditFilePath VARCHAR(8000);

Select @AuditFilePath = audit_file_path
From sys.dm_server_audit_status
where name = 'MIS_Login_Audit'

select a.event_time,  
	c.[name], 
	b.class_type_desc, 
	a.[object_name],
	a.succeeded,  
	a.server_principal_name, 
	a.server_instance_name, 
	a.[statement]
	from sys.fn_get_audit_file(@AuditFilePath,default,default) a 
	INNER JOIN sys.dm_audit_class_type_map b ON a.class_type=b.class_type
	INNER JOIN (SELECT DISTINCT action_id,name FROM  sys.dm_audit_actions) as c ON a.action_id = c.action_id
WHERE server_principal_name LIKE 'P_____' OR server_principal_name LIKE 'D_____'
--WHERE a.action_id='LGIF' -- can filtered by successful/failed login/logout
-- LGIF : LOGIN FAILED
-- LGIS : LOGIN SUCCEEDED
-- LGO  : LOGOUT

order by a.event_time desc
go;


-- audit ddl
CREATE SERVER AUDIT MIS_DDL_Audit 
	TO FILE (FILEPATH = 'D:\Programs\Microsoft SQL Server\MSSQL16.MSSQLSERVER04\MSSQL\Audits');   
GO  

-- Enable the server audit.   
ALTER SERVER AUDIT MIS_DDL_Audit WITH (STATE = ON) ;
Go

CREATE SERVER AUDIT SPECIFICATION [MIS_DDL_Audit_Specification]
FOR SERVER AUDIT MIS_DDL_Audit
ADD (DATABASE_OBJECT_CHANGE_GROUP), -- server level
ADD (SCHEMA_OBJECT_CHANGE_GROUP) -- alter table add/drop
WITH (STATE=ON)
Go

DECLARE @AuditFilePath VARCHAR(8000);
Select @AuditFilePath = audit_file_path
From sys.dm_server_audit_status
where name = 'MIS_DDL_Audit'
select a.event_time,  
	c.[name], 
	b.class_type_desc, 
	a.[object_name],
	a.succeeded,  
	a.server_principal_name, 
	a.server_instance_name, 
	a.[statement]
	from sys.fn_get_audit_file(@AuditFilePath,default,default) a 
	INNER JOIN sys.dm_audit_class_type_map b ON a.class_type=b.class_type
	INNER JOIN (SELECT DISTINCT action_id,name FROM  sys.dm_audit_actions) as c ON a.action_id = c.action_id;

-- audit DML
-- -- create audit at external file location
CREATE SERVER AUDIT MIS_DML_Audit 
	TO FILE (FILEPATH = 'D:\Programs\Microsoft SQL Server\MSSQL16.MSSQLSERVER04\MSSQL\Audits');   

-- -- enable server audit
ALTER SERVER AUDIT MIS_DML_Audit WITH (STATE = ON) ;

-- -- create and enable dataset audit specification
USE MedicalInfoSystem;
CREATE DATABASE AUDIT SPECIFICATION [MIS_DML_Audit_Specification]
FOR SERVER AUDIT MIS_DML_Audit
ADD ( SELECT, INSERT, UPDATE, DELETE ON DATABASE::[MedicalInfoSystem] BY public)   
WITH (STATE = ON) ;

-- -- read DML audit file
DECLARE @AuditFilePath VARCHAR(8000);

Select @AuditFilePath = audit_file_path
From sys.dm_server_audit_status
where name = 'MIS_DML_Audit'

select a.event_time,  
	c.[name], 
	b.class_type_desc, 
	a.[object_name],
	a.succeeded,  
	a.server_principal_name, 
	a.server_instance_name, 
	a.[statement]
	from sys.fn_get_audit_file(@AuditFilePath,default,default) a 
	INNER JOIN sys.dm_audit_class_type_map b ON a.class_type=b.class_type
	INNER JOIN (SELECT DISTINCT action_id,name FROM  sys.dm_audit_actions) as c ON a.action_id = c.action_id
	WHERE server_principal_name='MISAdmin' OR server_principal_name LIKE 'P_____' OR server_principal_name LIKE 'D_____'
	order by a.event_time desc;

-- audit DCL
USE master;

CREATE SERVER AUDIT MIS_DCL_Audit 
	TO FILE (FILEPATH = 'D:\Programs\Microsoft SQL Server\MSSQL16.MSSQLSERVER04\MSSQL\Audits');   
GO  

-- Enable the server audit.   
ALTER SERVER AUDIT MIS_DCL_Audit WITH (STATE = ON) ;
Go

-- specification
USE MedicalInfoSystem;
CREATE DATABASE AUDIT SPECIFICATION [MIS_DCL_Audit_Specification]
FOR SERVER AUDIT MIS_DCL_Audit
ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP),   
ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP)
WITH (STATE = ON) ;


DECLARE @AuditFilePath VARCHAR(8000);

Select @AuditFilePath = audit_file_path
From sys.dm_server_audit_status
where name = 'MIS_DCL_Audit'

select a.event_time,  
	c.[name], 
	b.class_type_desc, 
	a.[object_name],
	a.succeeded,  
	a.server_principal_name, 
	a.server_instance_name, 
	a.[statement]
	from sys.fn_get_audit_file(@AuditFilePath,default,default) a 
	INNER JOIN sys.dm_audit_class_type_map b ON a.class_type=b.class_type
	INNER JOIN (SELECT DISTINCT action_id,name FROM  sys.dm_audit_actions) as c ON a.action_id = c.action_id;
go;


-- disable audits
--use master;
--ALTER SERVER AUDIT SPECIFICATION [MIS_Login_Audit_Specification]
--WITH (STATE=OFF);
--ALTER SERVER AUDIT SPECIFICATION [MIS_DDL_Audit_Specification]
--WITH (STATE=OFF);

--use MedicalInfoSystem;
--ALTER DATABASE AUDIT SPECIFICATION [MIS_DML_Audit_Specification]
--WITH (STATE=OFF);
--ALTER DATABASE AUDIT SPECIFICATION [MIS_DCL_Audit_Specification]
--WITH (STATE=OFF);

-- delete audits
--use master;
--DROP SERVER AUDIT SPECIFICATION [MIS_Login_Audit_Specification]  
--DROP SERVER AUDIT SPECIFICATION [MIS_DDL_Audit_Specification]  

--use MedicalInfoSystem;
--DROP DATABASE AUDIT SPECIFICATION [MIS_DML_Audit_Specification]  
--DROP DATABASE AUDIT SPECIFICATION [MIS_DCL_Audit_Specification]  

--use master;
--ALTER SERVER AUDIT [MIS_Login_Audit] WITH (STATE=OFF);
--ALTER SERVER AUDIT [MIS_DDL_Audit] WITH (STATE=OFF);
--ALTER SERVER AUDIT [MIS_DML_Audit] WITH (STATE=OFF);
--ALTER SERVER AUDIT [MIS_DCL_Audit] WITH (STATE=OFF);

--DROP SERVER AUDIT [MIS_Login_Audit]
--DROP SERVER AUDIT [MIS_DDL_Audit]
--DROP SERVER AUDIT [MIS_DML_Audit]
--DROP SERVER AUDIT [MIS_DCL_Audit]
