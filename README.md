# APU Medical Info System

## Introduction
The APU Medical Info System is designed to secure and manage sensitive data for the APU Medical Center, a hospital located in Kuala Lumpur, Malaysia. The system enhances database security by implementing data protection methods, permission management, and auditing mechanisms to safeguard the personal information of staff and patients.

## Table of Contents
- [Introduction](#introduction)
As an established hospital in the city area of Malaysia, Kuala Lumpur, that provides medical treatment to residents around Klang Valley, APU Medical Center has stored personal and sensitive details in its database, including staff personal information and patients’ diagnosis details. APU Medical Center is responsible for protecting staff and patients’ personal information and sensitive details. But the current database design and implementation by the application developers are not secure enough to protect current users’ data that is stored in the APU Medical Center database.  

To make the APU Medical Center database more secure, our team has been appointed to develop a more secure database security system to enhance the security of the database based on the listed functional and security requirements provided by the security architect. In this project, various data protection methods for various types of data will be implemented to the APU Medical Center database to make it more secure and able to protect users’ information. Permission management for each different user including data admin, doctors and patients will also be applied into the database to prevent unauthorized access to other users’ data. Auditing will also be included in this database to prevent data fraud from happening at APU Medical Center. 

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Database Structure](#database-structure)
- [Contributors](#contributors)

## Features
- **Data Security**: Implements enhanced security measures to protect sensitive data.
- **Permission Management**: Different roles (e.g., Data Admin, Doctors, Patients) have specific access controls.
- **Auditing**: Monitors database activities to prevent data fraud.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/dxlee0807/apu-medical-info-system.git
   ```
2. Execute the SQL scripts in the following order:
   - `Audits.sql`
   - `BackupDB Job.sql`
   - `ModifiedDB.sql`
   - `DataAdmin.sql`
   - `Doctor.sql`
   - `Patient.sql`

## Usage
- Once installed, the system will manage access and monitor usage according to the defined permissions and auditing rules.

## Database Structure
- The system includes various SQL scripts that define the database schema, roles, and permissions.

## Contributors
- **[dxlee0807](https://github.com/dxlee0807)**
- **[desmondsiew](https://github.com/desmondsiew)**
- **[venice0507](https://github.com/venice0507)**
- **[zhenmin01](https://github.com/zhenmin01)**
