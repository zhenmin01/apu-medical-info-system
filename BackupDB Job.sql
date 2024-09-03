-- prior preparation work
-- backup certificate
USE master
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'QwErTy12345!@#$%';

--drop certificate MISDBBackupEncryptCert;
--drop master key;

CREATE CERTIFICATE MISDBBackupEncryptCert
    WITH SUBJECT = 'MedicalInfoSystem Backup Encryption Certificate';

BACKUP CERTIFICATE MISDBBackupEncryptCert
TO FILE = N'D:\Programs\Microsoft SQL Server\MSSQL16.MSSQLSERVER04\MSSQL\Backup\MISDBBackupEncryptCert.cert'
WITH PRIVATE KEY (
	FILE = N'D:\Programs\Microsoft SQL Server\MSSQL16.MSSQLSERVER04\MSSQL\Backup\MISDBBackupEncryptCert.key',
	ENCRYPTION BY PASSWORD = 'QwErTy12345!@#$%'
);

Use msdb;
-- run full backup one time first
DECLARE @MyFileName varchar(1000);
SELECT @MyFileName = (SELECT N'D:\Programs\Microsoft SQL Server\MSSQL16.MSSQLSERVER04\MSSQL\Backup\MedicalInfoSystem_' 
+ REPLACE(convert(nvarchar(20),GetDate(),120),':','_') + '.bak');
BACKUP DATABASE MedicalInfoSystem
TO DISK = @MyFileName
WITH
COMPRESSION,
ENCRYPTION (
    ALGORITHM = AES_256,
    SERVER CERTIFICATE = MISDBBackupEncryptCert
),
STATS = 10;

--1- Create 2 jobs and add job to be performed on the current server:
-- -- full backup
-- -- differential and transaction log backup
-- -- --every time performing differential backup and transaction log backup, 
-- -- --the differential backup and transaction log overwrite the change on the latest full backup
EXEC dbo.sp_add_job
   @job_name = N'FullBackupMISDBJob', 
   @enabled = 1, 
   @description = N'Create a complete backup of database MedicalInfoSystem' ; 
GO

EXEC dbo.sp_add_job
   @job_name = N'DifferentialAndTransactionalLogBackupMISDBJob', 
   @enabled = 1, 
   @description = N'Create a Differential and a Transactional Log backup of database MedicalInfoSystem to the latest full backup' ; 
GO

EXEC dbo.sp_add_jobserver
	@job_name = N'FullBackupMISDBJob', 
	@server_name = 'LAPTOP-FI52UHOK\MSSQLSERVER04';

EXEC dbo.sp_add_jobserver
	@job_name = N'DifferentialAndTransactionalLogBackupMISDBJob', 
	@server_name = 'LAPTOP-FI52UHOK\MSSQLSERVER04';

--2a- Add a 'Create the backup' step to this FullBackupMISDBJob
EXEC dbo.sp_add_jobstep
    @job_name = N'FullBackupMISDBJob', 
    @step_name = N'Create the backup', 
    @subsystem = N'TSQL',
    @command = N'DECLARE @MyFileName varchar(1000);
	SELECT @MyFileName = (SELECT N''D:\Programs\Microsoft SQL Server\MSSQL16.MSSQLSERVER04\MSSQL\Backup\MedicalInfoSystem_'' 
	+ REPLACE(convert(nvarchar(20),GetDate(),120),'':'',''_'') + ''.bak'');
	BACKUP DATABASE MedicalInfoSystem
	TO DISK = @MyFileName
	WITH
	COMPRESSION,
	ENCRYPTION (
		ALGORITHM = AES_256,
		SERVER CERTIFICATE = MISDBBackupEncryptCert
	),
	STATS = 10;';
GO

--2b- Add a 'Create the backups' step to this DifferentialAndTransactionalLogBackupMISDBJob
EXEC dbo.sp_add_jobstep
    @job_name = N'DifferentialAndTransactionalLogBackupMISDBJob', 
    @step_name = N'Create the backups', 
    @subsystem = N'TSQL',
    @command = N'DECLARE @LatestFullBackupPath varchar(1000);
		IF OBJECT_ID(''tempdb..#DirectoryTree'')IS NOT NULL
			DROP TABLE #DirectoryTree;
	CREATE TABLE #DirectoryTree (
			id int IDENTITY(1,1)
			,subdirectory nvarchar(512)
			,depth int
			,isfile bit);
	INSERT #DirectoryTree (subdirectory,depth,isfile)
	EXEC master.sys.xp_dirtree ''D:\Programs\Microsoft SQL Server\MSSQL16.MSSQLSERVER04\MSSQL\Backup'',1,1;
	SELECT TOP 1 @LatestFullBackupPath=subdirectory FROM #DirectoryTree
	WHERE isfile = 1 AND RIGHT(subdirectory,4) = ''.BAK''
	ORDER BY subdirectory DESC;
	SET @LatestFullBackupPath = N''D:\Programs\Microsoft SQL Server\MSSQL16.MSSQLSERVER04\MSSQL\Backup\''+@LatestFullBackupPath

	BACKUP DATABASE MedicalInfoSystem TO DISK = @LatestFullBackupPath 
	WITH FORMAT, DIFFERENTIAL,COMPRESSION,
	ENCRYPTION (
		ALGORITHM = AES_256,
		SERVER CERTIFICATE = MISDBBackupEncryptCert
	),
	STATS = 10;

	BACKUP LOG MedicalInfoSystem TO DISK = @LatestFullBackupPath
	WITH FORMAT, COMPRESSION,
	ENCRYPTION (
		ALGORITHM = AES_256,
		SERVER CERTIFICATE = MISDBBackupEncryptCert
	),
	STATS = 10;';
GO


--3- schedule the full backup job, and differential and transactional-log backup job:

-- schedule for full backup
EXEC dbo.sp_add_schedule
    @schedule_name = N'RunFourTimesDaily',
	@enabled = 1, 
    @freq_type = 4, -- means run daily 
    @freq_interval = 1, -- means run once every 1 day
	@freq_subday_type = 8, -- run by n hours
	@freq_subday_interval = 6, -- every 6 hours
	@active_start_date = 20221008, -- start at earlier date
    @active_start_time = 000000 ; -- means at 00:00:00
GO

-- schedule for differential and transactional log backup
EXEC dbo.sp_add_schedule
    @schedule_name = N'RunHourlyDaily',
	@enabled = 1, 
    @freq_type = 4, -- means run daily 
    @freq_interval = 1, -- means run once every 1 day
	@freq_subday_type = 8, -- run by n hours
	@freq_subday_interval = 1, -- every 1 hour
	@active_start_date = 20221008, -- start at earlier date
    @active_start_time = 000000 ; -- means at 00:00:00
GO


--4- And attach these newly created schedules to the job full backup job, and differential and transactional-log backup job:

EXEC sp_attach_schedule
   @job_name = N'FullBackupMISDBJob',
   @schedule_name = N'RunFourTimesDaily'; 
GO

EXEC sp_attach_schedule
   @job_name = N'DifferentialAndTransactionalLogBackupMISDBJob',
   @schedule_name = N'RunHourlyDaily'; 
GO


select * from msdb.dbo.sysschedules;
select * from msdb.dbo.sysjobsteps;
select * from msdb.dbo.sysjobs;

select * from msdb.dbo.sysjobhistory;
select * from msdb.dbo.sysjobservers;

-- removing all backup job from schedules
exec sp_detach_schedule
   @job_name = N'FullBackupMISDBJob',
   @schedule_name = N'RunFourTimesDaily'; 

EXEC sp_detach_schedule
   @job_name = N'DifferentialAndTransactionalLogBackupMISDBJob',
   @schedule_name = N'RunHourlyDaily'; 

EXEC sp_delete_schedule	
	@schedule_name = N'RunFourTimesDaily';

EXEC sp_delete_schedule
	@schedule_name = N'RunHourlyDaily';

EXEC sp_delete_jobserver
	@job_name = N'FullBackupMISDBJob', 
	@server_name = 'LAPTOP-FI52UHOK\MSSQLSERVER04';

EXEC sp_delete_jobserver
	@job_name = N'DifferentialAndTransactionalLogBackupMISDBJob', 
	@server_name = 'LAPTOP-FI52UHOK\MSSQLSERVER04';

EXEC dbo.sp_delete_job
   @job_name = N'FullBackupMISDBJob'; 

EXEC dbo.sp_delete_job
   @job_name = N'DifferentialAndTransactionalLogBackupMISDBJob'; 