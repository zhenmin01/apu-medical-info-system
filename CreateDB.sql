-- Initial Database Script as Provided by The Developer
Create Database MedicalInfoSystem;
Go

Use MedicalInfoSystem
Go

Create Table Doctor(
DrID varchar(6) primary key,
DName varchar(100) not null,
DPhone varchar(20)
)

Create Table Patient(
PID varchar(6) primary key,
PName varchar(100) not null,
PPhone varchar(20),
PaymentCardNo varchar(100)
)

Create Table Diagnosis(
DiagID int identity(1,1) primary key,
PatientID varchar(6) references Patient(PID) ,
DoctorID varchar(6) references Doctor(DrID) ,
DiagnosisDate datetime not null,
Diagnosis varchar(max)
)