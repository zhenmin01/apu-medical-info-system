# APU Medical Info System

## Introduction
The APU Medical Info System is designed to secure and manage sensitive data for the APU Medical Center, a hospital located in Kuala Lumpur, Malaysia. The system enhances database security by implementing data protection methods, permission management, and auditing mechanisms to safeguard the personal information of staff and patients.

## Table of Contents
- [Introduction](#introduction)
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
